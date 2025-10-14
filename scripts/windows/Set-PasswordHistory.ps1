# scripts/windows/Set-PasswordHistory.ps1

$ErrorActionPreference = "SilentlyContinue"

# --- 1. Get the current setting first ---
$currentHistoryValue = (net accounts | Select-String "Password history").ToString().Split(':')[1].Trim()

# --- 2. Save the current setting to a rollback file ---
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$rollbackFile = "rollback\PasswordHistory_$($timestamp).json"
$rollbackData = @{
    parameter = "Enforce password history"
    value = $currentHistoryValue
}
$rollbackData | ConvertTo-Json -Compress | Out-File -FilePath $rollbackFile -Encoding utf8

# --- 3. Apply the new setting ---
$result = [PSCustomObject]@{
    parameter = "Enforce password history"
    status    = "Error"
    details   = "Failed to set password history. This script must be run with Administrator privileges."
}

try {
    net accounts /uniquepw:24 # Apply the hardening
    
    if ($LASTEXITCODE -eq 0) {
        $result.status = "Success"
        $result.details = "Password history set to 24. Previous value of '$($currentHistoryValue)' saved to $($rollbackFile)."
    }
}
catch {
     $result.details = $_.Exception.Message
}

$result | ConvertTo-Json -Compress