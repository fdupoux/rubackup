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

# Implementation of the backup module for pgsqldump

require "#{$progdir}/lib/modules/backup-generic"

class ModuleBackupPgsqldp < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='dbname', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='dbhost', mandatory=false, defval='127.0.0.1', validator=StringValidator.new),
            ValidationRule.new(name='dbuser', mandatory=false, defval='postgres', validator=StringValidator.new),
            ValidationRule.new(name='dbpass', mandatory=false, defval='', validator=StringValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
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

        # Verify if the pg_dump command can be found
        pg_dump = Utilities.path_to_command("pg_dump")
        raise "Command 'pg_dump' not found in PATH. Check pg_dump is installed and in PATH" if not pg_dump

        filename = "#{basename}.pgdump"
        bakfile = File.join(bkpdir, filename)
        File.delete(bakfile) if File.exist?(bakfile)

        # Preparing pipeline of commands
        cmd1 = [pg_dump]
        cmd1.concat(["--host=#{dbhost}"])
        cmd1.concat(["--user=#{dbuser}"])
        cmd1.concat(["--password=#{dbpass}"]) if (dbpass.length > 0)
        cmd1.concat(command_opts)
        cmd1.concat([dbname])

        begin
            # Execute pipeline of commands
            $output.write(3, "Running pipeline: cmd1=#{cmd1}  ...")
            piperes = Open3.pipeline(cmd1, :out=>bakfile)

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
