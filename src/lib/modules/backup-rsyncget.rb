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

# Implementation of the backup module for rsyncget

require "#{$progdir}/lib/modules/backup-generic"

class ModuleBackupRsyncGet < ModuleBackupGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='remote_host', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='remote_user', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='remote_path', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='extension', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    def backup(entrydata)
        backup_opts = entrydata.fetch('backup_opts')
        bkpdir = entrydata.fetch('bakfile_dir')
        remote_host = backup_opts.fetch('remote_host')
        remote_user = backup_opts.fetch('remote_user')
        remote_path = backup_opts.fetch('remote_path')
        extension = backup_opts.fetch('extension')
        command_opts = backup_opts.fetch('command_opts')

        # Verify if the rsync command can be found
        rsync = Utilities.path_to_command("rsync")
        raise "Command 'rsync' not found in PATH. Check rsync is installed and in PATH" if not rsync

        # Prepare rsync command
        rsyncopts=["-e", "ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0"]
        #rsyncopts+=["--partial", "--inplace", "--no-o", "--no-g"]
        rsyncsrc="#{remote_user}@#{remote_host}:#{remote_path}"
        basename = basename_with_date(entrydata)
        filename="#{basename}#{extension}"
        bakfile="#{bkpdir}/#{filename}"
        cmd1 = [rsync] + rsyncopts + command_opts + ["#{rsyncsrc}/#{filename}", "#{bakfile}"]

        begin
            # Execute pipeline of commands
            $output.write(3, "Running pipeline: cmd1=#{cmd1} ...")
            piperes = Open3.pipeline(cmd1)

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
