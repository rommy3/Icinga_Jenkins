#!/bin/bash

SNMPWALK=/usr/bin/snmpwalk
ECHO=/bin/echo
CUT=/bin/cut
EXPR=/usr/bin/expr
GREP=/bin/grep
BC=/usr/bin/bc
#CPU_OID="1.3.6.1.4.1.9.9.109.1.1.1.1.5"


TMOUT=5
RETRYCNT=1

usage(){
        $ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
        $ECHO "Usage: test.sh -h <host> -s <community string> -C <check type> -w <warning in %> -c <critical in %>"
	$ECHO "Check types should be one of the following"
	$ECHO "cpu"
	$ECHO "mem"
	$ECHO "connections"
	$ECHO "In the mentioned order first one is to check CPU usage, next is mem usage, Last is Current Connections and last is bandwidth usage of cluster member"
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
	if [ ! -n "$check" ]; then
		ERROR="Check type not specified"
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

#main function
main(){

case $check in
	cpu)
		oid="1.3.6.1.4.1.8741.1.3.1.3.0"
		RESULT=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v 1 -c $COMSTR $HOST $oid 2>&1 | $CUT -d' ' -f4`
		re='^[0-9]+$'
	        if [[ "$RESULT" != ""  &&  "$RESULT" =~ $re ]]; then
		#RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
		OUTMSG="CPU Utilization is $RESULT % | CPU=$RESULT;$WARN;$CRIT;0;100"
			if [[ $RESULT -ge $CRIT ]]; then
				STATUS=CRITICAL
			elif [[ $RESULT -ge $WARN ]]; then
				STATUS=WARNING
			else
				STATUS=OK
			fi
		else
			STATUS=UNKNOWN
			OUTMSG="Timeout: No Response from $HOST"
		fi
		;;
	mem)
		oid="1.3.6.1.4.1.8741.1.3.1.4.0"
		re='^[0-9]+$'
		RESULT=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v 1 -c $COMSTR $HOST $oid 2>&1 | $CUT -d' ' -f4`
                if [[ "$RESULT" != "" &&  "$RESULT" =~ $re ]]; then
                #RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
                OUTMSG="Memory Utilization is $RESULT % | MEM=$RESULT;$WARN;$CRIT;0;100"
                        if [[ $RESULT -ge $CRIT ]]; then
                                STATUS=CRITICAL
                        elif [[ $RESULT -ge $WARN ]]; then
                                STATUS=WARNING
                        else
                                STATUS=OK
                        fi
                else
                        STATUS=UNKNOWN
                        OUTMSG="Timeout: No Response from $HOST"
                fi
                ;;
	connections)
		oid="1.3.6.1.4.1.8741.1.3.1.2.0"
		re='^[0-9]+$'
		RESULT=`$SNMPWALK -r $RETRYCNT -t $TMOUT -v 1 -c $COMSTR $HOST $oid 2>&1 | $CUT -d' ' -f4`
                if [[ "$RESULT" != "" &&  "$RESULT" =~ $re ]]; then
                #RESULT=`$ECHO $RESULT | $CUT -d' ' -f4`
                OUTMSG="Number of Current Connections on the device is $RESULT | sessions=$RESULT;$WARN;$CRIT;0;100"
                        if [[ $RESULT -ge $CRIT ]]; then
                                STATUS=CRITICAL
                        elif [[ $RESULT -ge $WARN ]]; then
                                STATUS=WARNING
                        else
                                STATUS=OK
                        fi
                else
                        STATUS=UNKNOWN
                        OUTMSG="Timeout: No Response from $HOST"
                fi
                ;;
	*)
		STATUS=UNKNOWN
		OUTMSG="Incorrect check type selected. Please check usage for correct check types"
		break
		;;
esac
}

while getopts h:s:C:w:c:q:z: option
        do case "$option" in
                h) HOST=$OPTARG;;
                s) COMSTR=$OPTARG;;
                w) WARN=$OPTARG;;
				C) check=$OPTARG;;
                c) CRIT=$OPTARG;;
                q) TMOUT=$OPTARG;;
                z) RETRYCNT=$OPTARG;;

                *) ERROR="Illegal option used"
                        usage;;
        esac
done

checkpaths
checkinputs
main
output


