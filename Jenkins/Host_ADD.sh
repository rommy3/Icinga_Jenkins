#!/bin/bash

#***** SSH_Hosts Definitions *****#
ssh_hosts=( "192.168.102.100" )
ssh_port=22
ssh_user=rommy
ssh_conf_path="/etc/icinga2/iopex.d/Hosts/"

#*****Local Host Definitions*****#

template_path="/home/Jenkins/Templates/"

#*** Configuration Parameters ****#

Host_name=$1
Host_IP=$2
H_Type=$3
H_Type=`echo $H_Type | tr a-z A-Z`

### Script Usage ###

function show_usage (){
    printf "\n################################## Please refer the below usage and proceed ##################################\n"
    printf " -h|--help, Print help\n"
    printf " ### Use valid args by the order given below\n"
    printf " ### Hostname IPaddress Device_type & '-optargs' \n\n ###refer the options below###\n\n"
    printf " Choose any one of the Device_type below\n\n\t { 'Host_Only', 'Default', 'Firewall' or 'Cisco' }\n\n"
    printf " If you adding Firewall device pls mention the 'Firewall_Type' using -t arg\n"
    printf " '-t|type' to add the Firewall_Type as { 'PAN', 'FORTI' or 'SONIC' }\n"
    printf " '-c|string' to add the Community_String"
    printf " '-b|bandwidth' to add bandwidth service refer the parameter for bandwidth\n"
    printf "      -b Bandwidth_Name interface_speed(if_speed) interface_num(if_index)\n"
    printf " '-p|port' to add the Port_check service refer the parameter for port-check option \n"
    printf "	  -p  Port_name  Port_num\n" 
    printf " '-m|process' to add Process_check service refer the parameter for process_check option\n"
    printf "      -m Process_Name \n"
    printf " '-u|url' to add URL_check service refer the parameter for URL_check option\n"
    printf "      -u URL \n" 
    printf " '-n|notify' to Enable the Email Notification refer the parameter for notify option\n"
    printf "    -n Notification_template_name as follows\n\n\tGENERIC-DEFAULT\n\tOPEXWISESUPPORT-FIRST\n\tCIO\n\tMTAP\n\tSERVER-ADMINS\n\tNET-SERVE\n\tIOPEX-BLR\n"
    printf " \n Example for script usage:\n\n\t$0 Hostname IPaddress HOST_ONLY -n arg \n\n"
    printf " \t$0 Hostname IPaddress Basic_Service_Type {-t arg} -c Community_String -n arg\n\n"
    printf " \t$0 Hostname IPaddress Basic_Service_Type -c Community_String -b Bandwidth 200 2 -p http 80 -m mysqld -u URL -n Noc_team {-C or -R}\n\n"
    printf " Use -C option as a end argument to Compile the Output.\n\n"
    printf " Use -R option as a end argument to Reload the icinga2 services\n\n" 
    printf " Note:- \n\n Device Type works if you choose Host_only adds only Host template and Ping_check Service only\n\n"
    printf " if a Deivce_Type is Firewall in 3rd parameter then '-t' is mandiatory\n\n"
    printf " if you choose Default this will add default services (CPU,RAM,Disk & Uptime)\n\n"
    printf " if you choose Cisco this will add the default Switch services (CPU & RAM)\n\n"
    printf " -b|bandwidth , -p|port , -m|process , -u|url are optional here either you can use or leave as empty\n\n"
    printf " Community_String is required for SNMP based services like Default_Services, Firewall_Services, Bandwidth & Process_check\n\n"
    printf " Refer the above Examples before proceeding\n\n"
return 0
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]];then
    show_usage
    exit 1
fi 

#### File Paths ####

Input_file="/tmp/"$Host_name"_"$Host_IP".conf"
Output_file="/etc/icinga2/iopex.d/Hosts/"$Host_name"_"$Host_IP".conf"
#Notify_File="/etc/icinga2/iopex.d/notifications.conf"



### Optional input for Compile or Reload the icinga2 ###
if [ "${*: -1}" == "-C" ] || [ "${*: -1}" == "Compile" ] ; then

Compile_Mode=enabled

fi

if [ "${*: -1}" == "-R" ] || [ "${*: -1}" == "Reload" ] ; then

Exec_Mode=enabled

fi

### Adding Default Host Template ###

if [ -z "$Host_name" ] || [ -z "$Host_IP" ]; then
    show_usage
    echo -e "Please provide the Hostname and Host_IP to continue.\n"
    exit 1
else
    cat "$template_path/Host_temp.conf" > $Input_file
fi

### Default optargs ###
if [ $H_Type == DEFAULT ] ; then
while [ ! -z "$1" ]; do
  case "$1" in
     String|-c)
         shift
	 Community=$1
	 ;;

     Bandwidth|-b)
         shift
	 Band_name=$1
	 shift
         If_speed=$1
	 shift
 	 Index_value=$1
           
	 if [ -z $Index_value ] || [ -z $If_speed ] || [ -z $Band_name ] || [ -z $Community ]; then
	     echo -e "\n\n#### Please provide valid arguments for Bandwidth Service ####\n "Community_string -b Banwidth_name, IF_Speed, IF_Index"\n\n"
	     exit 1
	 else
	 cat ""$template_path"/Bandwidth_temp.conf" >> $Input_file
	 sed -i -e "s/Band_Name/$Band_name/;s/If_speed/$If_speed/;" $Input_file
	 sed -i "s/Index_value/$Index_value/;" $Input_file
         fi
	 ;;

     Port|-p)
         shift
         Port_Name=$1
	 shift
	 Port_Num=$1 
	 if [ -z $Port_Name ] || [ -z $Port_Num ] ; then
		 echo -e "\n\nPlease provide valid arguments for Port_check Service. "-p Porname Port_Num"\n\n"
		 exit 1
	 else
	 cat ""$template_path"/Port_check_temp.conf" >> $Input_file
	 sed -i "s/Port_Name/$Port_Name/;s/Port_Num/$Port_Num/" $Input_file
 	 fi
	 ;;
       
     Process|-m) 
	 shift
	 Process_name=$1
	 if [ -z $Process_name ] || [ -z $Community ]; then
                 echo -e "\n\nPlease provide valid arguments for Process_check Service. "Community_string -m Process_Name"\n\n"
                 exit 1
         else
         cat ""$template_path"/Process_check_temp.conf" >> $Input_file
         sed -i "s/Process_name/$Process_name/;" $Input_file
         fi
         ;;

     URL|-u)
	 shift
	 URL=$1
	 if [ -z $URL ] ; then
                 echo -e "\n\nPlease provide valid arguments for URL_check Service. "-m URL"\n\n"
                 exit 1
         else
         cat ""$template_path"/URL_check_temp.conf" >> $Input_file
         sed -i "s,URL,$URL,g" $Input_file
         fi
         ;;


     notify|-n) # Use this to add the PD Notification which is in templates.conf file
         shift
	 N_name=$1

  esac
 shift
done
fi

### FIREWALL Devices optargs ###
if [ $H_Type == FIREWALL ] ; then
while [ ! -z "$1" ]; do
  case "$1" in
     type|-t)
         shift
         FW_Type=$1
	 FW_Type=`echo $FW_Type | tr a-z A-Z`
         ;;

     String|-c)
         shift
         Community=$1
         ;;

     Bandwidth|-b)
         shift
         Band_name=$1
         shift
         If_speed=$1
         shift
         Index_value=$1
         if [ -z $Index_value ] || [ -z $If_speed ] || [ -z $Band_name ] || [ -z $Community ]; then
             echo -e "\n\n#### Please provide valid arguments for Bandwidth Service ####\n "Community_string -b Banwidth_name, IF_Speed, IF_Index"\n\n"
             exit 1
         else
         cat ""$template_path"/Bandwidth_temp.conf" >> $Input_file
         sed -i "s/Band_Name/$Band_name/;s/If_speed/$If_speed/;" $Input_file
         sed -i "s/Index_value/$Index_value/;" $Input_file
         fi
         ;;

     notify|-n) # Use this to add the PD Notification which is in templates.conf file
         shift
         N_name=$1

   esac
 shift
done
fi

### HOST_ONLY optargs ###
if [ $H_Type == HOST_ONLY ] ; then
while [ ! -z "$1" ]; do
  case "$1" in
     notify|-n) # Use this to add the PD Notification which is in templates.conf file
         shift
         N_name=$1
	
  esac
 shift
done
fi


### CISCO Devices optargs ###
if [ $H_Type == CISCO ] ; then
while [ ! -z "$1" ]; do
  case "$1" in
     String|-c)
         shift
         Community=$1
         ;;

     Bandwidth|-b)
         shift
         Band_name=$1
         shift
         If_speed=$1
         shift
         Index_value=$1

         if [ -z $Index_value ] || [ -z $If_speed ] || [ -z $Band_name ] || [ -z $Community ]; then
             echo -e "\n\n#### Please provide valid arguments for Bandwidth Service ####\n "Community_string -b Banwidth_name, IF_Speed, IF_Index"\n\n"
             exit 1
         else
         cat ""$template_path"/Bandwidth_temp.conf" >> $Input_file
         sed -i "s/Band_Name/$Band_name/;s/If_speed/$If_speed/;" $Input_file
         sed -i "s/Index_value/$Index_value/;" $Input_file
         fi
	 ;;

     notify|-n) # Use this to add the PD Notification which is in templates.conf file
         shift
         N_name=$1
         
  esac
 shift
done
fi

#### Adding the Default Services ###

if [ $H_Type == HOST_ONLY ] ;then 
	echo "\nAdding Host only in configuration file\n"
elif [ $H_Type == DEFAULT ] && [ -n $Community ] ; then
       cat "$template_path/Service_temp.conf" >> $Input_file
      
elif [ $H_Type == FIREWALL ] &&  [ -n $Community ] ; then
	if [ $FW_Type == PAN ] ;then
	   cat "$template_path/FW_Services.conf" >> $Input_file
	elif [ $FW_Type == FORTI ] ; then
	   cat "$template_path/FW_Services.conf" >> $Input_file
	   sed -i "s/check_PAN_ALL/check_fortigate/g" $Input_file
	elif [ $FW_Type == SONIC ]; then
     	   cat "$template_path/FW_Services.conf" >> $Input_file
           sed -i "s/check_PAN_ALL/check_Sonic_FW/g;s/sessions/connections/g" $Input_file 
        else
	   echo -e "\n\n Please mention valid the Firewall Type with '-t' (PAN,FORTI or SONIC) and Community string '-c' to proceed\n\n"
   	   exit 1
   	fi
elif [ $H_Type == CISCO ] &&  [ -n $Community ] ; then
	cat "$template_path/Cisco_Services.conf" >> $Input_file	

else
	echo -e "\n\n#### Please provide a Device Type and Community string Services ####\n\n"
	exit 1
#       cat "$template_path"/Service_temp.conf" >> $Input_file
        
fi


#### Validate the Notification Template Name ####
Notify_name=`echo $N_name | tr [a-z] [A-Z]`
if  [ "$Notify_name" == GENERIC-DEFAULT ] ; then
 sed -i "s/PD_HOST_TEMP/generic-host/;s/PD_SERVICE_TEMP/generic-service/g;" $Input_file
elif  [ "$Notify_name" == OPEXWISE ] ; then
 sed -i "s/PD_HOST_TEMP/OPEXWISE-Host/;s/PD_SERVICE_TEMP/OPEXWISE-Service/g;" $Input_file
elif [ "$Notify_name" == SUPPORT-FIRST ] ; then
 sed -i 's/PD_HOST_TEMP/SUPPORT-FIRST-Host/;s/PD_SERVICE_TEMP/SUPPORT-FIRST-Service/g;' $Input_file
elif [ "$Notify_name" == CIO ] ; then
 sed -i "s/PD_HOST_TEMP/CIO-Host/;s/PD_SERVICE_TEMP/CIO-Service/g;" $Input_file
elif [ "$Notify_name" == MTAP ] ; then
 sed -i 's/PD_HOST_TEMP/MTAP-Host/;s/PD_SERVICE_TEMP/MTAP-Service/g;' $Input_file
elif [ "$Notify_name" == SERVER-ADMINS ] ; then
 sed -i 's/PD_HOST_TEMP/SERVER-ADMINS-Host/;s/PD_SERVICE_TEMP/SERVER-ADMINS-Service/g;' $Input_file
elif [ "$Notify_name" == NET-SERVE ] ; then
 sed -i 's/PD_HOST_TEMP/NET-SERVE-Host/;s/PD_SERVICE_TEMP/NET-SERVE-Service/g;' $Input_file
elif [ "$Notify_name" == IOPEX-BLR ] ; then
 sed -i 's/PD_HOST_TEMP/IOPEX-BLR-Host/;s/PD_SERVICE_TEMP/IOPEX-BLR-Service/g;' $Input_file
else
 Notify_status=0
 echo -e "No Template found as $Notify_name \n\nPlease add one of the below name with -n argument then proceed\n\n\tGENERIC-DEFAULT\n\tOPEXWISE\n\tSUPPORT-FIRST\n\tSERVER-ADMINS\n\tNET-SERVE\n\tMTAP\n\tCIO"

 
 exit 1
fi

### Replacing the Arguments into file ###

sed -i "s/Hostname/$Host_name/;s/Host_IP/$Host_IP/;s/Community_String/$Community/;" $Input_file

### Tranfering the File from /tmp to icinga2 Hosts file location ###

if [ $? == 0 ] ; then

	echo -e "\n\nPlease Check a Backup file here $Input_file\n\n"
	sudo chown :icinga $Input_file
	echo -e "\n\nFile permissions changed successfully $Input_file\n\n"
	cp $Input_file $Output_file 
else
        echo -e "\n\nFailed to build the backup file..\n\n Please check the script usage\n\n"
        exit 1
fi


### Checking the exit code for above file tranfer ###
if [ $? == 0 ] ; then
	echo -e "\n\nHost file transfered Successfully\n\n"
else
        echo -e "\n\nFailed to transfer the backup file..\n\n Please provide right Crediential..\n\n"
	exit 1
fi

### Compiling the config files ###
if [ "$Compile_Mode" == "enabled" ] ; then 
	 	
case $Compile_Mode in
     enabled)
	 echo "Validating the Configuration file..."	 
         sudo icinga2 daemon -C
         if [ $? == 0 ] ; then
	         echo -e "\n\nIcinga2 Compiled Successfully..\n\n"
	 else
        	 echo -e "\n\nFailed to Validate the Configuration:- \n\n Please Check the Backup file in $Output_file..\n\n"
		 exit 1
	 fi
	 ;;
esac
fi

#### Reloading the ICINGA2 service ###
if [ "$Exec_Mode" == "enabled" ] ; then

case $Exec_Mode in
     enabled)
	 echo "Reloading the icinga2.services..." 
         sudo systemctl reload icinga2
	 if [ $? == 0 ] ; then
        	echo -e "\n\nIcinga2 Reloaded Successfully..\n\n"
         else
        	echo -e "\n\nFailed to reload the Icinga2.services.!! \n\n Please Check the Backup file in $Output_file..\n\n"
		exit 1
	 fi

 	 ;;
esac

fi

#### You can transfer the file to remote server by enabling the below lines ####
### Pls use this function if you aware of what you doing ###

#sync() {
#
#    echo scp -r -P $ssh_port $Input_file $ssh_user@$ssh_hosts:$ssh_conf_path
#    scp -r -P $ssh_port $Input_file $ssh_user@$ssh_hosts:$ssh_conf_path
#}
#
#echo -e "\n\nPlease Check a Backup file here $Output_file\n\n"
#
#
#for i in "${ssh_hosts[@]}"
#do
#    sync $i $Input_file $Output_file
#done
#

