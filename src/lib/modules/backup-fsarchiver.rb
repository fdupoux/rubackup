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

# Implementation of the backup module for fsarchiver

require "#{$progdir}/lib/modules/backup-generic"
require "#{$progdir}/lib/utils/lvm-snapshots"
require "#{$progdir}/lib/utils/checksums"

class ModuleBackupFsarchiver < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='filesystems', mandatory=true, defval=nil, validator=FsaArrayValidator.new),
            ValidationRule.new(name='excludes', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='description', mandatory=false, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    def backup(entrydata)

        # Configuration
        backup_opts = entrydata.fetch('backup_opts')
        bkpdir = entrydata.fetch('bakfile_dir')
        filesystems = backup_opts.fetch('filesystems')
        description = backup_opts.fetch('description', nil)
        excludes = backup_opts.fetch('excludes')
        command_opts = backup_opts.fetch('command_opts')
        basename = basename_with_date(entrydata)

        # initialization
        curtime = Time.now.to_i
        fsadevs = Array.new
        snaplist = Array.new

        # Verify if the fsarchiver command can be found
        fsarchiver = Utilities.path_to_command("fsarchiver")
        raise "Command 'fsarchiver' not found in PATH. Check fsarchiver is installed and in PATH" if not fsarchiver

        begin

            # Prepare fsarchiver parameters
            filename = "#{basename}.fsa"
            bakfile = File.join(bkpdir, filename)
            logfile = File.join(bkpdir, "#{filename}.log")
            File.delete(bakfile) if File.exist?(bakfile)
            File.delete(logfile) if File.exist?(logfile)

            # Create LVM Snapshots if required
            filesystems.each do |fsdev|
                blockdev = fsdev.fetch('block_device')
                snaptype = fsdev.fetch('snapshot_type', nil)
                snapsize = fsdev.fetch('snapshot_size', '1024M')
                case snaptype
                    when 'lvm' then
                        lvmsnap = LvmSnapshots.create(blockdev, curtime, snapsize)
                        snaplist << lvmsnap
                        fsadevs << lvmsnap
                    when nil then
                        fsadevs << blockdev
                    else 
                        raise "Unsupported snapshot type: #{snaptype}"
                end
            end

            # Prepare fsarchiver command
            fsa_excl = excludes.map { |excl| "--exclude='#{excl}'" }.join(' ')
            if description then
                fsa_desc = "-L '#{description}'"
            else
                fsa_desc = ""
            end
            if command_opts then
                fsa_opts = command_opts.join(' ')
            else
                fsa_opts = ""
            end
            command="#{fsarchiver} savefs #{fsa_excl} #{fsa_desc} #{fsa_opts} #{bakfile} #{fsadevs.join(' ')}"

            # Execute command
            $output.write(3, "Running fsarchiver: #{command}")
            (out, res) = Open3.capture2e(command)

            # Error handling
            if ((res.exited? == false) or (res.exitstatus != 0)) then
                raise "fsarchiver failed: #{command}\n#{out}"
            end

            $output.write(4, "Successfully written [#{bakfile}]")
            return filename

        rescue StandardError => e
            # Do not leave a partial or failed backup
            if File.exist?(bakfile) then
                $output.write(1, "Deleting failed backup file: #{bakfile}")
                File.delete(bakfile)
            end
            # Propagate exception to upper level
            raise e
        ensure # do the cleanup in any case (success or failure)
            # Remove snapshots in any case (even if backup failed)
            snaplist.each { |snap| LvmSnapshots.destroy(snap) }
        end

    end

end
