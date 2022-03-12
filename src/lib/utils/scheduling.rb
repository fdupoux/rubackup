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

# Implements support for scheduling (time/date decisions)

module Scheduling

    # Extract date of from backup filename
    def Scheduling.determine_creation_date(filename, basename)
        if filename =~ /#{basename}-(\d{8})/ then
            return Date.strptime($1, '%Y%m%d')
        else
            raise "ERROR: determine_creation_date(#{filename}, #{basename}): no match found"
        end
    end

    # Say if an backup fits in a daily/weekly/monthly schedule
    # Return nil when a backup does not fit in the schedule
    def Scheduling.determine_backup_schedule(bakdate, schedrules)
        limit_daily = $today - schedrules['daily']
        limit_weekly = $today - (7 * schedrules['weekly'])
        limit_monthly = $today << schedrules['monthly']

        $output.write(5, "Schedule: bakdate=[#{bakdate}] limit_daily=[#{limit_daily}] limit_weekly=[#{limit_weekly}] limit_monthly=[#{limit_monthly}]")

        day_of_week = $globcfg['day_of_week']
        day_of_month = $globcfg['day_of_month']

        if (bakdate > limit_daily) then
            'daily'
        elsif ((bakdate.wday == day_of_week) and (bakdate > limit_weekly)) then
            'weekly'
        elsif ((bakdate.mday == day_of_month) and (bakdate > limit_monthly)) then
            'monthly'
        else
            nil
        end
    end

end
