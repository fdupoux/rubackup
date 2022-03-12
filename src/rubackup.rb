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

require 'getoptlong'
require 'fileutils'
require 'pathname'
require 'socket'
require 'open3'
require 'date'
require 'yaml'

# Define constants
$RUBACKUP_VERSION = "0.2.3"
$RUBACKUP_MIN_RUBY = 1.9 # Required by Open3.pipeline()

# Define global variables
$progdir = File.dirname(__FILE__)
$curdate = Time.now.strftime("%Y%m%d")
$today = Date.today # date should not change if scripts starts just before midnight
$yamlcfg = "/etc/rubackup.d/*.yaml"
$output = nil

# Check ruby version is recent enough
if (RUBY_VERSION.to_f < $RUBACKUP_MIN_RUBY) then
    puts "ERROR: #{$PROGRAM_NAME} requires ruby-#{$RUBACKUP_MIN_RUBY} or a newer version to run properly."
    exit(10) # ExitStatus::EXITST_RUBY_TOO_OLD (value hard-coded as module with exit status not loaded yet)
end

# Load important application modules
require "#{$progdir}/lib/core/core"
require "#{$progdir}/lib/core/config"
require "#{$progdir}/lib/core/modules"
require "#{$progdir}/lib/core/bakfile"
require "#{$progdir}/lib/core/validators"
require "#{$progdir}/lib/core/exit-status"
require "#{$progdir}/lib/utils/lvm-snapshots"
require "#{$progdir}/lib/utils/scheduling"
require "#{$progdir}/lib/utils/checksums"
require "#{$progdir}/lib/utils/services"
require "#{$progdir}/lib/utils/utilities"
require "#{$progdir}/lib/utils/output"

# List of supported command line arguments
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--config', '-n', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--outlevel', '-o', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--loglevel', '-L', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--logfile', '-l', GetoptLong::REQUIRED_ARGUMENT ],
)

# Parse command line arguments
argval = Hash.new
argval['outlevel'] = 3
argval['loglevel'] = 4
argval['logfile'] = nil

# Parse command line arguments
opts.each do |opt, arg|
    case opt
    when '--help'
        puts("Usage: #{$PROGRAM_NAME} [<options>]")
        puts("Options:")
        puts("  --config <configuration-files>: use alternative configuration file(s)")
        puts("    example1: --config '/etc/rubackup/*.yaml' (config in a multiple files)")
        puts("    example2: --config '/etc/rubackup.yaml' (config in a single file)")
        puts("  --outlevel <level-for-output>: set verbosity of console messages (between 0 and 6)")
        puts("    example: --outlevel 4 (use higer level of verbosity to get more details and debugging)")
        puts("  --loglevel <level-for-logfile>: set verbosity of messages logged to file (between 0 and 6)")
        puts("  --logfile <path-to-logfile>: enable logging to a file (cf --loglevel)")
        puts("    example: --logfile /var/log/rubackup.log --loglevel 5")
        exit(ExitStatus::EXITST_SUCCESS)
    when '--config'
        $yamlcfg = arg
    when '--logfile'
        argval['logfile'] = arg
    when '--outlevel'
        if ((arg !~ /^\d+$/) or (arg.to_i < 0) or (arg.to_i > 6)) then
            $output.write(0, "Option '--outlevel <output-detail-level>' must be a number between 0 and 6")
            exit(ExitStatus::EXITST_INVALID_ARGUMENTS)
        else
            argval['outlevel'] = arg.to_i
        end
    when '--loglevel'
        if ((arg !~ /^\d+$/) or (arg.to_i < 0) or (arg.to_i > 6)) then
            $output.write(0, "Option '--loglevel <output-detail-level>' must be a number between 0 and 6")
            exit(ExitStatus::EXITST_INVALID_ARGUMENTS)
        else
            argval['loglevel'] = arg.to_i
        end
    end
end

# Create a new object to manage output messages printed to console and to log file
$output = Output.new(argval['outlevel'], argval['loglevel'], argval['logfile'])
$output.twrite(0, "#{$PROGRAM_NAME} version #{$RUBACKUP_VERSION} starting")

# The user configuration can extend PATH to we ca access programs in other directories
def update_path()
    path_extra = $globcfg.fetch('path_extra', nil)
    if path_extra then
        $output.write(1, "Updating PATH environment with extra directories from path_extra: #{path_extra} ...")
        envpath = ENV['PATH'].split(":")
        path_extra.each { |dir| envpath.push(dir) unless envpath.include?(dir) }
        ENV['PATH'] = envpath.join(":")
    end
    $output.write(1, "PATH=#{ENV['PATH']}")
end

# main function
$output.separator(1)
load_modules()
$output.separator(1)
config = load_config($yamlcfg)
$output.separator(1)
validate_config(config)
$output.separator(1)
update_path()
$output.separator(1)
result = process_entries()
exitst = (result == true) ? (ExitStatus::EXITST_SUCCESS) : (ExitStatus::EXITST_OPERATIONS_FAILURES)
$output.twrite(0, "#{$PROGRAM_NAME} finished with exit status #{exitst}")
exit(exitst)
