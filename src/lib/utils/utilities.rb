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

# Implement various functions used by other modules

module Utilities

    # find full path to a command
    def Utilities.path_to_command(command)
        progdirs = ENV['PATH'].split(':').select { |dir| File.directory?(dir) }
        progdirs.each do |dir|
            fullpath = File.join(dir, command)
            return fullpath if File.exist?(fullpath)
        end
        return nil
    end

    # return the official extension associated to a particular compression program
    def Utilities.compress_to_extension(compress_prog)
        case compress_prog
        when "lzop"
            return "lzo"
        when "lz4"
            return "lz4"
        when "gzip"
            return "gz"
        when "bzip2"
            return "bz2"
        when "xz"
            return "xz"
        else
            return nil
        end
    end

end
