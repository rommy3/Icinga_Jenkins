#!/bin/bash

SNMPWALK=/usr/bin/snmpwalk
SNMPGET=/usr/bin/snmpget
ECHO=/bin/echo
CUT=/bin/cut
GREP=/bin/grep
SED=/bin/sed
BC=/usr/bin/bc
EXPR=/usr/bin/expr

WIN_STOR_TYPE_OID=".1.3.6.1.2.1.25.2.3.1.2"
WIN_STOR_LABE_OID=".1.3.6.1.2.1.25.2.3.1.3"
WIN_STOR_ALLO_OID=".1.3.6.1.2.1.25.2.3.1.4"
WIN_STOR_SIZE_OID=".1.3.6.1.2.1.25.2.3.1.5"
WIN_STOR_USED_OID=".1.3.6.1.2.1.25.2.3.1.6"

TEBY=1099511627776
GIBY=1073741824
MEBY=1048576
KIBY=1024

usage(){
	$ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
	$ECHO "Usage: check_win_snmp_cdrive.sh -h <host> -s <community string> -w <warning in %> -c <critical in %>"
	exit 3
}

output(){
	$ECHO "RESPONSE: $STATUS - $OUTMSG"
	if [ "$STATUS" = "OK" ]; then
		exit 0
	elif [ "$STATUS" = "WARNING" ]; then
		exit 1
	elif [ "$STATUS" = "CRITICAL" ]; then
		exit 2
	fi
	exit 3
}

checkpaths(){
	for PATH in $SNMPWALK $SNMPGET $CUT $GREP $SED $EXPR; do 
		if [ ! -f "$PATH" ]; then
			STATUS=UNKNOWN
			OUTMSG="ERROR: $PATH does not exist"
			output
		fi
	done
}

# Check inputs and formats
checkinputs(){
	if [ ! -n "$HOST" ]; then
		ERROR="Host not set"
		usage
	fi
	if [ ! -n "$COMSTR" ]; then
		ERROR="Community String not set"
		usage
	fi
	if [ ! -n "$WARN" ]; then
		ERROR="Warning not set"
		usage
	fi
  case $WARN in
    *[!0-9]*)
		  ERROR="Warning must be an integer in %"
		  usage
	esac
	if [ ! -n "$CRIT" ]; then
		ERROR="Critical not set"
		usage
	fi
  case $CRIT in
    *[!0-9]*)
		  ERROR="Critical must be an integer in %"
		  usage
	esac
	if [ "$CRIT" -lt "$WARN" ]; then
		ERROR="Critical must be greater than Warning"
		usage
	fi
}

converthrf(){
	VALUE1=$1
	VALUE2=$2
	TOTAL=`$EXPR $VALUE1 \* $VALUE2`
	if [[ `$EXPR $TOTAL '>=' $TEBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE1*$VALUE2/$TEBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`TiB"
	elif [[ `$EXPR $TOTAL '>=' $GIBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE1*$VALUE2/$GIBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`GiB"
	elif [[ `$EXPR $TOTAL '>=' $MEBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE1*$VALUE2/$MEBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`MiB"
	elif [[ `$EXPR $TOTAL '>=' $KIBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE1*$VALUE2/$KIBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`KiB"
	elif [[ $TOTAL -gt 0 ]]; then
		STR="`$EXPR $VALUE1 * $VALUE2`B"
	else
		STR=0
	fi
	$ECHO $STR
}

checkstatus(){
	if [[ $1 -ne 0 ]]; then
		STATUS=UNKNOWN
		OUTMSG=$2
		output
	fi
}

getalloc(){
	ALLOC_UNITS=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_ALLO_OID}.${1} 2>&1`
	checkstatus $? "ERROR: In getting drive allocation units"
	ALLOC_UNITS=`$ECHO $ALLOC_UNITS | $CUT -d' ' -f4`
	$ECHO $ALLOC_UNITS
}

getsize(){
	STOR_SIZE=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_SIZE_OID}.${1} 2>&1`
	checkstatus $? "ERROR: In getting drive size"
	STOR_SIZE=`$ECHO $STOR_SIZE | $CUT -d' ' -f4`
	$ECHO $STOR_SIZE
}

getused(){
	STOR_USED=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_USED_OID}.${1} 2>&1`
	checkstatus $? "ERROR: In getting used size of drive"
	STOR_USED=`$ECHO $STOR_USED | $CUT -d' ' -f4`
	$ECHO $STOR_USED
}

calcused(){
	if [[ $1 -gt 0 ]]; then
		STOR_USED_PERCENT=`$ECHO "scale=3;${2}/${1}*100" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`
	else
		STOR_USED_PERCENT=0
	fi
	$ECHO $STOR_USED_PERCENT
}

collectalloc(){
	for i in $DRIVE_INDEXES
	do
		ret_value=$(getalloc $i)
		ALL_ALLOC_UNITS="$ALL_ALLOC_UNITS $ret_value"
	done
	ALL_ALLOC_UNITS=($ALL_ALLOC_UNITS)
}

collectsize(){
	for i in $DRIVE_INDEXES
	do
		ret_value=$(getsize $i)
		ALL_STOR_SIZE="$ALL_STOR_SIZE $ret_value"
	done
	ALL_STOR_SIZE=($ALL_STOR_SIZE)
}

collectused(){
	for i in $DRIVE_INDEXES
	do
		ret_value=$(getused $i)
		ALL_STOR_USED="$ALL_STOR_USED $ret_value"
	done
	ALL_STOR_USED=($ALL_STOR_USED)
}

calcusedper(){
	temp=($DRIVE_INDEXES)
	for (( i = 0; i < ${#temp[@]}; i++ ))
	do
		ret_value=$(calcused ${ALL_STOR_SIZE[$i]} ${ALL_STOR_USED[$i]})
		PERCENT_USED="$PERCENT_USED $ret_value"
	done
	PERCENT_USED=($PERCENT_USED)
}

calcfree(){
	temp=($DRIVE_INDEXES)
	for (( i = 0; i < ${#temp[@]}; i++ ))
	do
		FREE_UNITS=`$EXPR ${ALL_STOR_SIZE[$i]} - ${ALL_STOR_USED[$i]}`
		ALL_STOR_FREE="$ALL_STOR_FREE $FREE_UNITS"
	done
	ALL_STOR_FREE=($ALL_STOR_FREE)
}

hrformat(){
	temp=($DRIVE_INDEXES)
	for (( i = 0; i < ${#temp[@]}; i++ ))
	do
		ret_value=$(converthrf ${ALL_STOR_SIZE[$i]} ${ALL_ALLOC_UNITS[$i]})
		SIZESTR="$SIZESTR $ret_value"
		ret_value=$(converthrf ${ALL_STOR_USED[$i]} ${ALL_ALLOC_UNITS[$i]})
		USEDSTR="$USEDSTR $ret_value"
		ret_value=$(converthrf ${ALL_STOR_FREE[$i]} ${ALL_ALLOC_UNITS[$i]})
		FREESTR="$FREESTR $ret_value"
	done
	SIZESTR=($SIZESTR)
	USEDSTR=($USEDSTR)
	FREESTR=($FREESTR)
}

diskusage(){
#	TOTAL_USED=`$ECHO ${PERCENT_USED[*]} | $SED 's/ /+/g' | $BC`
#	DISK_USAGE=`$ECHO "scale=3;${TOTAL_USED}/${#PERCENT_USED[@]}" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`
	total_drives=${#DRIVE_LABLES[@]}
	for (( i=0; i<total_drives; i++ ))
	do
		if [[ `$ECHO "${PERCENT_USED[$i]} < $WARN" | $BC` -eq 1 ]]; then
			OK="$OK ${DRIVE_LABLES[$i]}-${PERCENT_USED[$i]}%"
		elif [[ `$ECHO "${PERCENT_USED[$i]} < $CRIT" | $BC` -eq 1 ]]; then
			WARNING="$WARNING ${DRIVE_LABLES[$i]}-${PERCENT_USED[$i]}%"
		elif [[ `$ECHO " ${PERCENT_USED[$i]}>= $CRIT" | $BC` -eq 1 ]]; then
			CRITICAL="$CRITICAL ${DRIVE_LABLES[$i]}-${PERCENT_USED[$i]}%"
		fi
	done
}

formstring(){
	temp=($DRIVE_INDEXES)
	for (( i = 0; i < ${#temp[@]}; i++ ))
	do
		DETAIL_STR="$DETAIL_STR ${}"
	done
}

searchindex(){
	while read line
	do
		if [[ `$ECHO $line | $GREP "^Timeout:"` != "" ]]; then
			checkstatus 1 "$line"
		fi
		if [[ `$ECHO $line | $GREP hrStorageFixedDisk` != "" ]]; then
			INDEX=`$ECHO $line | $SED 's/[^0-9]\+//g'`
			DRIVE_INDEXES="$DRIVE_INDEXES $INDEX"
		fi
	done <<< "`$SNMPWALK -v 1 -c $COMSTR $HOST $WIN_STOR_TYPE_OID 2>&1`"
}

searchlabel(){
	for i in $DRIVE_INDEXES
	do
		LABLES=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_LABE_OID}.${i} 2>&1`
		checkstatus $? "$LABLES"
		DRIVE_LABLES="$DRIVE_LABLES `$ECHO $LABLES | $CUT -d' ' -f4`"
	done
	DRIVE_LABLES=($DRIVE_LABLES)
}

searchdrive(){
	searchindex
	searchlabel
}

checkdrive(){
	collectalloc
	collectsize
	collectused
	calcusedper
	calcfree
	hrformat
	diskusage
	if [[ -n $CRITICAL ]]; then
		STATUS=CRITICAL
	elif [[ -n $WARNING ]]; then
		STATUS=WARNING
	elif [[ -n $OK ]]; then
		STATUS=OK
	else
		STATUS=ERROR
		OUTMSG="Unknown Response from $HOST"
		output
	fi
	#OUTMSG="Percent Used : $DISK_USAGE% - ${DRIVE_LABLES[*]} [${PERCENT_USED[*]}]"
	#OUTMSG="Percent Used : $DISK_USAGE%"
}

formoutput(){
	total_drives=${#DRIVE_LABLES[@]}
	OUTMSG=""
	if [[ -n $CRITICAL ]]; then
		OUTMSG="Critical Drives[$CRITICAL] "
	fi
	if [[ -n $WARNING ]]; then
		OUTMSG="${OUTMSG}Warning Drives[$WARNING] "
	fi
	for (( i=0; i<total_drives; i++ ))
	do
		OUTMSG="$OUTMSG${DRIVE_LABLES[$i]}=${PERCENT_USED[$i]}%used(Total:${SIZESTR[$i]},Used:${USEDSTR[$i]}-Free:${FREESTR[$i]});"
		PERFDATA="$PERFDATA${DRIVE_LABLES[$i]}=${PERCENT_USED[$i]}% "
	done
	OUTMSG="$OUTMSG | $PERFDATA"
}

while getopts h:s:w:c: option
	do case "$option" in
		h) HOST=$OPTARG;;
		s) COMSTR=$OPTARG;;
		w) WARN=$OPTARG;;
		c) CRIT=$OPTARG;;
		*) ERROR="Illegal option used"
			usage;;
	esac
done

checkpaths
checkinputs
searchdrive
checkdrive
formoutput
output
