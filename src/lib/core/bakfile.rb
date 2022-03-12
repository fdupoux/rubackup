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

# Represent existing backup files which are found on either the primary or in
# remote backups

class Bakfile

    attr_accessor :name
    attr_accessor :date
    attr_accessor :size
    attr_accessor :csum

    def initialize()
        @name = nil
        @date = nil
        @size = nil
        @csum = Array.new
    end

    # how old the file is in number of days
    def age()
       $today.mjd - @date.mjd 
    end

    # Return file names for all files related to this backup: main backup and checksum files
    def list_all_related_files()
        results = Array.new
        return results if (@name == nil)
        results.push(@name)
        @csum.each do | sumtype |
            csumfile = "#{@name}.#{sumtype}"
            results.push(csumfile)
        end
        return results
    end
    
    # show list of checksums which exist for this backup
    def sumlist()
        @csum.sort.join(',')
    end
end
