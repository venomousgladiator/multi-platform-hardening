#!/bin/bash

# Parameters passed from the Python orchestrator
MODE=$1
LEVEL=$2
ROLLBACK_FILE_ARG=$3 # The filename for rollback operations

SSH_CONFIG_FILE="/etc/ssh/sshd_config"
RESTART_NEEDED=0

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

# A robust helper function to safely modify a setting in the SSH config file
set_ssh_config() {
    local KEY=$1
    local VALUE=$2
    
    if sudo grep -qE "^\s*#?\s*${KEY}\s+" "$SSH_CONFIG_FILE"; then
        sudo sed -i -E "s/^\s*#?\s*${KEY}\s+.*/${KEY} ${VALUE}/" "$SSH_CONFIG_FILE"
    else
        echo "${KEY} ${VALUE}" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
    fi

    if sudo grep -qE "^\s*${KEY}\s+${VALUE}" "$SSH_CONFIG_FILE"; then
        write_result "SSH: $KEY" "Success" "Set to '$VALUE'."
        RESTART_NEEDED=1
        return 0
    else
        write_result "SSH: $KEY" "Failure" "Could not verify the setting in $SSH_CONFIG_FILE."
        return 1
    fi
}

# --- Main Execution Logic ---

if [[ "$MODE" == "Harden" ]]; then
    # --- Create a single, transactional rollback file for this module run ---
    rollback_data="[]" # Start with an empty JSON array

    # --- Harden PermitRootLogin ---
    current_value=$(sudo sshd -T | grep -i permitrootlogin | awk '{print $2}')
    rollback_data=$(echo "$rollback_data" | jq --arg cv "$current_value" '. += [{"parameter": "PermitRootLogin", "value": $cv}]')
    set_ssh_config "PermitRootLogin" "no"

    # --- Harden PermitEmptyPasswords ---
    current_value=$(sudo sshd -T | grep -i permitemptypasswords | awk '{print $2}')
    rollback_data=$(echo "$rollback_data" | jq --arg cv "$current_value" '. += [{"parameter": "PermitEmptyPasswords", "value": $cv}]')
    set_ssh_config "PermitEmptyPasswords" "no"

    # --- Write the final rollback file ---
    timestamp=$(date +"%Y%m%d-%H%M%S")
    new_rollback_file="rollback/${timestamp}_AccessControl.json"
    echo "$rollback_data" | jq -c '.' > "$new_rollback_file"
    write_result "Rollback" "Info" "Transactional rollback file created at $new_rollback_file"

elif [[ "$MODE" == "Audit" ]]; then
    # --- Audit PermitRootLogin ---
    value=$(sudo sshd -T | grep -i permitrootlogin | awk '{print $2}')
    if [[ "$value" == "no" ]]; then
        write_result "SSH: PermitRootLogin" "Compliant" "Currently set to 'no'."
    else
        write_result "SSH: PermitRootLogin" "Not Compliant" "Currently set to '$value', should be 'no'."
    fi
    
    # --- Audit PermitEmptyPasswords ---
    value=$(sudo sshd -T | grep -i permitemptypasswords | awk '{print $2}')
    if [[ "$value" == "no" ]]; then
        write_result "SSH: PermitEmptyPasswords" "Compliant" "Currently set to 'no'."
    else
        write_result "SSH: PermitEmptyPasswords" "Not Compliant" "Currently set to '$value', should be 'no'."
    fi

elif [[ "$MODE" == "Rollback" ]]; then
    rollback_path="rollback/$ROLLBACK_FILE_ARG"
    if [ ! -f "$rollback_path" ]; then
        write_result "Rollback" "Failure" "Rollback file not found: $rollback_path"
        exit 1
    fi

    # Read the entire JSON array from the file and loop through it
    jq -c '.[]' "$rollback_path" | while IFS= read -r item; do
        param=$(echo "$item" | jq -r '.parameter')
        value=$(echo "$item" | jq -r '.value')

        if [[ "$param" == "PermitRootLogin" ]]; then
            sudo sed -i -E "s/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin $value/" "$SSH_CONFIG_FILE"
            write_result "Rollback: PermitRootLogin" "Success" "Reverted to '$value'."
            RESTART_NEEDED=1
        elif [[ "$param" == "PermitEmptyPasswords" ]]; then
            sudo sed -i -E "s/^\s*#?\s*PermitEmptyPasswords\s+.*/PermitEmptyPasswords $value/" "$SSH_CONFIG_FILE"
            write_result "Rollback: PermitEmptyPasswords" "Success" "Reverted to '$value'."
            RESTART_NEEDED=1
        fi
    done
fi

# After all changes, check if a restart is needed
if [ "$RESTART_NEEDED" -eq 1 ]; then
    if sudo systemctl restart sshd; then
        write_result "SSH Service" "Info" "sshd service restarted successfully to apply changes."
    else
        write_result "SSH Service" "Warning" "Failed to restart sshd service. Please restart it manually."
    fi
fi
