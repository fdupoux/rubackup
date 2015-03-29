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

# Implementation of the notification module to send an email via AWS SES

require "#{$progdir}/lib/modules/notify-generic"
require 'rubygems'
require 'aws-sdk-v1'

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

    def get_ses_acces(sesmedia)
        # extract information from parameters
        awsregion = sesmedia.fetch('awsregion')
        accesskey = sesmedia.fetch('accesskey')
        keypublic = accesskey['public']
        keysecret = accesskey['secret']
        # get an instance of the S3 interface
        ses = AWS::SimpleEmailService.new(
            :access_key_id => keypublic,
            :secret_access_key => keysecret,
            :region => awsregion)
        # return s3 object
        return ses
    end

    def message(notify_args, subject, contents)
        # extract information from parameters
        sesmedia = notify_args.fetch('ses_media')
        mailsrc = sesmedia.fetch('mailsrc')
        maildst = sesmedia.fetch('maildst')
        ses = get_ses_acces(sesmedia)
        ses.send_email(
             :to        => [maildst],
             :from      => mailsrc,
             :subject   => subject,
             :body_text => contents)
    end

end
