#!/bin/bash
# scripts/linux/Disable-CramfsModule.sh

PARAM="cramfs kernel module"
CONFIG_FILE="/etc/modprobe.d/hardening-cramfs.conf"

# This requires sudo privileges to write to /etc/modprobe.d/
if ! echo "install cramfs /bin/true" | sudo tee "$CONFIG_FILE"; then
    DETAILS="Failed to write config file. This script must be run with sudo privileges."
    STATUS="Error"
else
    # Unload the module if it's currently loaded
    sudo rmmod cramfs 2>/dev/null
    DETAILS="cramfs module has been disabled. A reboot may be required for full effect."
    STATUS="Success"
fi

# Use jq to build the JSON output
jq -n \
  --arg param "$PARAM" \
  --arg status "$STATUS" \
  --arg details "$DETAILS" \
  '{parameter: $param, status: $status, details: $details}'