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
# Homepage: https://rubackup.gitlab.io                                       #
#                                                                            #
##############################################################################

# This file provides the main process loop which actually implements most of
# the astract work: this is generic code which uses features from the specific
# modules.

# Process all backup entries
def process_entries()
    entcount = 0
    errcount = 0
    results = Hash.new

    $output.write(1, "Processing backup entries ...")

    # Process each entry
    $entries.each do |entryname,entrydata|
        entcount += 1
        $output.separator(2)
        # Ignore if backup entry is disabled
        enabled = entrydata.fetch('enabled', true)
        if (enabled == false) then
            $output.twrite(2, "Ingoring entry '#{entryname}' as it is disabled")
            results[entryname] = 'IGNORED'
            next
        end
        # Perform all operations for a single entry at a time
        $output.twrite(2, "Processing of entry '#{entryname}' starting ...")
        time1 = Time.now
        entryres = process_entry(entryname, entrydata)
        time2 = Time.now
        if not entryres then
            errcount += 1
        end
        timediff = (time2 - time1).to_i
        resultmsg = entryres ? 'SUCCESS' : 'FAILURE'
        results[entryname] = resultmsg
        $output.twrite(2, "Processing of entry '#{entryname}' completed in #{timediff} seconds: #{resultmsg}")
        # Wait between backups if requested by configuration
        sleep($globcfg.fetch('sleep_between', 0))
    end

    $output.separator(1)

    $output.write(1, "Results summary ...")

    hostname = Socket.gethostname
    message = "In total #{entcount} backup entries have been processed with #{errcount} errors:\n"
    results.each { |key,val| message += "- #{key} : #{val}\n" }
    $output.twrite(1, message)

    # Error handler and send final notification message
    status = (errcount == 0) ? 'SUCCESS' : 'FAILURE'
    notify_type = $globcfg.fetch('notify_type', nil)
    notify_args = $globcfg.fetch('notify_opts', nil)
    if (notify_type and notify_args) then
        subject = "#{hostname}: rubackup results for #{$today} [#{status}]"
        notify_module = $modules['notify'][notify_type].new
        notify_module.message(notify_args, subject, message)
    end

    return (errcount == 0)
end

# Process a single backup entry
def process_entry(entryname, entrydata)
    errcount = 0

    backup_module = entrydata['modules'].fetch('backup', nil)
    remote_module = entrydata['modules'].fetch('remote', nil)
    encrypt_module = entrydata['modules'].fetch('encrypt', nil)
    backup_schedule = entrydata.fetch('backup_schedule', nil)
    remote_schedule = entrydata.fetch('remote_schedule', nil)

    # make sure the directory exists (optional: not used by all backup modules)
    bkpdir = entrydata.fetch('bakfile_dir', nil)
    FileUtils.mkdir_p(bkpdir) if bkpdir

    # 1. create backup and encrypt it if requested
    baksched = Scheduling.determine_backup_schedule($today, backup_schedule)
    if ((backup_module != nil) and (baksched != nil)) then

        $output.separator(4)

        # 1.1 create backup by running module function
        begin
            $output.twrite(3, "Creating primary backup using module '#{backup_module.class}' for '#{entryname}' ...")
            time1 = Time.now
            bkpfile = backup_module.backup(entrydata)
            time2 = Time.now
            timediff = (time2 - time1).to_i
            $output.twrite(3, "Primary backup for '#{entryname}' successfully completed in #{timediff} seconds")
        rescue StandardError => e
            $output.twrite(0, "Failed to create primary backup for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
            bkpfile = nil
            errcount += 1
        end

        $output.separator(4)

        # 1.2 encrypt backup file is requested and if backup module produced a local backup file
        if (encrypt_module and bkpdir and bkpfile) then
            begin
                $output.twrite(3, "Performing encryption using module '#{encrypt_module.class}' for '#{entryname}' ...")
                time1 = Time.now
                bkpfile = encrypt_module.encrypt(entrydata, bkpfile)
                time2 = Time.now
                timediff = (time2 - time1).to_i
                $output.twrite(3, "Encryption for entry '#{entryname}' successfully completed in #{timediff} seconds")
            rescue StandardError => e
                $output.twrite(0, "Failed to perform encryption for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
                bkpfile = nil
                errcount += 1
            end
            $output.separator(4)
        end

        # 1.3 create checksum for backup file
        if (bkpdir and bkpfile) then
            begin
                sumfile = backup_module.mkcsum(entrydata, bkpfile)
            rescue StandardError => e
                $output.write(0, "Failed to create checksum for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
                sumfile = nil
                errcount += 1
            end
            $output.separator(4)
        else
            sumfile = nil
        end

        # 1.4 set permissions on backup files if they exist
        if (bkpfile or sumfile) then
            begin
                backup_module.setperm(entrydata, bkpfile, sumfile)
            rescue StandardError => e
                $output.write(0, "Failed to set backup permissions for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
                errcount += 1
            end
            $output.separator(4)
        end
    end

    # 2. Rotation of primary backups

    # 2.1 Create list of primary backups
    $output.write(3, "Creating list of primary backups using module '#{backup_module.class}' for '#{entryname}' ...")
    begin
        localist = backup_module.list(entrydata)
        localist.each do |bakfile|
            $output.write(4, "PRIMARY-BAKLIST: name=[#{bakfile.name}] date=[#{bakfile.date}] age=[#{bakfile.age.to_s.rjust(3)}d] sums=[#{bakfile.sumlist}] size=[#{bakfile.size}]")
        end
    rescue StandardError => e
        $output.write(0, "Failed to list all existing backups for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
        errcount += 1
    end

    $output.separator(4)

    # 2.2 Perform local rotation
    $output.write(3, "Rotating primary backups using module '#{backup_module.class}' for '#{entryname}' ...")
    begin
        localist.each do |bakfile|
            filesched = Scheduling.determine_backup_schedule(bakfile.date, backup_schedule)
            $output.write(4, "PRIMARY-ROTATE: name=[#{bakfile.name}] => age=[#{bakfile.age.to_s.rjust(3)}d] schedule=[#{filesched}]")
            if (filesched == nil) then # delete file if it does not fit in retention policy
                $output.write(3, "Deleting primary backup: bakfile='#{bakfile.name}'")
                backup_module.delete(entrydata, bakfile)
                localist.delete(bakfile)
            end
        end
    rescue StandardError => e
        $output.write(0, "Failed to perform primary rotation for backup for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
        errcount += 1
    end

    $output.separator(4)

    # 3 remote stuff
    if (remote_module != nil) then
        
        # 3.1 Create list of remote history
        begin
            $output.write(3, "Getting list of remote files using module '#{backup_module.class}' for '#{entryname}' ...")
            remotelist = remote_module.list(entrydata)
            remotelist.each do |bakfile|
                $output.write(4, "REMOTE-BAKLIST: name=[#{bakfile.name}] date=[#{bakfile.date}] sums=[#{bakfile.sumlist}] size=[#{bakfile.size}]")
            end
        rescue StandardError => e
            $output.write(0, "Failed to produce list of remote backups for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
            errcount += 1
        end

        $output.separator(4)

        # 3.2 Upload backup to remote location
        begin
            $output.twrite(3, "Performing uploads to remote storage using module '#{remote_module.class}' for '#{entryname}' ...")
            localist.each do |lbakfile|
                baksched = Scheduling.determine_backup_schedule(lbakfile.date, remote_schedule)
                next if (baksched == nil)
                # make list of files that must actually be uploaded (when files are not present of have a different size in remote location)
                filestoupload = Array.new
                $output.write(5, "lbakfile.name='#{lbakfile.name}'. Determine if same file is already present on the remote side ...")
                rbakfiles = remotelist.select { |rbakfile| ((rbakfile.name == lbakfile.name) and (rbakfile.size == lbakfile.size)) } 
                if (rbakfiles.length == 0) then
                    filestoupload.push(lbakfile.name) # upload main backup file
                    lbakfile.csum.each { |sumext| filestoupload.push("#{lbakfile.name}.#{sumext}") } # upload checskum files
                    $output.write(5, "Have to upload the main backup file: '#{lbakfile.name}'")
                else
                    rbakfile = rbakfiles[0]
                    lsums = lbakfile.sumlist
                    rsums = rbakfile.sumlist
                    $output.write(5, "Upload of main backup file not required: filename='#{lbakfile.name}' lsums='#{lsums}' rsums='#{rsums}'")
                    if (lsums != rsums) then
                        lbakfile.csum.each { |sumext| filestoupload.push("#{lbakfile.name}.#{sumext}") }
                        $output.write(5, "Must upload checksum files only: #{filestoupload}")
                    end
                end
                $output.write(5, "filename='#{lbakfile.name}' ==> filestoupload=#{filestoupload.join(',')}")
                uploadaction = (filestoupload.size > 0) ? 'upload' : nil
                $output.write(4, "REMOTE-UPLOAD: name=[#{lbakfile.name}] => age=[#{lbakfile.age}d] baksched=[#{baksched}] action=[#{uploadaction}]")
                # upload all files which are not already present in remote location
                if (uploadaction == 'upload') then
                    $output.write(3, "Uploading backup '#{lbakfile.name}' and its checksum files ...")
                    time1 = Time.now
                    filestoupload.each do |filename|
                        fullpath = File.join(bkpdir, filename)
                        $output.write(4, "Uploading file '#{filename}'")
                        remote_module.send(entrydata, fullpath)
                    end
                    time2 = Time.now
                    timediff = (time2 - time1).to_i
                    $output.twrite(3, "Uploads for '#{entryname}' successfully completed in #{timediff} seconds")
                end
            end
        rescue StandardError => e
            $output.write(0, "Failed to manage uploads to remote location for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
            errcount += 1
        end

        $output.separator(4)

        # 3.3 Perform remote rotation       
        $output.write(3, "Performing remote rotation using module '#{remote_module.class}' for entry='#{entryname}' ")
        begin
            remotelist.each do |bakfile|
                filesched = Scheduling.determine_backup_schedule(bakfile.date, remote_schedule)
                $output.write(4, "REMOTE-ROTATE: name=[#{bakfile.name}] => age=[#{bakfile.age.to_s.rjust(3)}d] schedule=[#{filesched}]")
                if (filesched == nil) then
                    $output.write(3, "Deleting remote backup: backup=[#{bakfile.name}] and its checksum files")
                    bakfile.list_all_related_files.each do |filename|
                        $output.write(4, "Deleting remote file: #{filename}")
                        remote_module.delete(entrydata, filename)
                    end
                    remotelist.delete(bakfile)
                end
            end
        rescue StandardError => e
            $output.write(0, "Failed to perform remote rotation for entry '#{entryname}'\n#{e.message}\n#{e.backtrace.join("\n")}")
            errcount += 1
        end
    end

    return (errcount == 0)
end
