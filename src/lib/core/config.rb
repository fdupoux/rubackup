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

# This file implements the loading and validation of the configuration files

# Validates a hash according to validation rules
# Returns validation errors in the valerrs hash (passed as an argument)
# Returns parsed data (use default value when required) as the returned value
def parse_and_validate_rules(inhash, valitems, valerrs, context='')
    results = Hash.new
    $output.write(4, "About to validate the following hash: context=[#{context}]\n#{inhash} ...")
    # 1. make sure all validation rules are satisfied
    valitems.each do |item|
        $output.write(5, "item: name='#{item.name}' mandatory='#{item.mandatory}' defval='#{item.defval}'")
        # 1. verify the "mandatory" attribute is respected
        if ((item.mandatory == true) and (inhash.has_key?(item.name) == false)) then
            valerrs.push("Option '#{item.name}' is mandatory and absent")
        end
        # 2. execute validator code
        if (inhash.has_key?(item.name) == true) then # use valut from configuration if there is one
            itemval = inhash.fetch(item.name)
            errmsg = Array.new
            substvalue = item.validator.validate_and_substitute(itemval, errmsg)
            if (errmsg.count > 0) then
                valerrs.push("Validation of '#{item.name}' failed: #{errmsg.join(',')}")
            end
        else
            # use default value if no value provided by configuration
            if (item.defval != nil) then
                substvalue = item.defval
            end
        end
        # 3. select the final value for this option (value from user of default value)
        if (substvalue != nil) then
            results[item.name] = substvalue
        end
    end
    # 2. make sure all entries in the configuration correspond to a validation rules (no unknown items)
    inhash.each do |key,val|
        curvals = valitems.select { |valitem| valitem.name == key }
        if (curvals.count == 0) then
            valerrs.push("Unexpected configuration item '#{key}': found no validation rule for an item with this name in this context")
        end
    end
    # results
    return results
end

# Parse configuration and attempt to load a particular category and populated the global resources array
def load_category(config, catname, valitems)
    $output.write(2, "Performing validation of the category '#{catname}' ...")
    results = Hash.new
    # attempt to find definitions for objects of this category in the configuration
    definitions = config.fetch(catname, nil)
    if (definitions == nil) then
        # Not necessarily a problem: not all possible section as required.
        # For example we do not expect the section which defines AWS access keys when AWS not in use
        $output.write(4, "Cannot find definitions for category '#{catname}' in the configuration")
        return
    end
    # apply validation to all object of this category which have just been found
    definitions.each do |key,val|
        $output.separator(4)
        $output.write(3, "Loading definitions for resource '#{key}' of type '#{catname}' ...")
        valerrs = Array.new
        parseopt = parse_and_validate_rules(val, valitems, valerrs, "category=#{catname}")
        if (valerrs.count > 0) then
            $output.write(0, "Failed to validate the following options:\n#{val}\n#{valerrs.join("\n")}")
            raise "Validation failed for the configuration of the '#{catname}' category"
        else
            $output.write(4, "Validation passed for resource '#{key}' of type '#{catname}'")
            results[key] = parseopt
        end
    end
    $output.separator(4)
    # show summary of all objects of this category which have been found and validated
    $output.write(4, "Have loaded and validated all definitions for category '#{catname}'")
    results.each { |key,val| $output.write(4, "#{key} #{val}") }
    return results
end

# Load configuration file
def load_config(yamlcfg)

    # verify the configuration files exist
    $output.write(1, "Loading program configuration from '#{yamlcfg}' ...")
    cfgfiles = Dir.glob(yamlcfg)
    if (cfgfiles.size == 0) then
        $output.write(0, "Yaml configuration files not found: '#{yamlcfg}'")
        exit(ExitStatus::EXITST_INVALID_CONFIG_FILES)
    end

    # read configuration from all yaml files and merge everything into a single hash
    config = Hash.new
    cfgfiles.sort_by{ |fullpath| File.basename(fullpath) }.each do |fullpath|
        $output.write(2, "Loading configuration fragment: '#{fullpath}' ...")
        curfile = YAML.load_file(fullpath)
        curfile.each do |key,val|
            if not config.has_key?(key) then
                config[key] = curfile[key]
            else
                config[key].merge!(curfile[key])
            end
        end
    end
    
    return config
end

# Load configuration file
def validate_config(config)

    $output.write(1, "Performing general validation of the whole configuration ...")

    # create array to store all resources to which entries can refer in their configuration
    $resources = Hash.new

    $output.separator(4)

    # load definition of the "Schedules" resources
    schedules_val = 
    [
        ValidationRule.new(name='daily', mandatory=true, defval=nil, validator=IntegerValidator.new),
        ValidationRule.new(name='weekly', mandatory=true, defval=nil, validator=IntegerValidator.new),
        ValidationRule.new(name='monthly', mandatory=true, defval=nil, validator=IntegerValidator.new),
    ]
    $resources["schedules"] = load_category(config, "schedules", schedules_val)

    $output.separator(4)

    # load definition of the "AWS Access Keys" resources
    aws_access_keys_val = 
    [
        ValidationRule.new(name='public', mandatory=true, defval=nil, validator=AwsAccessKeyPublicValidator.new),
        ValidationRule.new(name='secret', mandatory=true, defval=nil, validator=AwsAccessKeySecretValidator.new),
    ]
    $resources["aws_access_keys"] = load_category(config, "aws_access_keys", aws_access_keys_val)

    $output.separator(4)

    # load definition of the "AWS S3 Buckets" resources
    aws_s3_buckets_val = 
    [
        ValidationRule.new(name='bucket', mandatory=true, defval=nil, validator=StringValidator.new),
        ValidationRule.new(name='awsregion', mandatory=true, defval=nil, validator=AwsRegionValidator.new),
        ValidationRule.new(name='accesskey', mandatory=false, defval=nil, validator=AwsAccessKeyReferenceValidator.new),
    ]
    $resources["aws_s3_buckets"] = load_category(config, "aws_s3_buckets", aws_s3_buckets_val)

    $output.separator(4)

    # load definition of the "AWS SES Medias" resources
    aws_ses_medias_val = 
    [
        ValidationRule.new(name='awsregion', mandatory=true, defval=nil, validator=AwsRegionValidator.new),
        ValidationRule.new(name='accesskey', mandatory=false, defval=nil, validator=AwsAccessKeyReferenceValidator.new),
        ValidationRule.new(name='mailsrc', mandatory=true, defval=nil, validator=EmailAddressValidator.new),
        ValidationRule.new(name='maildst', mandatory=true, defval=nil, validator=EmailAddressValidator.new),
    ]
    $resources["aws_ses_medias"] = load_category(config, "aws_ses_medias", aws_ses_medias_val)

    $output.separator(4)

    # load definition of the backup entries
    backup_entries_val = 
    [
        ValidationRule.new(name='enabled', mandatory=false, defval=true, validator=BooleanValidator.new),
        ValidationRule.new(name='backup_type', mandatory=true, defval=nil, validator=BackupTypeValidator.new),
        ValidationRule.new(name='backup_opts', mandatory=true, defval=nil, validator=HashValidator.new),
        ValidationRule.new(name='backup_schedule', mandatory=true, defval=nil, validator=ScheduleTypeValidator.new),
        ValidationRule.new(name='encrypt_type', mandatory=false, defval=nil, validator=EncryptTypeValidator.new),
        ValidationRule.new(name='encrypt_opts', mandatory=false, defval=nil, validator=HashValidator.new),
        ValidationRule.new(name='remote_type', mandatory=false, defval=nil, validator=RemoteTypeValidator.new),
        ValidationRule.new(name='remote_opts', mandatory=false, defval=nil, validator=HashValidator.new),
        ValidationRule.new(name='remote_schedule', mandatory=false, defval=nil, validator=ScheduleTypeValidator.new),
        ValidationRule.new(name='bakfile_dir', mandatory=false, defval=nil, validator=DirectoryValidator.new),
        ValidationRule.new(name='bakfile_owner', mandatory=false, defval=nil, validator=StringValidator.new),
        ValidationRule.new(name='bakfile_group', mandatory=false, defval=nil, validator=StringValidator.new),
        ValidationRule.new(name='bakfile_mode', mandatory=false, defval=nil, validator=IntegerValidator.new),
        ValidationRule.new(name='bakfile_basename', mandatory=false, defval=nil, validator=StringValidator.new),
    ]
    $entries = load_category(config, "entries", backup_entries_val)

    $output.separator(4)

    # split yaml configuration into global section and regular entries
    globcfg1 = config.delete('global')

    # validate and substitute global configuration section
    global_val = 
    [
        ValidationRule.new(name='day_of_week', mandatory=true, defval='Mon', validator=DayOfWeekValidator.new),
        ValidationRule.new(name='day_of_month', mandatory=true, defval=1, validator=DayOfMonthValidator.new),
        ValidationRule.new(name='notify_type', mandatory=false, defval=nil, validator=NotifyTypeValidator.new),
        ValidationRule.new(name='notify_opts', mandatory=false, defval=nil, validator=HashValidator.new),
        ValidationRule.new(name='path_extra', mandatory=false, defval=nil, validator=DirListValidator.new),
        ValidationRule.new(name='sleep_between', mandatory=false, defval=0, validator=IntegerValidator.new),
    ]
    valerrs = Array.new
    $globcfg = parse_and_validate_rules(globcfg1, global_val, valerrs, 'global section')
    if (valerrs.count > 0) then
        $output.write(0, "Validation errors in the global section of the configuration:\n#{globcfg1}\n#{valerrs.join("\n")}")
        raise "Failed to validate the global section of the configuration"
    else
        $output.write(4, "Validation passed for the global section of the configuration")
    end

    $output.separator(4)

    # validate and substitute options for the notification
    notify_type = $globcfg.fetch('notify_type', nil)
    notify_args = $globcfg.fetch('notify_opts', nil)
    if ((notify_type == nil) != (notify_args == nil)) then
        raise "You must provide both a type and arguments for the nofitication ('notify_type' and 'notify_opts')"
    end
    if (notify_type and notify_args) then
        notify_module = $modules['notify'][notify_type].new
        items = notify_module.get_options_validation()
        valerrs = Array.new
        parseopt = parse_and_validate_rules(notify_args, items, valerrs, 'notify_opts')
        if (valerrs.count > 0) then
            $output.write(0, "Failed to validate the notify options of the global configuration:\n#{notify_args}\n#{valerrs.join("\n")}")
            raise "Validation failed for the notify options of the global configuration"
        else
            $output.write(4, "Validation passed for the notify options of the global configuration")
            $globcfg['notify_opts'] = parseopt
        end
    end

    $output.separator(2)

    $output.write(1, "Performing validation of the backup entries ...")

    # validate module specific configuration options
    $entries.each do |entryname,entrydata|

        $output.separator(4)

        $output.write(2, "Performing validation of the backup entry '#{entryname}' ...")

        # create a hash so the module implementations are accessible from the entries
        entrydata['modules'] = Hash.new

        # validate arguments used by all three type of modules for this entry
        ['backup', 'encrypt', 'remote'].each do |plugcategory|

            # Verify either both or none of the type/opts are provided for each module type
            type = entrydata.fetch("#{plugcategory}_type", nil)
            opts = entrydata.fetch("#{plugcategory}_opts", nil)
            if ((type == nil) != (opts == nil)) then
                raise "You must provide both a type ('#{plugcategory}_type') and arguments ('#{plugcategory}_opts') for the '#{plugcategory}' module"
            end
            if (type and opts) then

                # verify if module of the requested type can be found in the $modules array
                if not $modules[plugcategory].has_key?(type) then
                    raise "ERROR: Cannot find '#{plugcategory}' module with this name: '#{type}'"
                end

                # create an instance of the "module" in the entry object so it can be reused in the core section
                entrydata['modules'][plugcategory] = $modules[plugcategory][type].new

                $output.write(4, "Performing validation for plugcategory='#{plugcategory}' with type='#{type}'...")
                items = entrydata['modules'][plugcategory].get_options_validation()
                valerrs = Array.new
                parseopt = parse_and_validate_rules(opts, items, valerrs, "#{plugcategory}_opts")
                if (valerrs.count > 0) then
                    $output.write(0, "Failed to validate the '#{entryname}' entry configuration:\n#{opts}\n#{valerrs.join("\n")}")
                    raise "Validation failed for the the '#{entryname}' entry options"
                else
                    $output.write(4, "Validation passed for plugcategory='#{plugcategory}' with type='#{type}'...")
                    entrydata["#{plugcategory}_opts"] = parseopt
                    $output.write(5, "#{parseopt}")
                end
            end
        end

        $output.write(4, "Successfully validated configuration of backup entry '#{entryname}'")
        $output.write(4, "Modules associated with entry '#{entryname}' ...")
        entrydata['modules'].each { |key,val| $output.write(4, "- module category='#{key}' implementation='#{val.class}'") }

    end

    $output.separator(4)
end
