#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Parameters passed from the Python orchestrator
MODE=$1
LEVEL=$2
ROLLBACK_FILE_ARG=$3

SSH_CONFIG_FILE="/etc/ssh/sshd_config"
RESTART_NEEDED=0

# A standardized helper function to send single-line, compressed JSON output
write_result() {
    PARAM=$1
    STATUS=$2
    DETAILS=$3
    jq -c -n --arg p "$PARAM" --arg s "$STATUS" --arg d "$DETAILS" '{parameter:$p, status:$s, details:$d}'
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
        RESTART_NEEDED=1; return 0
    else
        write_result "SSH: $KEY" "Failure" "Could not verify the setting in $SSH_CONFIG_FILE."
        return 1
    fi
}

# --- Main Execution Logic ---
if [[ "$MODE" == "Harden" ]]; then
    rollback_data="[]"
    current_value=$(sudo sshd -T | grep -i permitrootlogin | awk '{print $2}' || echo "prohibit-password")
    rollback_data=$(echo "$rollback_data" | jq -c --arg cv "$current_value" '. += [{"parameter": "PermitRootLogin", "value": $cv}]')
    set_ssh_config "PermitRootLogin" "no"

    current_value=$(sudo sshd -T | grep -i permitemptypasswords | awk '{print $2}' || echo "no")
    rollback_data=$(echo "$rollback_data" | jq -c --arg cv "$current_value" '. += [{"parameter": "PermitEmptyPasswords", "value": $cv}]')
    set_ssh_config "PermitEmptyPasswords" "no"

    timestamp=$(date +"%Y%m%d-%H%M%S")
    new_rollback_file="rollback/${timestamp}_AccessControl.json"
    echo "$rollback_data" > "$new_rollback_file"
    write_result "Rollback" "Info" "Transactional rollback file created at $new_rollback_file"

elif [[ "$MODE" == "Audit" ]]; then
    value=$(sudo sshd -T | grep -i permitrootlogin | awk '{print $2}' || echo "prohibit-password")
    if [[ "$value" == "no" ]]; then
        write_result "SSH: PermitRootLogin" "Compliant" "Currently set to 'no'."
    else
        write_result "SSH: PermitRootLogin" "Not Compliant" "Currently set to '$value' (or default), should be 'no'."
    fi
    
    value=$(sudo sshd -T | grep -i permitemptypasswords | awk '{print $2}' || echo "no")
    if [[ "$value" == "no" ]]; then
        write_result "SSH: PermitEmptyPasswords" "Compliant" "Currently set to 'no'."
    else
        write_result "SSH: PermitEmptyPasswords" "Not Compliant" "Currently set to '$value', should be 'no'."
    fi

elif [[ "$MODE" == "Rollback" ]]; then
    if [ ! -f "$ROLLBACK_FILE_ARG" ]; then
        write_result "Rollback" "Failure" "Rollback file not found: $ROLLBACK_FILE_ARG"; exit 1
    fi

    jq -c '.[]' "$ROLLBACK_FILE_ARG" | while IFS= read -r item; do
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

if [ "$RESTART_NEEDED" -eq 1 ]; then
    if sudo systemctl restart sshd; then
        write_result "SSH Service" "Info" "sshd service restarted successfully."
    else
        write_result "SSH Service" "Warning" "Failed to restart sshd. Please restart manually."
    fi
fi

