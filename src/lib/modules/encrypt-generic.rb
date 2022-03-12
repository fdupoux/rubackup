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

# Generic base class for encryption modules

class ModuleEncryptGeneric

    # Initialization
    def initialize()
        raise NotImplementedError, 'You must implement the initialize() function'
    end

    # Return list of rules to validate the module specific config options
    def get_options_validation()
        raise NotImplementedError, 'You must implement the get_options_validation() function'
    end

    # Implementation of the encryption
    def encrypt(entrydata, bkpfile)
        raise NotImplementedError, 'You must implement the send() function'
    end

end
