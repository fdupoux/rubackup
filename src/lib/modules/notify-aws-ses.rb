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

# Implementation of the notification module to send an email via AWS SES

require "#{$progdir}/lib/modules/notify-generic"
require 'rubygems'
require 'aws-sdk-core'

class ModuleNotifyAwsSes < ModuleNotifyGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='ses_media', mandatory=true, defval=nil, validator=SesMediaValidator.new),
        ]
    end

    def get_ses_access(sesmedia)
        # extract information from parameters
        awsregion = sesmedia.fetch('awsregion')
        # get access keys if they are defined
        keypublic = nil
        keysecret = nil
        accesskey = sesmedia.fetch('accesskey')
        if accesskey then
            keypublic = accesskey.fetch('public')
            keysecret = accesskey.fetch('secret')
            creds = Aws::Credentials.new(keypublic, keysecret)
            ses = Aws::SES::Client.new(region: awsregion, credentials: creds)
        else
            ses = Aws::SES::Client.new(region: awsregion)
        end
        return ses
    end

    def message(notify_args, subject, contents)
        # extract information from parameters
        sesmedia = notify_args.fetch('ses_media')
        mailsrc = sesmedia.fetch('mailsrc')
        maildst = sesmedia.fetch('maildst')
        ses = get_ses_access(sesmedia)
        ses.send_email({
            source: mailsrc,
            destination: { to_addresses: [maildst] },
            message: { subject: { data: subject },
            body: { text: { data: contents } } }
        })
    end

end
