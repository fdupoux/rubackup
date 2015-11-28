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
require 'aws-sdk-core'
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
        creds = Aws::Credentials.new(keypublic, keysecret)
        @ec2 = Aws::EC2::Client.new(region: awsregion, credentials: creds)
    end

    def detect_ebs_volumes(instid)
        results = Array.new
        volumes = @ec2.describe_volumes(filters: [{name: 'attachment.status', values: ['attached']}]).volumes
        volumes.each do |vol|
            vol.attachments.each do |attach|
                results.push(vol) if (attach.instance_id == instid)
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
                newtags = [
                    {key: 'Name', value: "#{hostname}-#{curtime}"},
                    {key: 'Date', value: "#{$curdate}"},
                    {key: 'Product', value: "rubackup"},
                ]
                snapshot = @ec2.create_snapshot({volume_id: vol.volume_id, description: "rubackup #{basename}"}) 
                loglines.push("Created snapshot [#{snapshot.snapshot_id}] of volume=[#{vol.volume_id}]")
                @ec2.create_tags({resources:[snapshot.snapshot_id], tags: newtags})
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
            snaps = @ec2.describe_snapshots(filters: [{name: 'volume-id', values: [vol.volume_id]},{name: 'tag-key', values: ['Product','Date']}]).snapshots
            snaps.each do |snap|
                bakfile = Bakfile.new
                bakfile.name = snap.snapshot_id
                bakfile.size = snap.volume_size * (1024*1024*1024)
                tags_date = snap.tags.select { |mytag| (mytag.key == 'Date') }
                tags_prod = snap.tags.select { |mytag| (mytag.key == 'Product') }
                tag_date = tags_date[0]['value']
                tag_prod = tags_prod[0]['value']
                if (tag_prod == 'rubackup') then
                    bakfile.date = Date.strptime(tag_date, '%Y%m%d')
                    results.push(bakfile)
              end
            end
        end
        return results
    end

    # Delete an old backup
    def delete(entrydata, bakfile)
        snapid = bakfile.name
        $output.write(4, "ModuleBackupEbsSnap.delete(snapid=[#{snapid}])")
        backup_opts = entrydata.fetch('backup_opts')
        init_ec2_handle(backup_opts)
        $output.write(4, "Deleting EBS Snapshot [#{snapid}]")
        @ec2.delete_snapshot({snapshot_id: snapid})
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
