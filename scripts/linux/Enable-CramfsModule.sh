#!/bin/bash
# scripts/linux/Enable-CramfsModule.sh

PARAM="Rollback cramfs kernel module"
CONFIG_FILE="/etc/modprobe.d/hardening-cramfs.conf"
ROLLBACK_VALUE=$1 # The original state ('loaded' or 'disabled') is passed as an argument

# Only remove the hardening file if the original state was not disabled
if [ "$ROLLBACK_VALUE" == "loaded" ]; then
    if sudo rm "$CONFIG_FILE"; then
        DETAILS="Rollback successful. The hardening rule has been removed. A reboot may be required."
        STATUS="Success"
    else
        DETAILS="Failed to remove config file. This script must be run with sudo privileges."
        STATUS="Error"
    fi
else
    # If the original state was already disabled, there's nothing to do.
    DETAILS="Rollback not needed. The module was already disabled before hardening was applied."
    STATUS="Info"
fi

jq -n \
  --arg param "$PARAM" \
  --arg status "$STATUS" \
  --arg details "$DETAILS" \
  '{parameter: $param, status: $status, details: $details}'