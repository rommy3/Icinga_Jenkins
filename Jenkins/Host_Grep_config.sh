#!/bin/bash

Host_IP=$1
Read_Config_File=$2
Delete_File=$3


Hostname=`grep -l $Host_IP /etc/icinga2/iopex.d/Hosts/*.conf | awk -F/ '{print $NF}'`
grep -l $Host_IP /etc/icinga2/iopex.d/Hosts/*.conf
if [ $? == 0 ]; then
    if [ -n $Host_IP ];then
    	echo -e "\n\nHost file is found \n\n Hostname = $Hostname\n\n"
    	
    	if [ "$Read_Config_File" == true ] || [ "$Read_Config_File" == 1 ]; then	
    	        echo -e "Check the Configuration below : \n\n"
    	        cat "/etc/icinga2/iopex.d/Hosts/$Hostname"
    	fi
   	if [ "$Delete_File" == true ] || [ "$Delete_File" == 1 ] && [ "$Read_Config_File" == true ] || [ "$Read_Config_File" == 1 ];then
   	        mv /etc/icinga2/iopex.d/Hosts/$Hostname /etc/icinga2/iopex.d/Hosts/Backup/$Hostname.bak
   	        if [ $? == 0 ]; then
   	    	    echo -e "\n\nFile has been backup Successfully in /etc/icinga2/iopex.d/Hosts/Backup/$Hostname.bak"
		
   		else 
		    echo -e "\nFalied to Backup the Hostfile"
		    exit 1
   		fi
	fi
    fi
else
    echo -e "\n\nNo Host found with IP $Host_IP\n\n"
    exit 1
fi
