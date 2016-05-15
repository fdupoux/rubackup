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

# Implementation of the backup module for sending to aws-s3

require "#{$progdir}/lib/modules/remote-generic"
require 'rubygems'
require 'aws-sdk-resources'

class ModuleRemoteAwsS3 < ModuleRemoteGeneric

    # Initialization
    def initialize()
    end

    # Returns validation types used by this module
    def get_options_validation()
        [
            ValidationRule.new(name='s3_bucket', mandatory=true, defval=nil, validator=S3BucketReferenceValidator.new),
        ]
    end

    # Prepare access to S3
    def get_s3_access(remote_opts)
        # extract information from parameters
        bucketdata = remote_opts.fetch('s3_bucket')
        awsregion = bucketdata.fetch('awsregion')
        # get access keys if they are defined
        keypublic = nil
        keysecret = nil
        accesskey = bucketdata.fetch('accesskey', nil)
        if accesskey then
            keypublic = accesskey.fetch('public')
            keysecret = accesskey.fetch('secret')
            creds = Aws::Credentials.new(keypublic, keysecret)
            s3clt = Aws::S3::Client.new(region: awsregion, credentials: creds)
            s3res = Aws::S3::Resource.new(:access_key_id => keypublic, :secret_access_key => keysecret, :region => awsregion)
        else
            s3clt = Aws::S3::Client.new(region: awsregion)
            s3res = Aws::S3::Resource.new(:region => awsregion)
        end
        # return s3 objects
        return s3clt,s3res
    end

    # Return list of file names found in this bucket for this type of backup
    def list(entrydata)
        results = Array.new
        remote_opts = entrydata.fetch('remote_opts')
        basename = entrydata['bakfile_basename']
        bucketdata = remote_opts.fetch('s3_bucket')
        bucketname = bucketdata.fetch('bucket')
        s3clt,s3res = get_s3_access(remote_opts)
        allobjs = s3clt.list_objects({bucket: bucketname}).contents # all objects including checksums files
        coreobj = allobjs.select { |obj| ((obj.key =~ /#{basename}-(\d{8})/) and (Checksum.checksum?(obj.key) == false)) }
        coreobj.each do |obj|
            bakfile = Bakfile.new
            bakfile.name = obj.key
            bakfile.size = obj.size
            bakfile.date = Scheduling.determine_creation_date(bakfile.name, basename)
            Checksum.list_extensions().each do |sumext|
                sumobj = allobjs.select { |o| o.key == "#{bakfile.name}.#{sumext}" }
                if (sumobj.length == 1) then
                    bakfile.csum.push(sumext)
                end
            end
            results.push(bakfile)
        end
        return results
    end

    # Upload a file to an S3 bucket
    def send(entrydata, fullpath)
        remote_opts = entrydata.fetch('remote_opts')
        bucketdata = remote_opts.fetch('s3_bucket')
        bucketname = bucketdata.fetch('bucket')
        s3clt,s3res = get_s3_access(remote_opts)
        filename = File.basename(fullpath)
        s3res.bucket(bucketname).object(filename).upload_file(fullpath)
    end

    # Delete a file in the bucket
    def delete(entrydata, filename)
        remote_opts = entrydata.fetch('remote_opts')
        bucketdata = remote_opts.fetch('s3_bucket')
        bucketname = bucketdata.fetch('bucket')
        s3clt,s3res = get_s3_access(remote_opts)
        s3clt.delete_object( { bucket: bucketname, key: filename} )
    end

end
