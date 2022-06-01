#!/bin/bash
# Author - Shan
# Version - 1.1, Date - 23/05/2014
# Purpose - to find system uptime of a host via snmp response
# Use case - Most servers might have ping blocked, we can monitor those server uptime using this check script

SNMPWALK=/usr/bin/snmpwalk
ECHO=/bin/echo
CUT=/bin/cut
EXPR=/usr/bin/expr
GREP=/bin/grep

Sysuptime_OID="1.3.6.1.2.1.1.3.0"

TMOUT=30
RETRYCNT=1

usage(){
        $ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
        $ECHO "Usage: check_uptime.sh -h <host> -s <community string> -w <warning in %> -c <critical in %>"
        $ECHO "Note : Critical value must be lesser than Warning value. This is because a lower sysuptime value means the system rebooted recently"
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
        if [ ! -n "$CRIT" ]; then
                ERROR="Critical not set"
                usage
        fi
        if [ "$CRIT" -gt "$WARN" ]; then
                ERROR="Critical must be lesser than Warning"
                usage
        fi
}

checkuptime(){
        COUNT=0
        TOTAL=0
        RESULT=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v2c -c $COMSTR $HOST $Sysuptime_OID 2>&1 | $CUT -d'(' -f2| $CUT -d')' -f1`
        if [[ "$RESULT" != "" ]]; then
                #RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
                for i in $RESULT; do
                        TOTAL=`$EXPR $TOTAL + $i`
                        COUNT=`$EXPR $COUNT + 1`
                done
                UP=$RESULT
                daytemp=`$EXPR $UP / 100`
                DAYS=`$EXPR $daytemp / 86400`
                OUTMSG="Sysuptime is $UP $DAYS days | timeticks=$UP;$WARN;$CRIT"
                if [ "$UP" -le  "$CRIT" ]; then
                        STATUS=CRITICAL
                elif [ "$UP" -le  "$WARN" ] && [ "$UP" -gt "$CRIT" ]; then
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
checkuptime
output


