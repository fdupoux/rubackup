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

# Implements support for creating and detecting checksum of backup files

require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module Checksum

    # Create a checksum file for a backup file
    def Checksum.create(bkpdir, bakfile, sumtype='sha256')
        case sumtype
            when 'md5' then
                checksum = Digest::MD5.new
            when 'sha1' then
                checksum = Digest::SHA1.new
            when 'sha256' then
                checksum = Digest::SHA2.new
            else
                raise "Unsupported checksum type: #{sumtype}"
        end

        # Calculate checksum using pure ruby code
        sumfile = "#{bakfile}.#{sumtype}"
        bkppath = File.join(bkpdir, bakfile)
        sumpath = File.join(bkpdir, sumfile)
        File.open(bkppath) do |file|
            buffer = ''
            while not file.eof
                file.read(4096, buffer)
                checksum.update(buffer)
            end
        end
        File.open(sumpath, "w") do |file|
            file.write("#{checksum.to_s}  #{bakfile}\n")
        end
        return sumfile
    end

    # Say if a file is a checksum file based on its filename
    def Checksum.checksum?(filename)
        if (filename =~ /(.md5|.sha1|.sha224|.sha256|.sha384|.sha512)$/)
            return true
        else
            return false
        end
    end

    # List all possible checksum extensions
    def Checksum.list_extensions()
        return ['md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512']
    end

end
