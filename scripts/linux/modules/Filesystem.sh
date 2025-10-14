#!/bin/bash

# The level is passed as the first argument from the cli.py orchestrator
LEVEL=$1

# A standardized helper function to send JSON output back to the Python CLI
write_result() {
    PARAM=$1
    STATUS=$2
    DETAILS=$3
    jq -n \
      --arg p "$PARAM" \
      --arg s "$STATUS" \
      --arg d "$DETAILS" \
      '{parameter:$p, status:$s, details:$d}'
}

# --- Module: Disable Unused Filesystem Kernel Modules ---
apply_kernel_module_hardening() {
    write_result "Module: Kernel Modules" "Info" "Applying L1 kernel module policies..."

    # List of modules to disable for L1
    modules_to_disable=("cramfs" "hfs" "hfsplus" "udf" "usb-storage")

    for module in "${modules_to_disable[@]}"; do
        # Create a config file to prevent the module from being loaded
        if echo "install $module /bin/true" | sudo tee "/etc/modprobe.d/hardening-$module.conf" > /dev/null; then
            # Attempt to unload the module if it's currently loaded
            sudo rmmod "$module" 2>/dev/null
            write_result "Disable $module module" "Success" "Module has been disabled via modprobe config."
        else
            write_result "Disable $module module" "Failure" "Could not write to /etc/modprobe.d/. Requires sudo."
        fi
    done
}


# --- Main script execution logic ---
# This corrected structure is much cleaner and avoids syntax errors.
if [[ "$LEVEL" == "L1" || "$LEVEL" == "L2" || "$LEVEL" == "L3" ]]; then
    apply_kernel_module_hardening
fi

if [[ "$LEVEL" == "L2" || "$LEVEL" == "L3" ]]; then
    # Add any Filesystem settings that are specific to L2 here in the future
    write_result "Filesystem" "Info" "No L2-specific policies are implemented in this module yet."
fi

if [[ "$LEVEL" == "L3" ]]; then
    # Add any Filesystem settings that are specific to L3 here in the future
    write_result "Filesystem" "Info" "No L3-specific policies are implemented in this module yet."
fi
