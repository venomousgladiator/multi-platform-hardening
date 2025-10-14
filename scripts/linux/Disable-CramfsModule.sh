#!/bin/bash
# scripts/linux/Disable-CramfsModule.sh

PARAM="cramfs kernel module"
CONFIG_FILE="/etc/modprobe.d/hardening-cramfs.conf"
CURRENT_STATE="loaded" # Assume it's loaded by default

# --- 1. Check the current state ---
if modprobe -n -v cramfs | grep -q "install /bin/true" || ! lsmod | grep -q "cramfs"; then
    CURRENT_STATE="disabled"
fi

# --- 2. Save the current state to a rollback file ---
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
ROLLBACK_FILE="rollback/CramfsModule_$TIMESTAMP.json"
jq -n \
  --arg parameter "$PARAM" \
  --arg value "$CURRENT_STATE" \
  '{"parameter": $parameter, "value": $value}' > "$ROLLBACK_FILE"


# --- 3. Apply the new setting ---
if ! echo "install cramfs /bin/true" | sudo tee "$CONFIG_FILE" > /dev/null; then
    DETAILS="Failed to write config file. This script must be run with sudo privileges."
    STATUS="Error"
else
    sudo rmmod cramfs 2>/dev/null
    DETAILS="cramfs module has been disabled. Previous state of '$CURRENT_STATE' saved to $ROLLBACK_FILE."
    STATUS="Success"
fi

# Use jq to build the JSON output for the UI
jq -n \
  --arg param "$PARAM" \
  --arg status "$STATUS" \
  --arg details "$DETAILS" \
  '{parameter: $param, status: $status, details: $details}'