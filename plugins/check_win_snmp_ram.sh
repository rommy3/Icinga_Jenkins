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
WIN_STOR_ALLO_OID=".1.3.6.1.2.1.25.2.3.1.4"
WIN_STOR_SIZE_OID=".1.3.6.1.2.1.25.2.3.1.5"
WIN_STOR_USED_OID=".1.3.6.1.2.1.25.2.3.1.6"

TEBY=1099511627776
GIBY=1073741824
MEBY=1048576
KIBY=1024

usage(){
	$ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
	$ECHO "Usage: check_win_snmp_ram.sh -h <host> -s <community string> -w <warning in %> -c <critical in %>"
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
	VALUE=$1
	TOTAL=`$EXPR $VALUE \* $STOR_ALLO_UNITS`
	if [[ `$EXPR $TOTAL '>=' $TEBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE*$STOR_ALLO_UNITS/$TEBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'` TiB"
	elif [[ `$EXPR $TOTAL '>=' $GIBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE*$STOR_ALLO_UNITS/$GIBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'` GiB"
	elif [[ `$EXPR $TOTAL '>=' $MEBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE*$STOR_ALLO_UNITS/$MEBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'` MiB"
	elif [[ `$EXPR $TOTAL '>=' $KIBY` -eq 1 ]]; then
		STR="`$ECHO "scale=1;$VALUE*$STOR_ALLO_UNITS/$KIBY" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'` KiB"
	elif [[ $TOTAL -gt 0 ]]; then
		STR="`$EXPR $VALUE * $STOR_ALLO_UNITS` B"
	else
		STR=0
	fi
	case $2 in
	  1)
	    STR1=$STR
	    ;;
	  2)
	    STR2=$STR
	    ;;
	  3)
	    STR3=$STR
	    ;;
	esac
			

		
}

checkstatus(){
	if [[ $1 -ne 0 ]]; then
		STATUS=UNKNOWN
		OUTMSG=$2
		output
	fi
}

getindex(){
	STOR_INDEX=`$SNMPWALK -v 1 -c $COMSTR $HOST $WIN_STOR_TYPE_OID 2>&1 | $GREP "hrStorageRam" | $SED 's/[^0-9]\+//g'`
	if [[ "$STOR_INDEX" = "" ]]; then
		checkstatus 1 "Timeout: No Response from $HOST"
	fi
}

getalloc(){
	STOR_ALLO_UNITS=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_ALLO_OID}.${STOR_INDEX} 2>&1`
	checkstatus $? "ERROR: In getting ram allocation units"
	STOR_ALLO_UNITS=`$ECHO $STOR_ALLO_UNITS | $CUT -d' ' -f4`
}

getsize(){
	STOR_SIZE=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_SIZE_OID}.${STOR_INDEX} 2>&1`
	checkstatus $? "ERROR: In getting ram size"
	STOR_SIZE=`$ECHO $STOR_SIZE | $CUT -d' ' -f4`
}

getused(){
	STOR_USED=`$SNMPGET -v 1 -c $COMSTR $HOST ${WIN_STOR_USED_OID}.${STOR_INDEX} 2>&1`
	checkstatus $? "ERROR: In getting used size of ram"
	STOR_USED=`$ECHO $STOR_USED | $CUT -d' ' -f4`
}

calcused(){
	if [[ $STOR_SIZE -gt 0 ]]; then
		STOR_USED_PERCENT=`$ECHO "scale=3;$STOR_USED/$STOR_SIZE*100" | $BC | $SED 's/\.0\+$//;s/\.\([1-9]\+\)0\+$/.\1/'`
	else
		STOR_USED_PERCENT=0
	fi
}

calcfree(){
	STOR_FREE=`$EXPR $STOR_SIZE - $STOR_USED`
}

checkramusage(){
	getindex
	getalloc
	getsize
	getused
	calcused
	calcfree
	converthrf $STOR_SIZE 1
	converthrf $STOR_USED 2
	converthrf $STOR_FREE 3
	 if (($(echo "$STOR_USED_PERCENT < $WARN" | $BC)==1)); then
                STATUS=OK
        elif (($(echo "$STOR_USED_PERCENT < $CRIT" | $BC)==1)); then
                STATUS=WARNING
        elif (($(echo "$STOR_USED_PERCENT >= $CRIT" | $BC)==1)); then
                STATUS=CRITICAL
	else
		STATUS=ERROR
	fi
	OUTMSG="Percent Used : $STOR_USED_PERCENT%, Total : $STR1, Used : $STR2, Free : $STR3 | RAM=$STOR_USED_PERCENT%"
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
checkramusage
output
