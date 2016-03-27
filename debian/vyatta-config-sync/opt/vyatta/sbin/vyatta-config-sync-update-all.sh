#!/bin/bash

printf "Syncing all nodes...\n\n"
NODES_LIST=$(cli-shell-api listEffectiveNodes system config-sync remote-router)
eval "NODES=($NODES_LIST)"

for i in "${NODES[@]}"
  do    
    $vyatta_sbindir/vyatta-config-sync-update.sh $i
  done     