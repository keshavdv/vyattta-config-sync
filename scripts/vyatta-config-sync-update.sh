#!/bin/bash
HOST=$1

function update_status()
{
  local STATUS=${1}
  local FILE=/var/lib/vyatta-config-sync/$HOST
  touch $FILE
  TIME=`date +%s`
  echo "$STATUS $TIME"> $FILE
}


echo -e "remote-router:\t$HOST"

EXIST=$(cli-shell-api existsEffective system config-sync remote-router $HOST)
if [ $? -ne 0 ]; then
  echo -e "\t    status:\tconfig-sync for $HOST is not configured"
  exit 1
fi

# Test connectivity
USER=$(cli-shell-api returnEffectiveValue system config-sync remote-router $HOST username)
PORT=$(cli-shell-api returnEffectiveValue system config-sync remote-router $HOST port)
if [ $? -ne 0 ]; then
  PORT="22"
fi
PASS=$(cli-shell-api returnEffectiveValue system config-sync remote-router $HOST password)
status=$(ssh -oStrictHostKeyChecking=no -p $PORT -o BatchMode=yes -o ConnectTimeout=5 $USER@$HOST exit 2>&1 )
if [ $? -ne 0 ]; then
  echo -e "\t    status:\tcould not connect via 'ssh -p $PORT $USER@$HOST'"  
  update_status "failed"
  exit 1
fi

MAP=$(cli-shell-api returnEffectiveValue system config-sync remote-router $HOST sync-map)
echo -e "\t  sync-map:\t$MAP"


# Generate config tree to sync
RULES_LIST=$(cli-shell-api listEffectiveNodes system config-sync sync-map $MAP rule)
eval "RULES=($RULES_LIST)"

SORTED_RULES=( $(
    for el in "${RULES[@]}"
    do
        echo "$el"
    done | sort -nr) )


commands=()
excludes=()

function join { local IFS="${1}"; shift; echo "${*}"; }
function is_included()
{
  local PATH=${1}
  for i in "${excludes[@]}"
  do    
    if [[ $PATH == $i* ]]; then
      return 1
    fi
  done
  return 0
}


function generate_commands()
{
  local LOCATION=${1}
  if is_included "$LOCATION"; then
    
    # Workaround: getNodeType don't return leaf when a command can end before this (i.e.: set protocols static route x.x.x.x/x next-hop y.y.y.y <distance z> - distance isn't required)
    NODES_LIST_LEAF=$(cli-shell-api listEffectiveNodes $LOCATION)
    eval "NODES_LEAF=($NODES_LIST_LEAF)"
    if [ ${#NODES_LEAF[@]} == 0 ]; then
        NODE_TYPE="leaf"
    else
        NODE_TYPE=$(cli-shell-api getNodeType $LOCATION)
    fi
    
    if [ "$NODE_TYPE" != "leaf" ]; then

      # Check if node is multi
      if [ "$NODE_TYPE" == "multi" ]; then
        MULTI_VALUE_LIST=$(cli-shell-api returnEffectiveValues $LOCATION)
        eval "MULTI_VALUES=($MULTI_VALUE_LIST)"
        for i in "${MULTI_VALUES[@]}"
        do    
          generate_commands "$LOCATION $i"
        done        
      fi

      # If the node isn't a leaf, recurse through children to generate set commands
      NODES_LIST=$(cli-shell-api listEffectiveNodes $LOCATION)
      eval "NODES=($NODES_LIST)"

      for node in ${NODES[@]};
      do        
          generate_commands "$LOCATION $node"
      done

    else
      # If node is a leaf, then check if it has a value
      LEAF_VALUE=$(cli-shell-api returnEffectiveValue $LOCATION)
      if [ $? -ne 0 ]; then
        # Leaf doesn't have a value, it's most likely a boolean (e.g. disabled)
        commands+=("set $LOCATION")
      else
        # Leaf has a value
        commands+=("set $LOCATION '$LEAF_VALUE'")
      fi

    fi
  fi

}

# Generate list of config paths that should be excluded from sync
for i in "${SORTED_RULES[@]}";
    do
      ACTION=`cli-shell-api returnEffectiveValue system config-sync sync-map $MAP rule $i action`
      LOCATION=`cli-shell-api returnEffectiveValue system config-sync sync-map $MAP rule $i location`
      if [ "$ACTION" == "exclude" ]; then
          excludes+=("$LOCATION")
      fi
    done

# Generate set commands for things that should be synced
for i in "${SORTED_RULES[@]}";
    do
      ACTION=`cli-shell-api returnEffectiveValue system config-sync sync-map $MAP rule $i action`
      LOCATION=`cli-shell-api returnEffectiveValue system config-sync sync-map $MAP rule $i location`
      if [ "$ACTION" == "include" ]; then
        commands+=("delete $LOCATION")
          generate_commands "$LOCATION"
      fi
    done

CHANGESET=`join ";" "${commands[@]}"`
CHANGESET="$CHANGESET;commit;"

echo -e "\t changeset: ##############"
for i in "${commands[@]}"
  do
    echo -e "    $i"
  done

echo -e "\t            ##############"

# Execute on host
cat << EOF > /var/lib/vyatta-config-sync/$HOST.changeset
#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
${CHANGESET}  
EOF

# cat /var/lib/vyatta-config-sync/$HOST.changeset| ssh -oStrictHostKeyChecking=no -p $PORT -o BatchMode=yes -o ConnectTimeout=5 $USER@$HOST 2>/dev/null
cat /var/lib/vyatta-config-sync/$HOST.changeset| ssh -oStrictHostKeyChecking=no -p $PORT -o BatchMode=yes -o ConnectTimeout=5 $USER@$HOST > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "\t    status:\t error applying changeset"
  update_status "failed"
  echo -e ""
  exit 1
fi
echo -e "\t    status:\tsynced"

# Update status
update_status "success"
