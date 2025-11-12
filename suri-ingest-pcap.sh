#!/usr/bin/env bash

PCAPFILE=$1
LOG_LOCATION='/tmp/suricata/'

if [ -z $PCAPFILE ] || [ ! -f $PCAPFILE ]; then
    echo "File ${PCAPFILE} doesn't seem to be there - please supply a pcap file."
    exit 1
fi

if [ ! -d "$LOG_LOCATION" ]; then
    echo "Attempting to create Suricata log directory..."
    mkdir "$LOG_LOCATION"
else
    echo "Log location exists, removing previous content..."
    rm -rf "$LOG_LOCATION/"*
fi

# Run Suricata in offline mode
suricata -c /etc/suricata/suricata.yaml -k none -r $1 --runmode=autofp -l /tmp/suricata/

# Print alerts from eve.json
echo -e "\nAlerts:\n"
grep '"event_type":"alert"' /tmp/suricata/eve.json | jq '"\(.timestamp) | \(.alert.gid):\(.alert.signature_id):\(.alert.rev) | \(.alert.signature) | \(.alert.category) | \(.src_ip):\(.src_port) -> \(.dest_ip):\(.dest_port)"'

# If you have Evebox installed, you can comment out this line to launch it in oneshot mode 
# evebox oneshot "$LOG_LOCATION/eve.json"
