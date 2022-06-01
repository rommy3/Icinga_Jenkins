#!/bin/sh
ECHO=/bin/echo
SCRIPT=/usr/lib64/nagios/plugins/check_snmp

ST_UK=3
ST_CR=2
ST_WR=1
ST_OK=0

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
	RAM_TOTAL=".1.3.6.1.4.1.2021.4.5.0"
	RAM_AVAIL=".1.3.6.1.4.1.2021.4.6.0"
	RAM_BUFFER=".1.3.6.1.4.1.2021.4.14.0"
	RAM_CACHE=".1.3.6.1.4.1.2021.4.15.0"
	TOTAL=`$SCRIPT -H $HOST -C $COM_STR -o $RAM_TOTAL | cut -d' ' -f4`
	AVAIL=`$SCRIPT -H $HOST -C $COM_STR -o $RAM_AVAIL | cut -d' ' -f4`
	CACHE=`$SCRIPT -H $HOST -C $COM_STR -o $RAM_CACHE | cut -d' ' -f4`
	BUFFER=`$SCRIPT -H $HOST -C $COM_STR -o $RAM_BUFFER | cut -d' ' -f4`
	if [[ $TOTAL != [0-9]* ]]; then
		ERROR="SNMP Timeout"
		$ECHO "UNKNOWN - $ERROR"
		exit $ST_UK
	elif [[ $AVAIL != [0-9]* ]]; then
                ERROR="SNMP Timeout"
                $ECHO "UNKNOWN - $ERROR"
		exit $ST_UK
	elif [[ $CACHE != [0-9]* ]]; then
                ERROR="SNMP Timeout"
                $ECHO "UNKNOWN - $ERROR"
                exit $ST_UK
	elif [[ $BUFFER != [0-9]* ]]; then
                ERROR="SNMP Timeout"
                $ECHO "UNKNOWN - $ERROR"
                exit $ST_UK


	else
		CB=$(($CACHE + $BUFFER))
		USED=$(($TOTAL - $AVAIL))
		USED_CB=$(($USED - $CB))
		USED_RAM=$(($USED_CB * 100))
		USED_PER=$(($USED_RAM / $TOTAL))
		if [ $USED_PER -ge $WARN -a $USED_PER -lt $CRIT ]; then
			$ECHO "WARNING - The Memory Utilization is $USED_PER % | Memory=$USED_PER%"
			exit $ST_WR
		elif [  $USED_PER -gt $CRIT ]; then
			$ECHO "CRITICAL  - The Memory Utilization is $USED_PER % | Memory=$USED_PER%"
			exit $ST_CR
		else
			$ECHO "OK  - The Memory Utilization is $USED_PER % | Memory=$USED_PER%"
			exit $ST_OK
		fi
	fi
}




usage(){
        $ECHO "RESPONSE: Error is - $ERROR"
        $ECHO "Usage: check_snmp.sh -C <Community String>  -H <Host>"
        exit 3
}

while getopts C:H:w:c: option
        do case "$option" in
                C) COM_STR=$OPTARG;;
                H) HOST=$OPTARG;;
		w) WARN=$OPTARG;;
		c) CRIT=$OPTARG;;
                *) ERROR="Illegal option used"
                        usage;;
        esac
done
checkinputs
execute

	
