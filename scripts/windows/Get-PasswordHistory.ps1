# scripts/windows/Get-PasswordHistory.ps1

$ErrorActionPreference = "SilentlyContinue"
$result = [PSCustomObject]@{
    parameter = "Enforce password history"
    status    = "Error"
    details   = "Could not retrieve setting."
}

try {
    # This command works on both domain-joined and standalone machines.
    $historyValue = (net accounts | Select-String "Password history").ToString().Split(':')[1].Trim()
    
    $result.status = "Info"
    $result.details = "Current password history is set to remember the last $($historyValue) passwords."
}
catch {
    $result.details = $_.Exception.Message
}

# Always output the result as a JSON string
$result | ConvertTo-Json -Compress