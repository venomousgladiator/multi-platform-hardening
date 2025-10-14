# scripts/windows/Set-PasswordHistory.ps1

$ErrorActionPreference = "SilentlyContinue"
$result = [PSCustomObject]@{
    parameter = "Enforce password history"
    status    = "Error"
    details   = "Failed to set password history. This script must be run with Administrator privileges."
}

try {
    # This command sets the history to 24 passwords as per the PDF.
    net accounts /uniquepw:24
    
    # Check if the command was successful.
    if ($LASTEXITCODE -eq 0) {
        $result.status = "Success"
        $result.details = "Password history has been set to remember the last 24 passwords."
    }
}
catch {
     $result.details = $_.Exception.Message
}

$result | ConvertTo-Json -Compress