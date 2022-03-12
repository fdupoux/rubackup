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

# Implements support for creating and deleting LVM Snapshots

module LvmSnapshots

    # Create an LVM snapshot
    def LvmSnapshots.create(blkdev, prefix, snapshot_size)

        $output.write(5, "LvmSnapshots.create(blkdev='#{blkdev}', prefix='#{prefix}', snapshot_size=[#{snapshot_size}])")
        if blkdev =~ /^\/dev\/([-A-Za-z0-9_\.]+)\/([-A-Za-z0-9_\.]+)$/ then
            lvm_vg = $1
            lvm_lv = $2
        else
            raise "Error: cannot parse LVM Logical Volume name: [#{blkdev}]"
        end
        $output.write(5, "lvm_lv=[#{lvm_lv}] and lvm_vg=[#{lvm_vg}]")
        snapname = "snap_#{prefix}_#{lvm_lv}"

        lvcreate = Utilities.path_to_command("lvcreate")
        raise "Command 'lvcreate' not found in PATH. Check lvm is installed and in PATH" if not lvcreate

        command = "#{lvcreate} -s -L #{snapshot_size} -n #{snapname} #{blkdev}"
        $output.write(5, "Creating LVM Snapshot: #{command}")
        (out, res) = Open3.capture2e(command)

        if ((res.exited? == false) or (res.exitstatus != 0)) then
            raise "Creation of LVM snapshot failed:\n#{command}\n#{out}"
        end

        return "/dev/#{lvm_vg}/#{snapname}"
    end

    # Destroy an LVM snapshot
    def LvmSnapshots.destroy(snap)
        
        lvremove = Utilities.path_to_command("lvremove")
        raise "Command 'lvremove' not found in PATH. Check lvm is installed and in PATH" if not lvremove
        
        command = "#{lvremove} -f #{snap}"
        $output.write(5, "Deleting LVM Snapshot: #{command}")
        (out, res) = Open3.capture2e(command)
        
        if ((res.exited? == false) or (res.exitstatus != 0)) then
            raise "Deletion of LVM snapshot failed:\n#{command}\n#{out}"
        end
    end

end
