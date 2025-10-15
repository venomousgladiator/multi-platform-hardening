#!/bin/bash

MODE=$1
LEVEL=${2:-"L1"}
ROLLBACK_FILE=$3

# Function to output JSON-formatted results
output_result() {
    printf '{"parameter":"%s","status":"%s","details":"%s"}\n' "$1" "$2" "$3"
}

# Store original values for rollback
declare -A rollback_data

# Check and set file permissions
check_file_permissions() {
    local file=$1
    local expected_perms=$2
    local current_perms=$(stat -c "%a" "$file" 2>/dev/null)
    
    if [ "$current_perms" = "$expected_perms" ]; then
        output_result "$file permissions" "Compliant" "Permissions set correctly to $expected_perms"
    else
        output_result "$file permissions" "Not Compliant" "Current: $current_perms, Expected: $expected_perms"
        if [ "$MODE" = "Harden" ]; then
            rollback_data["$file"]=$current_perms
            chmod $expected_perms "$file"
            output_result "$file permissions" "Success" "Updated permissions to $expected_perms"
        fi
    fi
}

# Main execution
if [ "$MODE" = "Audit" ] || [ "$MODE" = "Harden" ]; then
    # Check critical file permissions
    check_file_permissions "/etc/passwd" "644"
    check_file_permissions "/etc/shadow" "600"
    check_file_permissions "/etc/group" "644"
    check_file_permissions "/etc/gshadow" "600"
    
    # Save rollback data if changes were made
    if [ "$MODE" = "Harden" ] && [ ${#rollback_data[@]} -gt 0 ]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        rollback_file="./rollback/${timestamp}_AccessControl.json"
        printf "%s\n" "$(declare -p rollback_data)" > "$rollback_file"
    fi
fi

