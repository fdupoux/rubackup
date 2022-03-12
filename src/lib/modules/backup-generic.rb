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

# Generic base class for backup modules

# The functions implemented here can be reused for most backup creation 
# modules as most backup creation modules create a file on the local disk.
# Other backup modules which do not use the local filesystem (eg: EBS Snaphot)
# must replace these functions with a function doing nothing

class ModuleBackupGeneric

    # Initialization
    def initialize()
        raise NotImplementedError, 'You must implement the initialize() function'
    end

    # Return list of rules to validate the module specific config options
    def get_options_validation()
        raise NotImplementedError, 'You must implement the get_options_validation() function'
    end

    # Create the backup
    def backup(entrydata)
        raise NotImplementedError, 'You must implement the backup() function'
    end

    # Calculate backup file name with date in it
    def basename_with_date(entrydata)
        bakfile_basename = entrydata['bakfile_basename']
        return "#{bakfile_basename}-#{$curdate}"
    end

    # List all backups which are stored locally for a specific entry (returns an array of Bakfile objects)
    def list(entrydata)
        bakfile_basename = entrydata['bakfile_basename']
        bkpdir = entrydata['bakfile_dir']
        if bkpdir.nil?() then
            raise "ERROR: entry has no option 'bakfile_dir'"
        end
        results = Array.new
        allfiles = Dir.glob(File.join(bkpdir, "#{bakfile_basename}-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].*"))
        bakfiles = allfiles.select { |fullpath| Checksum.checksum?(File.basename(fullpath)) == false }
        bakfiles.sort_by{ |f| File.mtime(f) }.each do |fullpath|
            bakfile = Bakfile.new
            bakfile.name = File.basename(fullpath)
            bakfile.size = File.size(fullpath)
            bakfile.date = Scheduling.determine_creation_date(bakfile.name, bakfile_basename)
            Checksum.list_extensions().each do |sumext|
                sumfile = "#{bakfile.name}.#{sumext}"
                sumpath = File.join(bkpdir, sumfile)
                if File.file?(sumpath) then
                    bakfile.csum.push(sumext)
                end
            end
            results.push(bakfile)
        end
        return results
    end

    # Delete an old backup
    def delete(entrydata, bakfile)
        bkpdir = entrydata['bakfile_dir']
        bakfile.list_all_related_files().each do |filename|
            fullpath = File.join(bkpdir, filename)
            $output.write(4, "Deleting local file: filename=[#{filename}] fullpath=[#{fullpath}]")
            File.delete(fullpath)
        end
    end

    # Create checksum file
    def mkcsum(entrydata, filename)
        bkpdir = entrydata['bakfile_dir']
        sumfile = Checksum.create(bkpdir, filename)
        return sumfile
    end

    # Set permissions and ownership on backup file and optional checksum file
    def setperm(entrydata, bkpfile, sumfile)
        bkpdir = entrydata['bakfile_dir']
        # set ownerships and permissions if requested in configuration
        owner = entrydata.fetch('bakfile_owner', nil)
        group = entrydata.fetch('bakfile_group', nil)
        if ((owner or group) and (bkpfile and sumfile)) then
            FileUtils.chown(owner, group, File.join(bkpdir, bkpfile))
            FileUtils.chown(owner, group, File.join(bkpdir, sumfile))
        end
        mode = entrydata.fetch('bakfile_mode', nil)
        if (mode and bkpfile and sumfile) then
            FileUtils.chmod(mode, File.join(bkpdir, bkpfile))
            FileUtils.chmod(mode, File.join(bkpdir, sumfile))
        end
    end

end
