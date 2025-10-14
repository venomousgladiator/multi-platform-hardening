#!/bin/bash

# The level is passed as the first argument from the cli.py orchestrator
LEVEL=$1
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
RESTART_NEEDED=0

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

# A robust helper function to modify a setting in the SSH config file
# It uncomments the line if it exists, or adds it if it doesn't.
set_ssh_config() {
    KEY=$1
    VALUE=$2
    
    # Check if the key already exists (commented or not)
    if sudo grep -qE "^\s*#?\s*${KEY}\s+" "$SSH_CONFIG_FILE"; then
        # If it exists, use sed to uncomment and set the correct value
        sudo sed -i -E "s/^\s*#?\s*${KEY}\s+.*/${KEY} ${VALUE}/" "$SSH_CONFIG_FILE"
    else
        # If the key doesn't exist at all, add it to the end of the file
        echo "${KEY} ${VALUE}" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
    fi

    # Verify the change
    if sudo grep -qE "^\s*${KEY}\s+${VALUE}" "$SSH_CONFIG_FILE"; then
        write_result "SSH: $KEY" "Success" "Set to '$VALUE'."
        RESTART_NEEDED=1
    else
        write_result "SSH: $KEY" "Failure" "Could not verify the setting in $SSH_CONFIG_FILE."
    fi
}


# --- Module: SSH Server Hardening ---
apply_ssh_hardening() {
    write_result "Module: SSH Server Hardening" "Info" "Applying L1 SSH access control policies..."

    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        write_result "SSH Hardening" "Failure" "SSH config file not found at $SSH_CONFIG_FILE."
        return
    fi

    # Policy: 6.a.xx - Ensure sshd PermitRootLogin is set to 'no'
    set_ssh_config "PermitRootLogin" "no"

    # Policy: 6.a.xix - Ensure sshd PermitEmptyPasswords is set to 'no'
    set_ssh_config "PermitEmptyPasswords" "no"
    
    # Policy: 6.a.ix - Ensure sshd GSSAPIAuthentication is set to 'no'
    set_ssh_config "GSSAPIAuthentication" "no"
    
    # Policy: 6.a.x - Ensure sshd HostbasedAuthentication is set to 'no'
    set_ssh_config "HostbasedAuthentication" "no"

    # Policy: 6.a.xxii - Ensure sshd UsePAM is enabled
    set_ssh_config "UsePAM" "yes"
}

# --- Main script execution logic ---
if [[ "$LEVEL" == "L1" || "$LEVEL" == "L2" || "$LEVEL" == "L3" ]]; then
    apply_ssh_hardening
fi

# After all changes, check if a restart is needed
if [ "$RESTART_NEEDED" -eq 1 ]; then
    write_result "SSH Service" "Info" "Attempting to restart SSH service to apply changes..."
    if sudo systemctl restart sshd; then
        write_result "SSH Service" "Success" "sshd service restarted successfully."
    else
        write_result "SSH Service" "Failure" "Failed to restart sshd service. Please restart it manually."
    fi
fi