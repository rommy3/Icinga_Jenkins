#!/bin/bash

SNMPWALK=/usr/bin/snmpwalk
ECHO=/bin/echo
CUT=/bin/cut
EXPR=/usr/bin/expr
GREP=/bin/grep
BC=/usr/bin/bc
#CPU_OID="1.3.6.1.4.1.9.9.109.1.1.1.1.5"
mem_used="1.3.6.1.4.1.9.9.48.1.1.1.5.1"
mem_free="1.3.6.1.4.1.9.9.48.1.1.1.6.1"


TMOUT=5
RETRYCNT=1

usage(){
	$ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
	$ECHO "Usage: test.sh -h <host> -s <community string> -w <warning in %> -c <critical in %>"
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

checkmem(){
	COUNT=0
	TOTAL=0
	re='^[0-9]+$'
	mused=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v 1 -c $COMSTR $HOST $mem_used 2>&1 | $CUT -d' ' -f4`
	if ! [[ $mused =~ $re ]]; then
	 STATUS=UNKNOWN
	 OUTMSG="Timeout: No Response from $HOST"
	 output
	fi
	mfree=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v 1 -c $COMSTR $HOST $mem_free 2>&1 | $CUT -d' ' -f4`
	if [[ "$mused" != "" ]] && [[ "$mfree" != "" ]]; then
	 mtotal=`$EXPR $mused + $mfree`
	 MEBY="1048576"
	 mused_mb=$(echo "scale=1; $mused / $MEBY" | $BC)
	 mfree_mb=$(echo "scale=1; $mfree / $MEBY" | $BC)
	 mtotal_mb=$(echo "scale=1; $mtotal / $MEBY" | $BC)
	 used_per=$(echo "scale=1; ($mused_mb / $mtotal_mb) * 100" | $BC -l)
	 OUTMSG="Device Processor Memory utilization is $used_per % | CPU=$used_per;$WARN;$CRIT;0;100"
	 	if [[ $used_per > $CRIT ]]; then
			STATUS=CRITICAL
		elif [[ $used_per > $WARN ]]; then
			STATUS=WARNING
		else
			STATUS=OK
		fi
	else
	 STATUS=UNKNOWN
	 OUTMSG="Timeout: No Response from $HOST"
	fi
}

while getopts h:s:w:c:q:z: option
	do case "$option" in
		h) HOST=$OPTARG;;
		s) COMSTR=$OPTARG;;
		w) WARN=$OPTARG;;
		c) CRIT=$OPTARG;;
		q) TMOUT=$OPTARG;;
		z) RETRYCNT=$OPTARG;;
		
		*) ERROR="Illegal option used"
			usage;;
	esac
done

checkpaths
checkinputs
checkmem
output

