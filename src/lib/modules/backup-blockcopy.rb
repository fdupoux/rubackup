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

# Implementation of the backup module for physical copies of block devices

require "#{$progdir}/lib/modules/backup-generic"
require "#{$progdir}/lib/utils/lvm-snapshots"
require "#{$progdir}/lib/utils/checksums"

class ModuleBackupBlockCopy < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='block_device', mandatory=true, defval=nil, validator=BlockDeviceValidator.new),
            ValidationRule.new(name='snapshot_type', mandatory=false, defval=nil, validator=SnapshotTypeValidator.new),
            ValidationRule.new(name='snapshot_size', mandatory=false, defval='1024M', validator=ByteSizeValidator.new),
            ValidationRule.new(name='compress_prog', mandatory=false, defval='xz', validator=CompressProgValidator.new),
            ValidationRule.new(name='compress_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    def backup(entrydata)
        backup_opts = entrydata.fetch('backup_opts')
        basename = basename_with_date(entrydata)
        bkpdir = entrydata.fetch('bakfile_dir')
        blockdev = backup_opts.fetch('block_device')
        snaptype = backup_opts.fetch('snapshot_type', nil)
        snapsize = backup_opts.fetch('snapshot_size', '1024M')
        compress_prog = backup_opts.fetch('compress_prog')
        compress_opts = backup_opts.fetch('compress_opts')

        # Verify compression program is available
        compressext = Utilities.compress_to_extension(compress_prog)
        raise "Invalid compression program: '#{compress_prog}'" if not compressext
        compresspath = Utilities.path_to_command(compress_prog)
        raise "Command '#{compress_prog}' not found in PATH. Check #{compress_prog} is installed and in PATH" if not compresspath

        # Determine backup filename and path
        filename = "#{basename}.img.#{compressext}"
        bakfile = File.join(bkpdir, filename)
        File.delete(bakfile) if File.exist?(bakfile)

        begin

            # Create snapshot if requested in the backup options
            snaplist = Array.new
            case snaptype
            when 'lvm' then
                curtime = Time.now.to_i
                devicebkp = LvmSnapshots.create(blockdev, curtime, snapsize)
                snaplist << devicebkp
            when nil then
                devicebkp << blockdev
            else
                raise "Unsupported snapshot type: #{snaptype}"
            end

            # Preparing pipeline of commands
            $output.write(4, "Copying data from '#{devicebkp}' and compressing to '#{bakfile}' ...")
            cmd1 = [compresspath] + compress_opts

            # Execute pipeline of commands
            $output.write(3, "Running pipeline: cmd1=#{cmd1} ...")
            piperes = Open3.pipeline(cmd1, :in=>devicebkp, :out=>bakfile)

            # Check results
            errcount = 0
            piperes.each do |ps|
                $output.write(4, "Process: pid=[#{ps.pid}] exited=[#{ps.exited?}] exitstatus=[#{ps.exitstatus}]")
                errcount += 1 if ((ps.exited? == false) or (ps.exitstatus != 0))
            end

            # Error handling
            if (errcount > 0) then
                raise "FAILED command: cmd1=#{cmd1}"
            end

            $output.write(4, "Successfully created backup file: #{bakfile}")
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
