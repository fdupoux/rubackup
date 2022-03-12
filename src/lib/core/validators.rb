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

# Defines validator classes for basic items which are found in the
# configuration entries. This actually does two things: first it validates
# input data, and it also replaces references with the actual values. For
# example when an item has to be the name of an AWS Access Key which is
# defined in another section the validator will check the name corresponds
# to an existing Access Key and it will also replace the reference with the
# actual access keys. Hence the class using the hash can directly use the
# values without having to do another lookup or verification.

# -----------------------------------------------------------------------------

# Object used to store validation rules
class ValidationRule
    attr_accessor :name, :mandatory, :defval, :validator
    def initialize(name, mandatory, defval, validator)
        @name = name
        @mandatory = mandatory
        @defval = defval
        @validator = validator
    end
end

# -----------------------------------------------------------------------------

class ObjectValidator # all validation classes inherit this class
    def initialize
    end

    def validate_and_substitute(object, errmsg)
        raise NotImplementedError, 'You must implement the validate() function'
    end
end

class HashValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Hash) then
            errmsg.push("This is not a valid hash: '#{object}'")
            return object # failure
        end
        return object # success
    end
end

class ArrayValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Array) then
            errmsg.push("This is not a valid array: '#{object}'")
            return object # failure
        end
        return object # success
    end
end

class StringValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(String) then
            errmsg.push("This is not a valid string: '#{object}'")
            return object # failure
        end
        return object # success
    end
end

class IntegerValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        inval = object.to_i
        if (object.to_s != inval.to_s) then
            errmsg.push("This is not a valid integer: '#{object}'")
            return object # failure
        end
        return object # success
    end
end

class BooleanValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if ((object.is_a?(TrueClass) == false) and (object.is_a?(FalseClass) == false)) then
            errmsg.push("This is not a valid boolean: '#{object}'")
            return object # failure
        end
        return object # success
    end
end

class DirectoryValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not File.directory?(object) then
            errmsg.push("This is not a valid directory: #{object}")
            return object # failure
        end
        return object # success
    end
end

class FileOrDirListValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Array) then
            errmsg.push("This is not a valid array: #{object}. Expects a list of existing files or directories.")
            return object # failure
        end
        object.each do |item|
            if not (File.directory?(item) or File.exist?(item)) then
                errmsg.push("List item '#{item}' is not a valid file or directory")
                return object # failure
            end
        end
        return object # success
    end
end

class DirListValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Array) then
            errmsg.push("This is not a valid array: #{object}. Expects a list of existing directories.")
            return object # failure
        end
        object.each do |item|
            if not File.directory?(item) then
                errmsg.push("List item '#{item}' is not a valid directory")
                return object # failure
            end
        end
        return object # success
    end
end

class CompressProgValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not Utilities.compress_to_extension(object) then
            errmsg.push("This is not a valid compression program: '#{object}'. Expected something such as 'gzip' or 'xz' without any path.")
            return object # failure
        end
        return object # success
    end
end

# Size in bytes or MB/GB
class ByteSizeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if (object !~ /^[0-9]+(M|G)$/) then
            errmsg.push("This is not a valid data size: '#{object}'. Expected size such as 768M or 10G")
            return object # failure
        end
        return object # success
    end
end

class DayOfMonthValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Integer) then
            errmsg.push("This is not a valid integer: '#{object}'")
            return object # failure
        end
        inval = object.to_i
        if (inval < 1) then
            errmsg.push("Invalid day of month: '#{object}'. It cannot be less than 1")
            return object # failure
        end
        if (inval > 31) then
            errmsg.push("Invalid day of month: '#{object}'. It cannot be greater than 31")
            return object # failure
        end
        return object # success
    end
end

class DayOfWeekValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        list_dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        if not list_dow.include?(object) then
            errmsg.push("Invalid day of week: '#{object}': must be one of #{list_dow.split(',')}")
            return object # failure
        end
        # convert name of the day into an integer
        day_of_week = Date._strptime(object, '%a').fetch(:wday)
        return day_of_week # success
    end
end

class AwsRegionValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if object !~ /^[a-z0-9\-]+$/ then
            errmsg.push("This is not a valid AWS Region (eg: 'us-west-2')")
            return object # failure
        end
        return object # success
    end
end

class AwsAccessKeyPublicValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if object !~ /^[A-Z0-9]{20}$/ then
            errmsg.push("This is not a valid public part of an AWS access key (20 characters alphanumeric string)")
            return object # failure
        end
        return object # success
    end
end

class AwsAccessKeySecretValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if object !~ /^[A-Za-z0-9\+\/\=]{40}$/ then
            errmsg.push("This is not a valid secret part of an AWS access key (40 characters string)")
            return object # failure
        end
        return object # success
    end
end

class AwsAccessKeyReferenceValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        accesskeys = $resources.fetch('aws_access_keys', nil)
        if not accesskeys then
            errmsg.push("Cannot find hash for resource type 'aws_access_keys'")
            return object # failure
        end
        thiskey = accesskeys.fetch(object, nil)
        if not thiskey then
            errmsg.push("Cannot find access key with this name: '#{object}'")
            return object # failure
        end
        return thiskey # success
    end
end

class ScheduleTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        schedules = $resources.fetch('schedules', nil)
        if not schedules then
            errmsg.push("Cannot find hash for resource type 'schedules'")
            return object # failure
        end
        thissched = schedules.fetch(object, nil)
        if not thissched then
            errmsg.push("Cannot find schedules with this name: '#{object}'")
            return object # failure
        end
        return thissched # success
    end
end

class SesMediaValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        aws_ses_medias = $resources.fetch('aws_ses_medias', nil)
        if not aws_ses_medias then
            errmsg.push("Cannot find hash for resource type 'aws_ses_medias'")
            return object # failure
        end
        media = aws_ses_medias.fetch(object, nil)
        if not media then
            errmsg.push("Cannot find ses media with this name: '#{object}'")
            return object # failure
        end
        return media # success
    end
end

class S3BucketReferenceValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        aws_s3_buckets = $resources.fetch('aws_s3_buckets', nil)
        if not aws_s3_buckets then
            errmsg.push("Cannot find hash for resource type 'aws_s3_buckets'")
            return object # failure
        end
        bucket = aws_s3_buckets.fetch(object, nil)
        if not bucket then
            errmsg.push("Cannot find S3 bucket with this name: '#{object}'")
            return object # failure
        end
        return bucket # success
    end
end

class BackupTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not $modules['backup'].has_key?(object) then
            errmsg.push("Unsupported 'backup' type: '#{object}'")
            return object
        end
        return object # success
    end
end

class EncryptTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not $modules['encrypt'].has_key?(object) then
            errmsg.push("Unsupported 'encrypt' type: '#{object}'")
            return object
        end
        return object # success
    end
end

class RemoteTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not $modules['remote'].has_key?(object) then
            errmsg.push("Unsupported 'remote' type: '#{object}'")
            return object
        end
        return object # success
    end
end

class NotifyTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not $modules['notify'].has_key?(object) then
            errmsg.push("Unsupported 'notify' type: '#{object}'")
            return object
        end
        return object # success
    end
end

class EmailAddressValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if object !~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i then
            errmsg.push("Invalid email address: '#{object}'")
            return object
        end
        return object # success
    end
end

class SnapshotTypeValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        valid_snap_types = ['lvm']
        if not valid_snap_types.include?(object) then
            errmsg.push("Invalid snapshot type: '#{object}'. Valid snapshot types are: #{valid_snap_types.join(',')}")
            return object # failure
        end
        return object # success
    end
end

class BlockDeviceValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not File.exist?(object) then
            errmsg.push("Cannot find block device: '#{object}'")
            return object
        end
        if not File.stat(object).blockdev? then
            errmsg.push("Invalid block device: '#{object}'")
            return object
        end
        return object # success
    end
end

# Array of hashes with three possible keys: block_device + snapshot_type + snapshot_size
# - block_device: /dev/vgname/lvname1
#   snapshot_type: lvm
#   snapshot_size: 1024M
#-  block_device: /dev/vgname/lvname2
#   snapshot_type: lvm
#   snapshot_size: 3G
class FsaArrayValidator < ObjectValidator
    def validate_and_substitute(object, errmsg)
        if not object.is_a?(Array) then
            errmsg.push("This is not a valid array: '#{object}'")
            return object # failure
        end
        # validate all filesystem description hashes
        object.each do |filesys|
            # make sure the filesystem description hash is a valid hash
            if not filesys.is_a?(Hash) then
                errmsg.push("This is not a valid hash: '#{object}'")
                return object # failure
            end
            # make sure the filesystem description hash does not contain any unexpected key
            fsdevsupportedkeys = ['block_device', 'snapshot_type', 'snapshot_size']
            filesys.each do |key,val|
                if not fsdevsupportedkeys.include?(key) then
                    errmsg.push("Unexpected '#{key}' key in filesystem description hash: '#{filesys}'. Expected only #{fsdevsupportedkeys.join(',')}")
                    return object # failure
                end
            end
            # make sure the filesystem description hash contains a 'block_device' key
            fsdevice = filesys.fetch('block_device', nil)
            if not fsdevice then
                errmsg.push("Filesystem description hash contains no 'block_device' key: '#{filesys}'")
                return object # failure
            end
            # make sure the 'block_device' key corresponds to a file which exists
            if not File.exist?(fsdevice) then
                errmsg.push("Cannot find filesystem block device: '#{fsdevice}'")
                return object # failure
            end
            # make sure the 'block_device' key corresponds to a file block device
            if not File.stat(fsdevice).blockdev? then
                errmsg.push("Invalid block device: '#{fsdevice}'")
                return object # failure
            end
            # make sure snapshot type corresponds to a valid type
            valid_snap_types = ['lvm']
            user_snap_type = filesys.fetch('snapshot_type', nil)
            if ((user_snap_type != nil) and (not valid_snap_types.include?(user_snap_type))) then
                errmsg.push("Invalid snapshot type: '#{user_snap_type}'. Valid snapshot types are: #{valid_snap_types.join(',')}")
                return object # failure
            end
            # make sure snapshot size corresponds to a valid size
            user_snap_size = filesys.fetch('snapshot_size', nil)
            if ((user_snap_size != nil) and (user_snap_size !~ /^[0-9]+(M|G)$/)) then
                errmsg.push("This is not a valid data size: '#{user_snap_size}'. Expected size such as 768M or 10G")
                return object # failure
            end
        end
        return object # success
    end
end
