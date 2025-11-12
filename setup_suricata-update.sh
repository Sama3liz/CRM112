#!/usr/bin/env bash

# Author: Josh Stroschein
# Ref: https://suricata-

if (($EUID != 0)); then
    echo -e "[!] Please run this script as root or with \"sudo\"\n"
    exit 1
fi

SURICATA_DIR=/etc/suricata/
SURICATA_RULES=/var/lib/suricata/rules/
SURICATA_UPDATE=/var/lib/suricata/update/
SESSION_USER=$(logname)

# Create group for suricata
groupadd suricata

# Prepare directories
for DIR in "$SURICATA_DIR" "$SURICATA_RULES" "$SURICATA_UPDATE"; do
    mkdir -p "$DIR"
    chgrp -R suricata "$DIR"
done

# Setup the directories with the correct permissions for the suricata group:

chmod -R g+r "$SURICATA_DIR"
chmod -R g+rw "$SURICATA_RULES"
chmod -R g+rw "$SURICATA_UPDATE"

# Now, add user current user to the group:
usermod -a -G suricata "$SESSION_USER"

# Please note, you may need to restart your machine
echo "Setup complete. Please restart your machine before continuing."
