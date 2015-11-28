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

# Function which load modules at program startup

def load_modules()

    $output.write(1, "Loading program modules ...")

    $modules = Hash.new
    $modules['backup'] = Hash.new
    $modules['encrypt'] = Hash.new
    $modules['remote'] = Hash.new
    $modules['notify'] = Hash.new

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-tarball' ...")
    require "#{$progdir}/lib/modules/backup-tarball"
    plugclass = ModuleBackupTarball
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-mysqldp' ...")
    require "#{$progdir}/lib/modules/backup-mysqldp"
    plugclass = ModuleBackupMysqldp
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-pgsqldp' ...")
    require "#{$progdir}/lib/modules/backup-pgsqldp"
    plugclass = ModuleBackupPgsqldp
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-rsyncget' ...")
    require "#{$progdir}/lib/modules/backup-rsyncget"
    plugclass = ModuleBackupRsyncGet
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-blockcopy' ...")
    require "#{$progdir}/lib/modules/backup-blockcopy"
    plugclass = ModuleBackupBlockCopy
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-fsarchiver' ...")
    require "#{$progdir}/lib/modules/backup-fsarchiver"
    plugclass = ModuleBackupFsarchiver
    $modules['backup'][plugclass.name] = plugclass

    $output.write(2, "Loading 'encrypt' module from '#{$progdir}/lib/modules/encrypt-gnupg' ...")
    require "#{$progdir}/lib/modules/encrypt-gnupg"
    plugclass = ModuleEncryptGnupg
    $modules['encrypt'][plugclass.name] = plugclass

    # allow to continue even if the rubygem 'aws-sdk-v1' is not installed as the user may not need it
    begin
        $output.write(2, "Attempting to load 'rubygems' ruby module (required for AWS features)...")
        require 'rubygems'

        $output.write(2, "Attempting to load 'aws-sdk-core' gem module (required for AWS features)...")
        require 'aws-sdk-core'

        $output.write(2, "Attempting to load 'aws-sdk-resources' gem module (required for AWS features)...")
        require 'aws-sdk-resources'

        $output.write(2, "Loading 'backup' module from '#{$progdir}/lib/modules/backup-ebssnap' ...")
        require "#{$progdir}/lib/modules/backup-ebssnap"
        plugclass = ModuleBackupEbsSnap
        $modules['backup'][plugclass.name] = plugclass

        $output.write(2, "Loading 'remote' module from '#{$progdir}/lib/modules/remote-aws-s3' ...")
        require "#{$progdir}/lib/modules/remote-aws-s3"
        plugclass = ModuleRemoteAwsS3
        $modules['remote'][plugclass.name] = plugclass

        $output.write(2, "Loading 'notify' module from '#{$progdir}/lib/modules/notify-aws-ses' ...")
        require "#{$progdir}/lib/modules/notify-aws-ses"
        plugclass = ModuleNotifyAwsSes
        $modules['notify'][plugclass.name] = plugclass
    rescue LoadError => e
        $output.write(1, "WARNING: Failed to load AWS related modules: #{e.message} as ruby gems requirements not satisfied")
    end

end
