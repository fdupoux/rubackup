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

# Implements stop/start of linux services

module Services

    # check we are able to control services
    def Services.check_service_command()
        @systemctl = Utilities.path_to_command("systemctl")
        @service = Utilities.path_to_command("service")
        if (not (@systemctl or @service)) then
            raise "Cannot find command to start/stop services in PATH (both 'systemctl' and 'service' commands not found)"
        end
    end

    # attempt to stop/start/restart a service
    def Services.manage_service(svcname, operation, ignorefail=false)

        Services.check_service_command()

        if @systemctl then
            unitfile = "/usr/lib/systemd/system/#{svcname}.service"
            if not File.exist?(unitfile) then
                raise "Cannot find systemd unit file for service #{svcname} in #{unitfile}"
            end
            command = "#{@systemctl} #{operation} #{svcname}"
        else
            command = "#{@service} #{svcname} #{operation}"
        end
        
        $output.write(5, "Running command: [#{command}]")
        (out, res) = Open3.capture2e(command)
        if ((res.exited? == false) or (res.exitstatus != 0)) then
            raise "Failed to perform service #{operation}\n#{command}\n#{out}"
        end
    end

end
