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

# Implementation of the backup module for encrypting using gnupg

require "#{$progdir}/lib/modules/encrypt-generic"

class ModuleEncryptGnupg < ModuleEncryptGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='recipient', mandatory=true, defval=nil, validator=StringValidator.new),
            ValidationRule.new(name='command_opts', mandatory=false, defval=[], validator=ArrayValidator.new),
        ]
    end

    # Encrypt a file using gnupg
    def encrypt(entrydata, bkpfile)

        # Get parameters from configuration
        encrypt_opts = entrydata.fetch('encrypt_opts')
        bkpdir = entrydata.fetch('bakfile_dir')
        recipient = encrypt_opts.fetch('recipient')
        command_opts = encrypt_opts.fetch('command_opts')

        # Calculate file names and paths
        encbkpfile = "#{bkpfile}.gpg"
        srcfile = File.join(bkpdir, bkpfile)
        dstfile = File.join(bkpdir, encbkpfile)

        # Verify if the gpg program can be found
        gpg = Utilities.path_to_command("gpg")
        raise "Command 'gpg' not found in PATH. Check gpg is installed and in PATH" if not gpg

        # Delete destination file if it already exists so it gets recreated (overwrite)
        File.delete(dstfile) if File.file?(dstfile)

        # Preparing commands
        command = "#{gpg} --output '#{dstfile}' --recipient '#{recipient}' #{command_opts.join(' ')} --encrypt '#{srcfile}'"

        begin
            # Execute command
            $output.write(3, "Running GnuPG: #{command}")
            (out, res) = Open3.capture2e(command)

            # Error handling
            if ((res.exited? == false) or (res.exitstatus != 0)) then
                raise "GnuPG failed: #{command}\n#{out}"
            else
                $output.write(4, "Deleting original unencrypted file: #{srcfile}")
                File.delete(srcfile)
            end

            return encbkpfile

        rescue StandardError => e
            # Do not leave a partial or failed backup
            if File.exist?(dstfile) then
                $output.write(1, "Deleting failed backup file: #{dstfile}")
                File.delete(dstfile)
            end
            # Propagate exception to upper level
            raise e
        end

    end

end
