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

# Implementation of the backup module for tarballs

require "#{$progdir}/lib/modules/backup-generic"

class ModuleBackupTarball < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='includes', mandatory=true,  defval=nil, validator=FileOrDirListValidator.new),
            ValidationRule.new(name='excludes', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='compress_prog', mandatory=false, defval='xz', validator=CompressProgValidator.new),
            ValidationRule.new(name='compress_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    # Implementation of the tar backups
    def backup(entrydata)
        backup_opts = entrydata.fetch('backup_opts')
        basename = basename_with_date(entrydata)
        bkpdir = entrydata.fetch('bakfile_dir')
        includes = backup_opts.fetch('includes')
        excludes = backup_opts.fetch('excludes')
        command_opts = backup_opts.fetch('command_opts')
        compress_prog = backup_opts.fetch('compress_prog')
        compress_opts = backup_opts.fetch('compress_opts')

        # Verify if the tar command can be found
        tar = Utilities.path_to_command("tar")
        raise "Command 'tar' not found in PATH. Check tar is installed and in PATH" if not tar

        # Verify compression program is available
        compressext = Utilities.compress_to_extension(compress_prog)
        raise "Invalid compression program: '#{compress_prog}'" if not compressext
        compresspath = Utilities.path_to_command(compress_prog)
        raise "Command '#{compress_prog}' not found in PATH. Check #{compress_prog} is installed and in PATH" if not compresspath

        # Determine file name and path
        filename = "#{basename}.tar.#{compressext}"
        bakfile = File.join(bkpdir, filename)
        logfile = File.join(bkpdir, "#{filename}.log")
        File.delete(bakfile) if File.exist?(bakfile)
        File.delete(logfile) if File.exist?(logfile)

        # Preparing pipeline of commands
        cmd1 = ["#{tar}",  "--create", "--file=-"] + command_opts + includes + excludes.map { |excl| "--exclude=#{excl}" }
        cmd2 = [compresspath] + compress_opts

        begin
            # Execute pipeline of commands
            $output.write(3, "Running pipeline: cmd1=#{cmd1} cmd2=#{cmd2} ...")
            #piperes = Open3.pipeline(cmd1, cmd2, :out=>bakfile, :err=>logfile)
            #piperes = Open3.pipeline(cmd1, cmd2, :out=>bakfile, :err=>logfile, :err=>[:child, :err])
            piperes = Open3.pipeline(cmd1, cmd2, :out=>bakfile)

            # Check results
            errcount = 0
            piperes.each do |ps|
                $output.write(4, "Process: pid=[#{ps.pid}] exited=[#{ps.exited?}] exitstatus=[#{ps.exitstatus}]")
                errcount += 1 if ((ps.exited? == false) or (ps.exitstatus != 0))
            end

            # Error handling
            if (errcount > 0) then
                raise "FAILED commands: cmd1=#{cmd1} cmd2=#{cmd2}"
            end

            return filename
        rescue StandardError => e
            # Do not leave a partial or failed backup
            if File.exist?(bakfile) then
                $output.write(1, "Deleting failed backup file: #{bakfile}")
                File.delete(bakfile)
            end
            # Propagate exception to upper level
            raise e
        end

    end

end
