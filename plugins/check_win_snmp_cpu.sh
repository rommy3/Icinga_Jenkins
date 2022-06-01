#!/bin/bash

SNMPWALK=/usr/bin/snmpwalk
ECHO=/bin/echo
CUT=/bin/cut
EXPR=/usr/bin/expr
GREP=/bin/grep

WIN_CPU_OID=".1.3.6.1.2.1.25.3.3.1.2"

usage(){
	$ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
	$ECHO "Usage: check_win_snmp_cpu.sh -h <host> -s <community string> -w <warning in %> -c <critical in %>"
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
	for PATH in $SNMPWALK $CUT $EXPR $GREP; do 
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

checkcpuload(){
	COUNT=0
	TOTAL=0
	RESULT=`$SNMPWALK -v 1 -c $COMSTR $HOST $WIN_CPU_OID 2>&1 | $GREP "hrProcessorLoad" | $CUT -d' ' -f4`
	if [[ "$RESULT" != "" ]]; then
		#RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
		for i in $RESULT; do
			TOTAL=`$EXPR $TOTAL + $i`
			COUNT=`$EXPR $COUNT + 1`
		done
		AVG=`$EXPR $TOTAL / $COUNT`
		OUTMSG="Average CPU Load $AVG | CPU=$AVG%"
		if [[ $AVG -ge $CRIT ]]; then
			STATUS=CRITICAL
		elif [[ $AVG -ge $WARN ]]; then
			STATUS=WARNING
		else
			STATUS=OK
		fi
	else
		STATUS=UNKNOWN
		OUTMSG="Timeout: No Response from $HOST"
	fi
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
checkcpuload
output
