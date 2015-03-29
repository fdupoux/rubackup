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

# Implementation of the backup module for mysqldump

require "#{$progdir}/lib/modules/backup-generic"

class ModuleBackupMysqldp < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='dbname', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='dbhost', mandatory=false, defval='127.0.0.1', validator=StringValidator.new),
            ValidationRule.new(name='dbuser', mandatory=false, defval='root', validator=StringValidator.new),
            ValidationRule.new(name='dbpass', mandatory=false, defval='', validator=StringValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
            ValidationRule.new(name='compress_prog', mandatory=false, defval='xz', validator=CompressProgValidator.new),
            ValidationRule.new(name='compress_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    def backup(entrydata)
        backup_opts = entrydata.fetch('backup_opts')
        basename = basename_with_date(entrydata)
        bkpdir = entrydata.fetch('bakfile_dir')
        dbname = backup_opts.fetch('dbname')
        dbhost = backup_opts.fetch('dbhost')
        dbuser = backup_opts.fetch('dbuser')
        dbpass = backup_opts.fetch('dbpass')
        command_opts = backup_opts.fetch('command_opts')
        compress_prog = backup_opts.fetch('compress_prog')
        compress_opts = backup_opts.fetch('compress_opts')

        # Verify compression program is available
        compressext = Utilities.compress_to_extension(compress_prog)
        raise "Invalid compression program: '#{compress_prog}'" if not compressext
        compresspath = Utilities.path_to_command(compress_prog)
        raise "Command '#{compress_prog}' not found in PATH. Check #{compress_prog} is installed and in PATH" if not compresspath

        # Determine file name and path
        filename = "#{basename}.sql.#{compressext}"
        bakfile = File.join(bkpdir, filename)
        File.delete(bakfile) if File.exist?(bakfile)

        # Verify if the mysqldump command can be found
        mysqldump = Utilities.path_to_command("mysqldump")
        raise "Command 'mysqldump' not found in PATH. Check mysqldump is installed and in PATH" if not mysqldump

        # Preparing pipeline of commands
        cmd1 = Array.new
        cmd1.concat([mysqldump])
        cmd1.concat(["--host=#{dbhost}"])
        cmd1.concat(["--user=#{dbuser}"])
        cmd1.concat(["--password=#{dbpass}"]) if (dbpass.length > 0)
        cmd1.concat(command_opts)
        cmd1.concat([dbname])
        cmd2 = Array.new
        cmd2.concat([compresspath])
        cmd2.concat(compress_opts)

        begin
            # Execute pipeline of commands
            $output.write(3, "Running pipeline: cmd1=#{cmd1} cmd2=#{cmd2} ...")
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
