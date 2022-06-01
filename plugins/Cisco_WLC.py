#!/usr/bin/python


# 2017-4-14 first version
# Author: DiXingYu



import sys
import getopt
import netsnmp
import time

opts, args = getopt.getopt(sys.argv[1:], 'H:C:',  
                           [ 
                               'host=',
                               'community=', 
                               'help' 
                           ] 
                           ) 

for option, value in opts: 
    if option in ['--help']: 
        print """ 
    usage:%s -H host ip address -C snmpv2 community 
    """ 
        sys.exit()

    elif option in ['--host', '-H']: 
        hosts = value

    elif option in ['--community', '-C']: 
        communitys = value


WarningNum = 0
CriticalNum = 0

# Check_WLC_TEMP
# The CISCO WLC datasheet show the wlc operating tempture is 0-40, so the min is 5, and the max is 40

temp_min = 5.0

temp_max = 50.0

temp_raw = netsnmp.snmpget(netsnmp.Varbind('.1.3.6.1.4.1.14179.2.3.1.13.0'),Version = 2,DestHost=(hosts),Community=(communitys))

temp = float(temp_raw[0])


# Check_WLC_CPU

cpu_warn = 80.0

cpu_crit = 90.0

cpu_raw = netsnmp.snmpget(netsnmp.Varbind('.1.3.6.1.4.1.14179.1.1.5.1.0'),Version = 2,DestHost=(hosts),Community=(communitys))

cpu = float(cpu_raw[0])



# Check_WLC_MEMORY

mem_warn = 80.0

mem_crit = 90.0

mem_used = netsnmp.snmpget(netsnmp.Varbind('.1.3.6.1.4.1.14179.1.1.5.3.0'),Version = 2,DestHost=(hosts),Community=(communitys))

mem_util = round(float(mem_used[0]) / 710816.0, 2) * 100


# The Exit

if mem_util > mem_warn and mem_util < mem_crit:
	WarningNum = WarningNum + 1
	print "Warning: The WLC Memory utilization is high, the utilization is %.1f%%"%mem_util,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

if mem_util > mem_crit:
	CriticalNum = CriticalNum + 1
	print "Critical: The WLC Memory utilization is too high, the utilization is %.1f%%"%mem_util,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

if temp < temp_min:
  WarningNum = WarningNum + 1
  print "Warning: The WLC temp is low, temp is %.1f"%temp ,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

if temp > temp_max:
  WarningNum = WarningNum + 1
  print "Warning: The WLC temp is high, temp is %.1f"%temp ,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

if cpu > cpu_warn and cpu < cpu_crit:
  WarningNum = WarningNum + 1
  print "Warning: The WLC CPU utilization is high, the utilization is %.1f%%"%cpu,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

if cpu > cpu_crit:
  CriticalNum = CriticalNum + 1
  print "Critical: The WLC CPU utilization is too high, the utilization is %.1f%%"%cpu,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp


# THE OK OUTPUT

if CriticalNum > 0:
    sys.exit(2)   
    
if WarningNum > 0:
    sys.exit(1)

else:
	print "OK: The WLC CPU utilization is %.1f%%,"%cpu,"Memory utilization is %.1f%%,"%mem_util,"Tempture is %.1f,"%temp,'|' "CPU_utilization=%.1f%%"%cpu, "Memory_utilization=%.1f%%"%mem_util,"Tempture=%.1f"%temp

	sys.exit(0)
