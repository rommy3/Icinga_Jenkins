#!/bin/sh
####################################################################################################################################################
## Version : 1.1
## Author  : Shan
## Purpose : Pass standard thresholds for CPU load average. Identify numberof cores and raise the threshold based on number of cores on the fly
## Origin  : check_linux_load_snmp.sh nagios plugin modified for above purpose
## Date	   : 19 - March - 2018
#####################################################################################################################################################

## Declare command variables to tell shell where to find these. 
ECHO=/bin/echo
SCRIPT=/usr/lib64/nagios/plugins/check_snmp
GREP=/bin/grep
CUT=/bin/cut
EXPR=/usr/bin/expr
BC=/usr/bin/bc
SNMPWALK=/usr/bin/snmpwalk

## SNMP MIBs To use for Polling
Load_1_OID=.1.3.6.1.4.1.2021.10.1.3.1
Load_5_OID=.1.3.6.1.4.1.2021.10.1.3.2
Load_15_OID=.1.3.6.1.4.1.2021.10.1.3.3
CPU_OID=.1.3.6.1.2.1.25.3.3.1.2

## Check declared command paths to ensure all required commands are present in the system
checkpaths(){
	for PATH in $ECHO $GREP $SCRIPT $CUT $EXPR $SNMPWALK $BC; do 
		if [ ! -f "$PATH" ]; then
			STATUS=UNKNOWN
			OUTMSG="ERROR: $PATH does does not exist"
			output
		fi
	done
}

## Function to frame output and include the nagios exit status
output(){
	$ECHO "$STATUS - $OUTMSG"
	if [ "$STATUS" = "OK" ]; then
		exit 0
	elif [ "$STATUS" = "WARNING" ]; then
		exit 1
	elif [ "$STATUS" = "CRITICAL" ]; then
		exit 2
	fi
	exit 3
}

## Usage function to inform an user what is required by the script
usage(){
	$ECHO "RESPONSE: Error is - $ERROR"
	$ECHO "Usage: check_linux_load_snmp.sh -C <community string> -H <host> -w <warning for 3 loads like 1.2:1:2 (pass based thresholds and see it raised based on cores automatically> -c <critical for 3 loads 1.05:1.2:1.6 and see it raised based on cores automatically>"
	exit 3
}

## Check inputs provided by user for an invalid entries. 
checkinputs(){
	if [ ! -n "$WARN" ]; then
		ERROR="Warning not set"
		usage
	fi
	if [ ! `$ECHO $WARN | $GREP -E '^([0-9]+.?[0-9]*:){2}[0-9]+.?[0-9]*'` ]; then
		ERROR="Incorrect format Warning or Warning must be an numeric other than zero, see usage"
		usage
	fi
	if [ ! -n "$CRIT" ]; then
		ERROR="Critical not set"
		usage
	fi
	if [ ! `$ECHO $CRIT | $GREP -E '^([0-9]+.?[0-9]*:){2}[0-9]+.?[0-9]*'` ]; then
		ERROR="Incorrect format Critical or Critical must be an numeric other than zero, see usage"
		usage
	fi
	if [ ! -n "$COM_STR" ]; then
		ERROR="Community String Not Set"
		usage
	fi
	if [ ! -n "$HOST" ]; then
		ERROR="Host Not Set"
		usage
	fi
	if [ -n $SKIP ]; then
		OLDIFS=$IFS
		IFS=','
		for i in $SKIP
		do
			case $i in
				1)
					SKIP1=1;;
				5)
					SKIP5=1;;
				15)
					SKIP15=1;;
				*)
					ERROR="Invalid values in option -s Skip, Possible values are 1,5,15"
					usage
			esac
		done
	fi

	IFS=':'
	WARN=($WARN)
	WARN1=${WARN[0]}
	WARN5=${WARN[1]}
	WARN15=${WARN[2]}
	CRIT=($CRIT)
	CRIT1=${CRIT[0]}
	CRIT5=${CRIT[1]}
	CRIT15=${CRIT[2]}
	IFS=$OLDIFS
}

# Checking CPU cores
checkcpucores(){
        CORES=0
        TOTAL=0
        RESULT=`$SNMPWALK -v 1 -c $COM_STR $HOST $CPU_OID | $CUT -d' ' -f4`
	#$ECHO $RESULT
        if [[ "$RESULT" != "" ]]; then
                #RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
                for i in $RESULT; do
                        TOTAL=`$EXPR $TOTAL + $i`
                        CORES=`$EXPR $CORES + 1`
                done
	#	$ECHO $CORES
                if [[ "$CORES" != 0 ]]; then
	#		$ECHO $CORES
                	WARN1=$($BC <<< "$WARN1 * $CORES")
			WARN5=$($BC <<< "$WARN5 * $CORES")
			WARN15=$($BC <<< "$WARN15 * $CORES")
			CRIT1=$($BC <<< "$CRIT1 * $CORES")
			CRIT5=$($BC <<< "$CRIT5 * $CORES")
			CRIT15=$($BC <<< "$CRIT15 * $CORES")

         #       	$ECHO $WARN1 $WARN5 $WARN15 $CRIT1 $CRIT5 $CRIT15
        	fi
	else
		continue
        fi
}




## Function for load 1
checkload1(){
	RESULT1=`$SCRIPT -H $HOST -C $COM_STR -o $Load_1_OID 2>&1| $CUT -d'"' -f2`
	case $RESULT1 in
		*Timeout*)
			STATUS=UNKNOWN
			OUTMSG="Load1 SNMP Timeout"
			output;;
		*Unknown*)
			STATUS=UNKNOWN
			OUTMSG="Unknown Response"
			output;;
		*Error*)
			STATUS=UNKNOWN
			OUTMSG="Unknown Response"
			output
	esac
	if [[ `$ECHO "scale=2;$RESULT1 < $WARN1" | $BC` -eq 1 ]]; then
		STATUS1=OK
	elif [[ `$ECHO "scale=2;$RESULT1 >= $WARN1" | $BC` -eq 1 && `$ECHO "scale=2;$RESULT1 < $CRIT1" | $BC` -eq 1 ]]; then
		STATUS1=WARNING
	elif [[ `$ECHO "scale=2;$RESULT1 >= $CRIT1" | $BC` -eq 1 ]]; then
		STATUS1=CRITICAL
	fi
}

#function for load 5
checkload5(){
	RESULT5=`$SCRIPT -H $HOST -C $COM_STR -o $Load_5_OID | $CUT -d'"' -f2`
	case $RESULT5 in
		*Timeout*)
			STATUS=UNKNOWN
			OUTMSG="Load5 SNMP Timeout"
			output
	esac
	if [[ `$ECHO "scale=2;$RESULT5 < $WARN5" | $BC` -eq 1 ]]; then
		STATUS5=OK
	elif [[ `$ECHO "scale=2;$RESULT5 >= $WARN5" | $BC` -eq 1 && `$ECHO "scale=2;$RESULT5 < $CRIT5" | $BC` -eq 1 ]]; then
		STATUS5=WARNING
	elif [[ `$ECHO "scale=2;$RESULT5 >= $CRIT5" | $BC` -eq 1 ]]; then
		STATUS5=CRITICAL
	fi
}

# function for load 15
checkload15(){
	RESULT15=`$SCRIPT -H $HOST -C $COM_STR -o $Load_15_OID | $CUT -d'"' -f2`
	case $RESULT15 in
		*Timeout*)
			STATUS=UNKNOWN
			OUTMSG="Load15 SNMP Timeout"
			output
	esac
	if [[ `$ECHO "scale=2;$RESULT15 < $WARN15" | $BC` -eq 1 ]]; then
		STATUS15=OK
	elif [[ `$ECHO "scale=2;$RESULT15 >= $WARN15" | $BC` -eq 1 && `$ECHO "scale=2;$RESULT15 < $CRIT15" | $BC` -eq 1 ]]; then
		STATUS15=WARNING
	elif [[ `$ECHO "scale=2;$RESULT15 >= $CRIT15" | $BC` -eq 1 ]]; then
		STATUS15=CRITICAL
	fi
}

# main function that is going to inherit and call the above load function
checkload(){
	OUTMSG="The Load Average is"
	if [[ ! -n "$SKIP1" ]]; then
		checkload1
		OUTMSG1="\"$RESULT1\";"
		OUTMSG2="Load1=$RESULT1; "
	fi
	if [[ ! -n "$SKIP5" ]]; then
		checkload5
		OUTMSG1="$OUTMSG1\"$RESULT5\";"
		OUTMSG2="${OUTMSG2}Load5=$RESULT5; "
	fi
	if [[ ! -n "$SKIP15" ]]; then
		checkload15
		OUTMSG1="$OUTMSG1\"$RESULT15\""
		OUTMSG2="${OUTMSG2}Load15=$RESULT15"
	fi
	if [[ "$STATUS1" == "WARNING" || "$STATUS5" == "WARNING" || "$STATUS15" == "WARNING" ]]; then
		STATUS=WARNING
	elif [[ "$STATUS1" == "CRITICAL" || "$STATUS5" == "CRITICAL" || "$STATUS15" == "CRITICAL" ]]; then
		STATUS=CRITICAL
	else
		STATUS=OK
	fi
	OUTMSG="$OUTMSG $OUTMSG1 | $OUTMSG2"
	output
}

## declare options for the script
while getopts C:H:w:c:s: option
	do case "$option" in
		C) COM_STR=$OPTARG;;
		H) HOST=$OPTARG;;
		w) WARN=$OPTARG;;
		c) CRIT=$OPTARG;;
		s) SKIP=$OPTARG;;
		*) ERROR="Illegal option used"
			usage;;
	esac
done


## Call the functions in required order. Without this all the above is a waste. 
checkpaths
checkinputs
checkcpucores
checkload
