#!/bin/bash

# Parameters passed from the Python orchestrator
MODE=$1
LEVEL=$2
ROLLBACK_FILE_ARG=$3 # The filename for rollback operations

# A standardized helper function to send single-line, compressed JSON output
write_result() {
    PARAM=$1
    STATUS=$2
    DETAILS=$3
    # The '-c' flag is CRITICAL. It ensures the JSON is on a single line.
    jq -c -n \
      --arg p "$PARAM" \
      --arg s "$STATUS" \
      --arg d "$DETAILS" \
      '{parameter:$p, status:$s, details:$d}'
}

# --- Internal Functions for This Module ---

# Checks if prelink is currently installed
is_prelink_installed() {
    if dpkg-query -W -f='${Status}' prelink 2>/dev/null | grep -q "ok installed"; then
        echo "installed"
    else
        echo "not installed"
    fi
}

# Checks if core dumps are restricted
is_core_dump_restricted() {
    # Check /etc/security/limits.conf for '* hard core 0'
    limit_conf_ok=false
    if sudo grep -qE "^\s*\*\s+hard\s+core\s+0" /etc/security/limits.conf; then
        limit_conf_ok=true
    fi

    # Check sysctl for fs.suid_dumpable = 0
    sysctl_ok=false
    if [[ $(sudo sysctl fs.suid_dumpable | awk '{print $3}') -eq 0 ]]; then
        sysctl_ok=true
    fi

    if [[ "$limit_conf_ok" == true && "$sysctl_ok" == true ]]; then
        echo "restricted"
    else
        echo "not restricted"
    fi
}


# --- Main Execution Logic ---

if [[ "$MODE" == "Harden" ]]; then
    # --- Create a single, transactional rollback file for this module run ---
    rollback_data="[]"

    # --- Harden Prelink (Policy 2.b.iv) ---
    current_state=$(is_prelink_installed)
    rollback_data=$(echo "$rollback_data" | jq -c --arg cv "$current_state" '. += [{"parameter": "Prelink", "value": $cv}]')
    if [[ "$current_state" == "installed" ]]; then
        sudo apt-get purge -y prelink > /dev/null 2>&1
        write_result "Package: prelink" "Success" "Purged the prelink package."
    else
        write_result "Package: prelink" "Success" "Package is already not installed."
    fi

    # --- Harden Core Dumps (Policy 2.b.iii) ---
    current_state=$(is_core_dump_restricted)
    # For core dumps, rollback is complex. We'll just note the state. A true rollback would need to save original file lines.
    rollback_data=$(echo "$rollback_data" | jq -c --arg cv "$current_state" '. += [{"parameter": "CoreDumps", "value": $cv}]')
    if [[ "$current_state" != "restricted" ]]; then
        # Add rule to limits.conf
        echo "* hard core 0" | sudo tee -a /etc/security/limits.conf > /dev/null
        # Set sysctl value
        sudo sysctl -w fs.suid_dumpable=0 > /dev/null 2>&1
        # Make sysctl value persistent
        echo "fs.suid_dumpable = 0" | sudo tee -a /etc/sysctl.conf > /dev/null
        write_result "Process: Core Dumps" "Success" "Core dumps have been restricted."
    else
        write_result "Process: Core Dumps" "Success" "Core dumps are already restricted."
    fi

    # --- Write the final rollback file ---
    timestamp=$(date +"%Y%m%d-%H%M%S")
    new_rollback_file="rollback/${timestamp}_PackageManagement.json"
    echo "$rollback_data" | jq -c '.' > "$new_rollback_file"
    write_result "Rollback" "Info" "Transactional rollback file created at $new_rollback_file"

elif [[ "$MODE" == "Audit" ]]; then
    # --- Audit Prelink ---
    state=$(is_prelink_installed)
    if [[ "$state" == "not installed" ]]; then
        write_result "Package: prelink" "Compliant" "Package is not installed."
    else
        write_result "Package: prelink" "Not Compliant" "Package 'prelink' is installed and should be removed."
    fi

    # --- Audit Core Dumps ---
    state=$(is_core_dump_restricted)
    if [[ "$state" == "restricted" ]]; then
        write_result "Process: Core Dumps" "Compliant" "Core dumps are properly restricted."
    else
        write_result "Process: Core Dumps" "Not Compliant" "Core dump configuration is not fully restrictive."
    fi

elif [[ "$MODE" == "Rollback" ]]; then
    rollback_path="rollback/$ROLLBACK_FILE_ARG"
    if [ ! -f "$rollback_path" ]; then
        write_result "Rollback" "Failure" "Rollback file not found: $rollback_path"
        exit 1
    fi

    # Read the JSON array and loop through items
    jq -c '.[]' "$rollback_path" | while IFS= read -r item; do
        param=$(echo "$item" | jq -r '.parameter')
        value=$(echo "$item" | jq -r '.value')

        if [[ "$param" == "Prelink" ]] && [[ "$value" == "installed" ]]; then
            sudo apt-get install -y prelink > /dev/null 2>&1
            write_result "Rollback: prelink" "Success" "Package 'prelink' has been re-installed."
        fi

        # Note: A true rollback for CoreDumps would require removing the specific lines added,
        # which is more complex than this placeholder. This action is informational.
        if [[ "$param" == "CoreDumps" ]] && [[ "$value" != "restricted" ]]; then
             write_result "Rollback: Core Dumps" "Warning" "Manual action may be needed to revert core dump settings."
        fi
    done
fi

