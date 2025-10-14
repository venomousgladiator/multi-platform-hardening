# scripts/windows/Rollback-PasswordHistory.ps1

param (
    [string]$RollbackValue
)

$ErrorActionPreference = "SilentlyContinue"
$result = [PSCustomObject]@{
    parameter = "Rollback password history"
    status    = "Error"
    details   = "Failed to rollback. This script must be run with Administrator privileges."
}

try {
    # Apply the old value that was passed as a parameter
    net accounts /uniquepw:$RollbackValue
    
    if ($LASTEXITCODE -eq 0) {
        $result.status = "Success"
        $result.details = "Password history has been rolled back to remember the last $($RollbackValue) passwords."
    }
}
catch {
     $result.details = $_.Exception.Message
}

$result | ConvertTo-Json -Compress