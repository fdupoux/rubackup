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

# Support for writing messages to either the console or/and to a logfile with
# a central control for verbosity

# Output levels:
# - 0. Fatal error or very important message (program is starting)
# - 1. First level information about major things the program is doing (Reading config, etc)
# - 2. Second level information about what program is going (Processing a particular entry)
# - 3. Third level information about what the program is going (Uploading a file as part of a backup entry)
# - 4. First level of debugging (such as showing the list of local or remote files)
# - 5. Second level of debugging
# - 6. Very detailed debugging

class Output

    # Initialization
    def initialize(outlevel, loglevel, logfile = nil)
        @outlevel = outlevel
        @loglevel = loglevel
        init_logfile(logfile)
    end

    # Initialize logfile
    def init_logfile(logfile)
        if logfile then
            @logfile = File.new(logfile, "w")
        else
            @logfile = nil
        end
    end

    # Produce message for either the console output or a log file
    def write(level, message)
        fullmsg = String.new
        if (level >= 2) then # indent more detailed messages to distringuish levels of importance
            fullmsg += ' '*(4*level)
        end
        fullmsg += message.to_s

        # write message to standard output if required
        if (@outlevel >= level) then
            puts(fullmsg)
        end

        # write message to log file if required
        if ((@logfile != nil) and (@loglevel >= level)) then
            @logfile.write("#{fullmsg}\n")
        end
    end

    # Produce message for either the console output or a log file with the time in prefix
    def twrite(level, message)
        curtime = Time.now.strftime("%Y%m%d_%H:%M:%S: ")
        write(level, curtime + message)
    end

    # Show line to separate different sections of the output
    def separator(level)
        sepchar = ((level < 2) ? ('=') : ('-'))
        write(level, sepchar*80)
    end

end
