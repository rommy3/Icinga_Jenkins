#!/bin/sh
ECHO=/bin/echo
SCRIPT=/usr/local/libexec/check_snmp

ST_UK=3
ST_CR=2
ST_WR=1
ST_OK=0

TMOUT=30
RETRYCNT=1

checkpaths(){
        for PATH in $ECHO; do
                if [ ! -f "$PATH" ]; then
                        STATUS=UNKNOWN
                        OUTMSG="ERROR: $PATH does does not exist"
                        output
                fi
        done
}


checkinputs(){
	if [ ! -n "$WARN" ]; then
		ERROR="set WARNING threshold in %"
		usage
	fi
	if [ ! -n "$CRIT" ]; then
		ERROR="set CRITICAL threshold in %"
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
}

execute(){
	disk_OID=1.3.6.1.2.1.25.2.3.1.3.31
	RESULT=`$SCRIPT -e $RETRYCNT -t $TMOUT -H $HOST -C $COM_STR -o $disk_OID | cut -d' ' -f4`
	if [[ $RESULT != [0-9]* ]]; then
		ERROR="SNMP Timeout"
		$ECHO "UNKNOWN - $ERROR"
		exit $ST_UK
	else
	
		if [ $RESULT -ge $WARN -a $RESULT -lt $CRIT ]; then
			$ECHO "WARNING - Root Partition usage $RESULT % | DISK=$RESULT%"
			exit $ST_WR
		elif [  $RESULT -gt $CRIT ]; then
			$ECHO "CRITICAL  - Root Partition usage $RESULT % | DISK=$RESULT%"
			exit $ST_CR
		else
			$ECHO "OK  - Root Partition usage $RESULT % | DISK=$RESULT%"
			exit $ST_OK
		fi
	fi
}




usage(){
        $ECHO "RESPONSE: Error is - $ERROR"
        $ECHO "Usage: check_snmp.sh -C <Community String>  -H <Host>"
        exit 3
}

while getopts C:H:w:c:q:z: option
        do case "$option" in
                C) COM_STR=$OPTARG;;
                H) HOST=$OPTARG;;
		w) WARN=$OPTARG;;
		c) CRIT=$OPTARG;;
		q) TMOUT=$OPTARG;;
		z) RETRYCNT=$OPTARG;;
                *) ERROR="Illegal option used"
                        usage;;
        esac
done
checkinputs
execute
