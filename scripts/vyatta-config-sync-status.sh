#!/bin/bash 

HOST=$1
MAP=$(cli-shell-api returnEffectiveValue system config-sync remote-router $HOST sync-map)

echo -e "remote-router:\t$HOST"
echo -e "\t  sync-map:\t$MAP"


EXIST=$(cli-shell-api existsEffective system config-sync remote-router $HOST)
if [ $? -ne 0 ]; then
  echo -e "\t    status:\t\tconfig-sync for $HOST is not configured"
  exit 1
fi

FILE="/var/lib/vyatta-config-sync/$HOST"
if [ ! -f $FILE ]; then
   echo -e "\t    status:\tnever synced"
   exit 1
fi

STATE=`cat $FILE`
STATUS=($STATE)
TIMESTAMP=`date -d @${STATUS[1]}`
echo -e "\t last sync:\t${STATUS[0]} (at ${TIMESTAMP})"