#!/bin/bash

### Script Usage ###
function show_usage (){
    printf "\n################################## Please refer the below usage and proceed ##################################\n"
    printf " '-h|--help' Print help\n"
    printf " '-I|--IP' to get the Hostname\n"
    printf " '-S|--service' which the service you want to modify the threshold\n"
    printf " '-b|--band' if its a Bandwidth Service use -b optioni\n"
    printf " '-w|--warn' for input the Warning level\n"
    printf " '-c|--crit' for input the Critical level\n"
    printf " '-C|--compile' to compile the configuration\n"
    printf " '-R|--reload' to Reload the Icinga2 service\n"
    printf " \nExample for script usage:\n\n$0 -I IP_ADDRESS -S Service_Name ('for bandwidth' -b) -w Warn_level -c Critical_level (-C or -R )\n\n"
    printf " Use -C option as a end argument to Compile the Output.\n\n"
    printf " Use -R option as a end argument to Reload the icinga2 services\n\n"
    printf " Refer the above Examples before proceeding\n\n"
return 0
}

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ $# == 0 ]] ;then
    show_usage
    exit 1
fi

### Optional input for Compile or Reload the icinga2 ###
if [ "${*: -1}" == "-C" ] || [ "${*: -1}" == "Compile" ] ; then
Compile_Mode=enabled

fi

if [ "${*: -1}" == "-R" ] || [ "${*: -1}" == "Reload" ] ; then

Exec_Mode=enabled

fi

### OPTARGS ###
while [ ! -z "$1" ]; do
  case "$1" in
     --ip|-I)
         shift
         Host_IP=$1
         ;;

     --service|-S)
         shift
         Service=$1
         ;;
     
     --band|-b)
	 Bandwidth=enabled
	 ;;

     --warn|-w)
         shift
         Warn=$1
	 ;;

     --crit|-c)
	 shift
	 Crit=$1

  esac
 shift
done

### Variable definitions ###
template_path="/home/Jenkins/Templates/"
if [ -z $Host_IP ] || [ $Host_IP == -S ] ;then 
	echo -e "Host_IP not given this will not process the Hostfile"
else
        Hostname=`grep -l $Host_IP /etc/icinga2/iopex.d/Hosts/*.conf | awk -F/ '{print $NF}'`
	if [ -z $Service ];then
		echo -e "Service_Name not given this will not process the Hostfile"
	else
		SERV_grep=`grep $Service /etc/icinga2/iopex.d/Hosts/$Hostname`
	fi
fi



### Script Process and validations ###

#sed "/RAM/ { n; n; n; n; n; s/[0-9][0-9]\"/$Warn\"/; }"
 
if [[ -n $SERV_grep ]]; then
	echo -e "\nHost: $Hostname \n\nService Line: $SERV_grep"
  if [[ -n $Service ]] && [[ $Bandwidth != enabled ]];then
  	echo -e "\n\nService has been found \n\nChanging the threshold values\n"
  	sed -i "/$Service/I { n; n; n; n; n; s/[0-9][0-9]\"/$Warn\"/; }" /etc/icinga2/iopex.d/Hosts/$Hostname
	sed -i "/$Service/I { n; n; n; n; n; n; s/[0-9][0-9]\"/$Crit\"/; }" /etc/icinga2/iopex.d/Hosts/$Hostname
	if [[ $? -eq 0 ]];then
		echo -e "\nValues changed Sucessfully\n"
	else
		echo -e "\nSed Operation Failed\n"
		exit 1
	fi
  elif [[ -n $Service ]] && [[ $Bandwidth == enabled ]];then
	   echo -e "\n\nBandwidth Service has been found \n\nChanging the threshold values\n"
	if [ -n $Warn ];then
        sed -i "/$Service/I { n; n; n; n; n; n; n; n; s/[0-9][0-9]\"/$Warn\"/; }" /etc/icinga2/iopex.d/Hosts/$Hostname
	fi
	if [ -n $Crit ];then
        sed -i "/$Service/I { n; n; n; n; n; n; n; n; n; s/[0-9][0-9]\"/$Crit\"/; }" /etc/icinga2/iopex.d/Hosts/$Hostname
	fi
        if [[ $? -eq 0 ]];then
                echo -e "\nValues changed Sucessfully\n"
        else
                echo -e "\nSed Operation Failed\n"
                exit 1
        fi

  else 
  	echo -e "\n\nPlease Provide the Service Name to Continue\n\n"
	show_usage
  	exit 1
  
  fi
else
	if [[ -z $Compile_Mode ]] && [[ -z $Exec_Mode ]] ; then
		show_usage
        	echo -e "\n\nService not found in the /etc/icinga2/iopex.d/Hosts/$Hostname\n\n"
        	echo -e "\nPlease validate the file and Proceed\n"
		echo $Compile_Mode
        	exit 1
	else
		echo -e "\nValidating Configuration without Changing the Hostfiles\n"
	fi

fi


### Compile Mode ###
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
