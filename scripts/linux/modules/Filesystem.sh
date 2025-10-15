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

# Function to output results in JSON format
output_json() {
    local parameter="$1"
    local status="$2"
    local details="$3"
    echo "{\"parameter\": \"$parameter\", \"status\": \"$status\", \"details\": \"$details\"}"
}

# Check if a kernel module is loaded or available
check_kernel_module() {
    local module="$1"
    if lsmod | grep -q "$module"; then
        output_json "Kernel Module: $module" "Not Compliant" "Module is currently loaded"
        return 1
    elif modprobe -n -v "$module" 2>&1 | grep -q "install /bin/true"; then
        output_json "Kernel Module: $module" "Compliant" "Module is properly disabled"
        return 0
    else
        output_json "Kernel Module: $module" "Not Compliant" "Module is available to be loaded"
        return 1
    fi
}

# Check mount point options
check_mount_option() {
    local mount_point="$1"
    local option="$2"
    if mount | grep " $mount_point " | grep -q "$option"; then
        output_json "Mount Option: $option on $mount_point" "Compliant" "Option is set"
        return 0
    else
        output_json "Mount Option: $option on $mount_point" "Not Compliant" "Option is not set"
        return 1
    fi
}

# Function to handle hardening actions
harden_filesystem() {
    # Create backup of current timestamp for rollback
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_file="../../rollback/${timestamp}_Filesystem.json"
    echo "{" > "$rollback_file"
    echo "  \"timestamp\": \"$timestamp\"," >> "$rollback_file"
    echo "  \"backups\": {" >> "$rollback_file"

    # 1. Disable kernel modules
    local modules=("cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs" "udf" "usb-storage")
    
    for module in "${modules[@]}"; do
        if ! [ -f "/etc/modprobe.d/${module}.conf" ]; then
            # Backup if file exists
            if [ -f "/etc/modprobe.d/${module}.conf" ]; then
                cp "/etc/modprobe.d/${module}.conf" "/etc/modprobe.d/${module}.conf.${timestamp}"
                echo "    \"/etc/modprobe.d/${module}.conf\": \"/etc/modprobe.d/${module}.conf.${timestamp}\"," >> "$rollback_file"
            fi
            
            # Create blacklist file
            echo "install ${module} /bin/true" > "/etc/modprobe.d/${module}.conf"
            echo "blacklist ${module}" >> "/etc/modprobe.d/${module}.conf"
            
            output_json "Kernel Module: $module" "Success" "Module blacklisted successfully"
        fi
    done

    # 2. Configure mount points
    if [ -f "/etc/fstab" ]; then
        cp "/etc/fstab" "/etc/fstab.${timestamp}"
        echo "    \"/etc/fstab\": \"/etc/fstab.${timestamp}\"" >> "$rollback_file"
    fi
    
    # Close JSON structure
    echo "  }" >> "$rollback_file"
    echo "}" >> "$rollback_file"

    # Update mount options in fstab
    sed -i.bak '/[[:space:]]\/tmp[[:space:]]/s/defaults/defaults,nodev,nosuid,noexec/' /etc/fstab
    sed -i '/[[:space:]]\/dev\/shm[[:space:]]/s/defaults/defaults,nodev,nosuid,noexec/' /etc/fstab
    sed -i '/[[:space:]]\/home[[:space:]]/s/defaults/defaults,nodev/' /etc/fstab
    
    output_json "Filesystem Configuration" "Success" "Mount options updated in fstab"
}

# Function to perform rollback
rollback() {
    local rollback_file="$1"
    if [ ! -f "$rollback_file" ]; then
        output_json "Rollback" "Failure" "Rollback file not found"
        exit 1
    fi

    # Read and parse rollback file
    while IFS= read -r line; do
        if [[ $line =~ \"([^\"]+)\"\:\ \"([^\"]+)\" ]]; then
            source_file="${BASH_REMATCH[1]}"
            backup_file="${BASH_REMATCH[2]}"
            if [ -f "$backup_file" ]; then
                cp "$backup_file" "$source_file"
                rm "$backup_file"
                output_json "Rollback" "Success" "Restored $source_file from backup"
            fi
        fi
    done < "$rollback_file"
}

# Main execution
case "$1" in
    "Audit")
        # Check kernel modules
        for module in cramfs freevxfs jffs2 hfs hfsplus squashfs udf usb-storage; do
            check_kernel_module "$module"
        done

        # Check mount points
        check_mount_option "/tmp" "nodev"
        check_mount_option "/tmp" "nosuid"
        check_mount_option "/tmp" "noexec"
        check_mount_option "/dev/shm" "nodev"
        check_mount_option "/dev/shm" "nosuid"
        check_mount_option "/dev/shm" "noexec"
        check_mount_option "/home" "nodev"
        ;;
        
    "Harden")
        harden_filesystem
        ;;
        
    "Rollback")
        if [ -z "$2" ]; then
            output_json "Rollback" "Failure" "No rollback file specified"
            exit 1
        fi
        rollback "$2"
        ;;
        
    *)
        output_json "Mode Selection" "Failure" "Invalid mode specified: $1"
        exit 1
        ;;
esac

exit 0
