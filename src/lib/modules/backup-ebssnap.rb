#!/usr/bin/env ruby

##############################################################################
#                                                                            #
# rubackup: ruby based backup application for Linux                          #
#                                                                            #
# Copyright (C) 2014-2015 Francois Dupoux.  All rights reserved.             #
#                                                                            #
# This program is free software; you can redistribute it and/or              #
# modify it under the terms of the GNU General Public                        #
# License v2 as published by the Free Software Foundation.                   #
#                                                                            #
# This program is distributed in the hope that it will be useful,            #
# but WITHOUT ANY WARRANTY; use it at your own risk.                         #
#                                                                            #
# Homepage: http://www.rubackup.org                                          #
#                                                                            #
##############################################################################

# Implementation of the backup module for tarballs

require "#{$progdir}/lib/modules/backup-generic"
require 'rubygems'
require 'aws-sdk-v1'
require 'socket'

class ModuleBackupEbsSnap < ModuleBackupGeneric

    # Initialization
    def initialize()
        @ec2 = nil
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='fsfreeze', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='stopsvc', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='awsregion', mandatory=true, defval=nil, validator=AwsRegionValidator.new),
            ValidationRule.new(name='accesskey', mandatory=true, defval=nil, validator=AwsAccessKeyReferenceValidator.new),
        ]
    end

    def detect_ec2_instance_id()
        uri = URI('http://169.254.169.254/latest/meta-data/instance-id')
        instid = Net::HTTP.get(uri)
        raise "Invalid EC2 instance ID: #{instid}" if (instid !~ /^i\-[0-9a-z]{8}$/)
        return instid
    end

    def init_ec2_handle(backup_opts)
        awsregion = backup_opts.fetch('awsregion')
        accesskey = backup_opts.fetch('accesskey')
        keypublic = accesskey['public']
        keysecret = accesskey['secret']
        @ec2 = AWS::EC2.new(:access_key_id => keypublic, :secret_access_key => keysecret, :region => awsregion)
    end

    def detect_ebs_volumes(instid)
        results = Array.new
        volumes = @ec2.volumes.select { |vol| (vol.status == :in_use) }
        volumes.each do |vol|
            vol.attachments.each do |attach|
                results.push(vol) if (attach.instance.id == instid)
            end
        end
        return results
    end

    def backup(entrydata)
        backup_opts = entrydata.fetch('backup_opts')
        basename = basename_with_date(entrydata)
        fsfreeze = backup_opts.fetch('fsfreeze', nil)
        stopsvc = backup_opts.fetch('stopsvc', nil)
        
        # hostname required for tagging
        hostname = Socket.gethostname

        # get list of EBS volumes attached to current EC2 instance
        init_ec2_handle(backup_opts)
        instid = detect_ec2_instance_id()
        $output.write(4, "EC2 Instance ID: instid='#{instid}'")
        vols = detect_ebs_volumes(instid)

        # local variables
        loglines = Array.new
        frozenfsok = Array.new
        frozenfserr = Array.new
        errormsgs = Array.new
        unfreezeerr = Array.new
        svcdone = Array.new
        
        begin # things to undo start here

            # stop all services which have to be stopped (for snapshot consistency)
            if ((stopsvc) and (stopsvc.count > 0)) then
                # check we are able to control services
                Services.check_service_command()
                # attempt to stop all services listed
                stopsvc.each do |svc|
                    svcdone.push(svc)
                    loglines.push("Stopping service #{svc}")
                    Services.manage_service(svc, 'stop')
                end
            end

            # freeze filesystems specific in the list to enforce consistency of the snapshot
            fsfreezebin = Utilities.path_to_command("fsfreeze")
            if ((fsfreezebin) and (fsfreeze) and (fsfreeze.count > 0)) then
                raise "Cannot find the fsfreeze binary in PATH" if not fsfreezebin
                fsfreeze.each do |fs|
                    if not Pathname(fs).mountpoint? then
                        raise "Cannot freeze directory #{fs} as it is not a mount point"
                    end
                    command="#{fsfreezebin} --freeze #{fs}"
                    loglines.push("Freezing filesystem: #{command}")
                    (out, res) = Open3.capture2e(command)
                    if ((res.exited? == true) and (res.exitstatus == 0)) then
                        frozenfsok.push(fs)
                    else
                        frozenfserr.push(fs)
                        errormsgs.push("#{out}\n")
                    end
                end
                if (frozenfserr.count() > 0) then
                    raise "Failed to freeze filesystems: #{frozenfserr.join(',')}\n#{errormsgs.join("\n")}"
                end
            end

            # Do not write to stdout/stderr while filesystems are frozen as it could
            # cause a dead lock when the output is redirected to a file stored on
            # a filesystem which is frozen. The script is waiting for the messages to
            # be sent and the filesystem is waiting for the script to unfreeze the
            # filesystem. The solution is to store ouput messages in memory instead
            # and to print these messages once all filesystems have been unfrozen.
            # Use loglines.push("My message") to log in these circumstances

            # create snapshot while filesystems are frozen and service stopped
            vols.each do |vol|
                curtime = Time.now.strftime("%Y%m%d-%H%M")
                snapshot = vol.create_snapshot("rubackup #{basename}")
                loglines.push("Created snapshot [#{snapshot.id}] of volume=[#{vol.id}]")
                snapshot.tag('Name', :value => "#{hostname}-#{curtime}")
                snapshot.tag('Date', :value => "#{$curdate}")
                snapshot.tag('Product', :value => "rubackup")
            end

        ensure # unfreeze filesystems and restart services in any circumstances (success or failure)

            # unfreeze all filesystems which have been frozen
            frozenfsok.each do |fs|
                command="#{fsfreezebin} --unfreeze #{fs}"
                (out, res) = Open3.capture2e(command)
                loglines.push("Unfreezing filesystem: #{command}")
                if ((res.exited? == false) or (res.exitstatus != 0)) then
                    unfreezeerr.push(fs)
                    errormsgs.push("#{out}")
                end
            end

            # restart all services which have been stopped
            svcdone.each do |svc|
                loglines.push("Restarting service #{svc}")
                Services.manage_service(svc, 'restart')
            end

            # report problems for unfreezing filesystems
            if (unfreezeerr.count() > 0) then
                raise "Failed to freeze filesystems: #{unfreezeerr.join(',')}\n#{errormsgs.join("\n")}"
            end

        end

        # print results to stdout/stderr now that filesystems have been unfrozen
        loglines.each { |log| $output.write(3, log) }

        return nil # return nil as the backup does not create a file on the local disk
    end

    # List all backups which are still stored for a specific entry
    def list(entrydata)
        results = Array.new
        backup_opts = entrydata.fetch('backup_opts')
        init_ec2_handle(backup_opts)
        instid = detect_ec2_instance_id()
        vols = detect_ebs_volumes(instid)
        vols.each do |vol|
            snaps1 = @ec2.snapshots.filter('volume-id', vol.id)
            snaps2 = snaps1.select { |snap| (snap.tags.has_key?('Product') and snap.tags['Product'] == 'rubackup') }
            snaps3 = snaps2.select { |snap| (snap.tags.has_key?('Name') and snap.tags.has_key?('Date')) }
            snaps3.each do |snap|
                bakfile = Bakfile.new
                bakfile.name = snap.id
                bakfile.size = snap.volume_size * (1024*1024*1024)
                bakfile.date = Date.strptime(snap.tags['Date'], '%Y%m%d')
                results.push(bakfile)
            end
        end
        return results
    end

    # Delete an old backup
    def delete(entrydata, bakfile)
        snapid = bakfile.name
        $output.write(4, "ModuleBackupEbsSnap.delete(bakfile=[#{snapid}])")
        backup_opts = entrydata.fetch('backup_opts')
        init_ec2_handle(backup_opts)
        snap = @ec2.snapshots[snapid]
        if ((snap.is_a?(AWS::EC2::Snapshot)) and (snap.id == snapid)) then
            $output.write(4, "Deleting EBS Snapshot [#{snap.id}]")
            snap.delete()
        else
            raise "Cannot find EBS snapshot having id=[#{snapid}]"
        end
    end

    # Create checksum file
    def mkcsum(entrydata, filename)
        return nil # Nothing to do
    end

    # Set permissions and ownership on backup file and optional checksum file
    def setperm(entrydata, bkpfile, sumfile)
        return nil # Nothing to do
    end

end
