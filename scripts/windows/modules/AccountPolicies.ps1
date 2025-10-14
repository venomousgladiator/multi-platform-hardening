[CmdletBinding()]
param (
    # This parameter is passed by the cli.py orchestrator
    [ValidateSet("L1", "L2", "L3")]
    [string]$Level = "L1"
)

# A standardized helper function to send JSON output back to the Python CLI
function Write-Result {
    param($Parameter, $Status, $Details)
    $output = [PSCustomObject]@{
        parameter = $Parameter
        status    = $Status
        details   = $Details
    }
    # This converts the object to a JSON string and prints it to the console
    $output | ConvertTo-Json -Compress -WarningAction SilentlyContinue
}

# --- Module: Password Policy ---
function Set-PasswordPolicies {
    Write-Result "Module: Password Policy" "Info" "Applying all L1 password policies..."
    
    try {
        net accounts /uniquepw:24
        Write-Result "Enforce password history" "Success" "Set to remember last 24 passwords."
    } catch { Write-Result "Enforce password history" "Failure" $_.Exception.Message }

    try {
        net accounts /maxpwage:90
        Write-Result "Maximum password age" "Success" "Set to 90 days."
    } catch { Write-Result "Maximum password age" "Failure" $_.Exception.Message }
    
    try {
        net accounts /minpwage:1
        Write-Result "Minimum password age" "Success" "Set to 1 day."
    } catch { Write-Result "Minimum password age" "Failure" $_.Exception.Message }

    try {
        net accounts /minpwlen:12
        Write-Result "Minimum password length" "Success" "Set to 12 characters."
    } catch { Write-Result "Minimum password length" "Failure" $_.Exception.Message }
}

# --- Module: Account Lockout Policy ---
function Set-AccountLockoutPolicies {
    Write-Result "Module: Account Lockout Policy" "Info" "Applying all L1 lockout policies..."

    try {
        net accounts /lockoutduration:15
        Write-Result "Account lockout duration" "Success" "Set to 15 minutes."
    } catch { Write-Result "Account lockout duration" "Failure" $_.Exception.Message }

    try {
        net accounts /lockoutthreshold:5
        Write-Result "Account lockout threshold" "Success" "Set to 5 invalid attempts."
    } catch { Write-Result "Account lockout threshold" "Failure" $_.Exception.Message }
}


# --- Main script execution logic ---
# This script runs different functions based on the --level parameter passed from the CLI.
if ($Level -ge "L1") {
    Set-PasswordPolicies
    Set-AccountLockoutPolicies
}

if ($Level -ge "L2") {
    # Add any Account Policy settings that are specific to L2 here
    # For now, there are none, but this shows how to extend it.
    Write-Result "Account Policies" "Info" "No L2-specific policies in this module."
}

if ($Level -ge "L3") {
    # Add any Account Policy settings that are specific to L3 here
    Write-Result "Account Policies" "Info" "No L3-specific policies in this module."
}