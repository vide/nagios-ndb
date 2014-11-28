#!/bin/bash

NDB_MGM=$(which ndb_mgm)
NDB_MGM=/opt/mysql/server-5.6/bin/ndb_mgm
function printHelp() {

cat >&2 <<EOF
$@
Usage: $(basename $0) 
        --warning|-w      Used memory warning threshhold
        --critical|-c     used memory critical threshold
        --node-id|-n      Specify which node you want to monitor
EOF
    
exit 3

}

# main starts here
while [ $# -gt 0 ]  
do
    case "$1" in
        --warning|-w)   WARN="$2";  shift 2;;
        --critical|-c)  CRIT="$2";  shift 2;;
        --node-id|-n)   NODE="$2";  shift 2;;
        *)              printHelp "Missing parameter" ;;
    esac        
done

test -z ${NDB_MGM} && { echo "Cannot find the ndb_mgm executable. Aborting."; exit 3; }
test -x ${NDB_MGM} || { echo "Cannot execute ndb_mgm. Aborting."; exit 3; }

if [ -z "${WARN}" ];
then
    printHelp "Please specify a warning threshold"
fi

if [ -z "${CRIT}" ];
then
    printHelp "Please specify a critical threshold"
fi

if [ -z "${NODE}" ];
then
    printHelp "Please specify a node ID"
fi

${NDB_MGM} -e "${NODE} status"|grep -i "not connected" > /dev/null
if [ $? -eq 0 ]; then
        # data node offline
        echo "Data: CRITICAL node: ${NODE} is OFFLINE"
        exit 2
fi

${NDB_MGM} -e "${NODE} status"|grep -i "starting" > /dev/null
if [ $? -eq 0 ]; then        
 	# data node starting
        echo "Data: WARNING node: ${NODE} is STARTING"
        exit 2
fi

DATA=$(${NDB_MGM} -e "${NODE} report memory"|grep "Data usage is"|awk '{print $6}'|awk -F "%" "{ if (\$1 > ${CRIT}) {                 
        exit 2 
 } else if (\$1 > ${WARN}) {        
        exit 1 
    }
 } END { print \$1 }")

RET=$?


# checking index usage
# IF ... critical .. ELSE IF .. warning
IDX=$(${NDB_MGM} -e "${NODE} report memory"|grep "Index usage is"|awk '{print $6}'|awk -F "%" "{ if (\$1 > ${CRIT}) {                     
        exit 8 
} else if (\$1 > ${WARN}) {        
        exit 4 
   }
} END { print \$1 }")

((RET+=$?))

case ${RET} in
    0)
        # everything OK
        echo "Data: OK (${DATA}%) Index: OK (${IDX}%)"
        exit 0
        ;;
    1)
        # data usage warning
        echo "Data: WARNING (${DATA}%) Index: OK (${IDX}%)"
        exit 1
        ;;
    2)
        # data usage critical
        echo "Data: CRITICAL (${DATA}%) Index: OK (${IDX}%)"
        exit 2
        ;;
    4)  
        # index usage warning
        echo "Data: OK (${DATA}%) Index: WARNING (${IDX}%)"
        exit 1
        ;;
    5)
        # data usage warning + index usage warning
        echo "Data: WARNING (${DATA}%) Index: WARNING (${IDX}%)"
        exit 1
        ;;
    6)
        # data usage critical + index usage warning
        echo "Data: CRITICAL (${DATA}%) Index: WARNING (${IDX}%)"
        exit 2
        ;;
    8)  
        # index usage critical
        echo "Data: OK (${DATA}%) Index: CRITICA (${IDX}%)"
        exit 2
        ;;
    9)
        # data usage warning + index usage critical
        echo "Data: WARNING (${DATA}%) Index: CRITICAL (${IDX}%)"
        exit 2
        ;;
    10)
        # data usage critical + index usage critical
        echo "Data: CRITICAL (${DATA}%) Index: CRITICAL (${IDX}%)"
        exit 2
        ;;
    *)  
        # unexpected condition
        echo "Unknown error"
        exit 3
        ;;
esac
