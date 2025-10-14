#!/bin/bash
# scripts/linux/Check-CramfsModule.sh

PARAM="cramfs kernel module"
STATUS="Error"
DETAILS="Could not determine module status."

# Check if the module is disabled in modprobe configs
if modprobe -n -v cramfs | grep -q "install /bin/true"; then
    STATUS="Compliant"
    DETAILS="cramfs is disabled via modprobe configuration."
# Check if the module is currently loaded
elif ! lsmod | grep -q "cramfs"; then
    STATUS="Compliant"
    DETAILS="cramfs is not currently loaded."
else
    STATUS="Failure"
    DETAILS="cramfs module is loaded."
fi

# Use jq to build the JSON output
jq -n \
  --arg param "$PARAM" \
  --arg status "$STATUS" \
  --arg details "$DETAILS" \
  '{parameter: $param, status: $status, details: $details}'