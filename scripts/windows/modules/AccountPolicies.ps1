[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("Harden", "Audit", "Rollback")]
    [string]$Mode,

    [ValidateSet("L1", "L2", "L3")]
    [string]$Level = "L1",

    [string]$RollbackFile
)

# A standardized helper function to send single-line JSON output back to the Python CLI
function Write-Result {
    param($Parameter, $Status, $Details)
    $output = [PSCustomObject]@{
        parameter = $Parameter
        status    = $Status
        details   = $Details
    }
    # CRITICAL FIX: The -Compress flag creates a single, unbroken line of JSON.
    $output | ConvertTo-Json -Compress -WarningAction SilentlyContinue
}

# --- Internal Functions for This Module ---

function Get-PolicyState {
    # In a real script, this function queries the live system state.
    $PasswordHistory = (net accounts | Select-String "Password history").ToString().Split(':')[1].Trim()
    $MaxPasswordAge = (net accounts | Select-String "Maximum password age").ToString().Split(':')[1].Trim()
    # Add more queries here...

    return @{
        "PasswordHistory" = $PasswordHistory;
        "MaxPasswordAge" = $MaxPasswordAge;
    }
}


# --- Main Execution Logic ---

if ($Mode -eq "Harden") {
    $currentState = Get-PolicyState
    $rollbackData = @() # Array to hold all changes for this module run

    # --- Apply Password History Policy ---
    try {
        # Create a rollback entry before making the change
        $rollbackData += [PSCustomObject]@{ parameter="PasswordHistory"; value=$currentState.PasswordHistory }
        # Apply the hardening
        net accounts /uniquepw:24
        Write-Result "Enforce password history" "Success" "Set to remember last 24 passwords."
    } catch {
        Write-Result "Enforce password history" "Failure" $_.Exception.Message
    }
    
    # --- Apply Max Password Age Policy ---
    try {
        # Create a rollback entry before making the change
        $rollbackData += [PSCustomObject]@{ parameter="MaxPasswordAge"; value=$currentState.MaxPasswordAge }
        # Apply the hardening
        net accounts /maxpwage:90
        Write-Result "Maximum password age" "Success" "Set to 90 days."
    } catch {
        Write-Result "Maximum password age" "Failure" $_.Exception.Message
    }

    # --- Finalize: Create a single rollback file for this entire module run ---
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $newRollbackFile = "rollback\$($timestamp)_AccountPolicies.json"
    $rollbackData | ConvertTo-Json -Compress | Out-File -FilePath $newRollbackFile
    Write-Result "Rollback" "Info" "Transactional rollback file created at $newRollbackFile"

} elseif ($Mode -eq "Audit") {
    $currentState = Get-PolicyState
    
    if ([int]$currentState.PasswordHistory -ge 24) {
        Write-Result "Enforce password history" "Compliant" "Currently set to $($currentState.PasswordHistory)."
    } else {
        Write-Result "Enforce password history" "Not Compliant" "Currently set to $($currentState.PasswordHistory), should be >= 24."
    }

    if ([int]$currentState.MaxPasswordAge -le 90 -and [int]$currentState.MaxPasswordAge -ne 0) {
        Write-Result "Maximum password age" "Compliant" "Currently set to $($currentState.MaxPasswordAge) days."
    } else {
        Write-Result "Maximum password age" "Not Compliant" "Currently set to $($currentState.MaxPasswordAge), should be <= 90."
    }

} elseif ($Mode -eq "Rollback") {
    if (-not (Test-Path $RollbackFile)) {
        Write-Result "Rollback" "Failure" "Rollback file not found: $RollbackFile"
        exit 1 # Exit with an error code
    }
    $rollbackContent = Get-Content $RollbackFile | ConvertFrom-Json
    foreach ($item in $rollbackContent) {
        try {
            # Logic to revert each setting using the value from the file
            if ($item.parameter -eq "PasswordHistory") {
                net accounts /uniquepw:$($item.value)
            }
            if ($item.parameter -eq "MaxPasswordAge") {
                net accounts /maxpwage:$($item.value)
            }
            Write-Result "Rollback $($item.parameter)" "Success" "Reverted to '$($item.value)'."
        } catch {
            Write-Result "Rollback $($item.parameter)" "Failure" "Could not revert. Error: $_.Exception.Message"
        }
    }
    # After a successful rollback, the file is deleted by the Python script
}

