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

# Defines the supported exit status returned by rubackup

module ExitStatus
  EXITST_SUCCESS                = 0  # Program was successful
  EXITST_EXCEPTION              = 1  # Program has thrown an exception which was not handled
  EXITST_RUBY_TOO_OLD           = 10 # The ruby version used to run this program is too old
  EXITST_INVALID_ARGUMENTS      = 11 # Errors in the arguments passed on the command line
  EXITST_INVALID_CONFIG_FILES   = 12 # Failed to find configuration files
  EXITST_INVALID_CONFIG_DATA    = 13 # Failed to validate options in the configuration files
  EXITST_OPERATIONS_FAILURES    = 20 # Operations such as backup or rotation failed
end
