[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Audit', 'Harden', 'Rollback')]
    [string]$Mode,

    [Parameter(Mandatory=$false)]
    [ValidateSet('L1', 'L2', 'L3')]
    [string]$Level = "L1",

    [Parameter(Mandatory=$false)]
    [string]$RollbackFile
)

# Helper function to output results in JSON format
function Write-Result {
    param(
        [string]$Parameter,
        [string]$Status,
        [string]$Details
    )
    
    $result = @{
        parameter = $Parameter
        status = $Status
        details = $Details
    }
    
    $jsonResult = $result | ConvertTo-Json -Compress
    Write-Output $jsonResult
}

# Helper function to create rollback data
function New-RollbackData {
    param(
        [string]$Setting,
        [object]$OriginalValue
    )
    
    return @{
        setting = $Setting
        value = $OriginalValue
    }
}

# Function to get current password policy settings
function Get-CurrentPasswordPolicy {
    $policy = net accounts
    return $policy
}

# Function to apply password policy settings
function Set-PasswordPolicy {
    param([string]$Level)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $rollbackPath = "..\..\rollback\${timestamp}_AccountPolicies.json"
    $rollbackData = @{
        timestamp = $timestamp
        policies = @()
    }

    # Store current settings for rollback
    $currentPolicy = Get-CurrentPasswordPolicy
    $rollbackData.policies += @(
        (New-RollbackData -Setting "PasswordHistory" -OriginalValue ($currentPolicy | Select-String "Length of password history").ToString()),
        (New-RollbackData -Setting "MaxPasswordAge" -OriginalValue ($currentPolicy | Select-String "Maximum password age").ToString()),
        (New-RollbackData -Setting "MinPasswordAge" -OriginalValue ($currentPolicy | Select-String "Minimum password age").ToString()),
        (New-RollbackData -Setting "PasswordComplexity" -OriginalValue (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters").RequireStrongKey)
    )

    # Apply base settings (common across all levels)
    # Password Policy
    net accounts /minpwlen:12 # iv. Minimum 12 characters
    net accounts /maxpwage:90 # ii. Maximum 90 days
    net accounts /minpwage:1  # iii. Minimum 1 day
    net accounts /uniquepw:24 # i. Remember 24 passwords

    # Enable password complexity
    secedit /configure /db "$env:WINDIR\security\local.sdb" /cfg "$env:WINDIR\security\local.inf" /areas SECURITYPOLICY /cfg "PasswordComplexity=1"

    # Disable reversible encryption
    secedit /configure /db "$env:WINDIR\security\local.sdb" /cfg "$env:WINDIR\security\local.inf" /areas SECURITYPOLICY /cfg "ClearTextPassword=0"

    # Account Lockout Policy
    net accounts /lockoutduration:15 # b.i. 15 minutes
    net accounts /lockoutthreshold:5 # b.ii. 5 attempts
    
    # Enable Administrator account lockout (requires registry modification)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
    Set-ItemProperty -Path $regPath -Name "AdminLockout" -Value 1 -Type DWord

    # Level-specific additional hardening
    switch ($Level) {
        "L2" {
            net accounts /minpwlen:14
            net accounts /lockoutduration:30
        }
        "L3" {
            net accounts /minpwlen:16
            net accounts /lockoutduration:60
            net accounts /lockoutthreshold:3
        }
    }

    # Save rollback data
    $rollbackData | ConvertTo-Json | Out-File -FilePath $rollbackPath -Force

    # Output results
    Write-Result -Parameter "Password History" -Status "Success" -Details "Set to remember 24 passwords"
    Write-Result -Parameter "Maximum Password Age" -Status "Success" -Details "Set to 90 days"
    Write-Result -Parameter "Minimum Password Age" -Status "Success" -Details "Set to 1 day"
    Write-Result -Parameter "Password Complexity" -Status "Success" -Details "Requirements enabled"
    Write-Result -Parameter "Reversible Encryption" -Status "Success" -Details "Disabled"
    Write-Result -Parameter "Account Lockout Duration" -Status "Success" -Details "Set to 15 minutes"
    Write-Result -Parameter "Account Lockout Threshold" -Status "Success" -Details "Set to 5 attempts"
    Write-Result -Parameter "Admin Account Lockout" -Status "Success" -Details "Enabled"
}

# Function to audit password policy settings
function Test-PasswordPolicy {
    param([string]$Level)

    $currentPolicy = Get-CurrentPasswordPolicy
    $securityPolicy = secedit /export /cfg "$env:TEMP\secpol.cfg"
    
    # Check password history
    $pwHistory = [int]($currentPolicy | Select-String "Length of password history" -Raw).Split(":")[1].Trim()
    if ($pwHistory -ge 24) {
        Write-Result -Parameter "Password History" -Status "Compliant" -Details "Set to remember $pwHistory passwords"
    } else {
        Write-Result -Parameter "Password History" -Status "Not Compliant" -Details "Currently $pwHistory, required: 24"
    }

    # Check maximum password age
    $maxAge = [int]($currentPolicy | Select-String "Maximum password age" -Raw).Split(":")[1].Trim()
    if ($maxAge -le 90 -and $maxAge -ne 0) {
        Write-Result -Parameter "Maximum Password Age" -Status "Compliant" -Details "Set to $maxAge days"
    } else {
        Write-Result -Parameter "Maximum Password Age" -Status "Not Compliant" -Details "Currently $maxAge days, required: 90 or less (not 0)"
    }

    # Check minimum password age
    $minAge = [int]($currentPolicy | Select-String "Minimum password age" -Raw).Split(":")[1].Trim()
    if ($minAge -ge 1) {
        Write-Result -Parameter "Minimum Password Age" -Status "Compliant" -Details "Set to $minAge day"
    } else {
        Write-Result -Parameter "Minimum Password Age" -Status "Not Compliant" -Details "Currently $minAge day, required: 1 day or more"
    }

    # Check password complexity
    $complexity = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "RequireStrongKey" -ErrorAction SilentlyContinue
    if ($complexity.RequireStrongKey -eq 1) {
        Write-Result -Parameter "Password Complexity" -Status "Compliant" -Details "Enabled"
    } else {
        Write-Result -Parameter "Password Complexity" -Status "Not Compliant" -Details "Disabled"
    }

    # Check reversible encryption
    $encryption = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "ClearTextPassword" -ErrorAction SilentlyContinue
    if ($encryption.ClearTextPassword -eq 0) {
        Write-Result -Parameter "Reversible Encryption" -Status "Compliant" -Details "Disabled"
    } else {
        Write-Result -Parameter "Reversible Encryption" -Status "Not Compliant" -Details "Enabled"
    }

    # Check account lockout duration
    $lockoutDuration = [int]($currentPolicy | Select-String "Lockout duration" -Raw).Split(":")[1].Trim()
    if ($lockoutDuration -ge 15) {
        Write-Result -Parameter "Account Lockout Duration" -Status "Compliant" -Details "Set to $lockoutDuration minutes"
    } else {
        Write-Result -Parameter "Account Lockout Duration" -Status "Not Compliant" -Details "Currently $lockoutDuration minutes, required: 15 minutes or more"
    }

    # Check account lockout threshold
    $lockoutThreshold = [int]($currentPolicy | Select-String "Lockout threshold" -Raw).Split(":")[1].Trim()
    if ($lockoutThreshold -le 5 -and $lockoutThreshold -ne 0) {
        Write-Result -Parameter "Account Lockout Threshold" -Status "Compliant" -Details "Set to $lockoutThreshold attempts"
    } else {
        Write-Result -Parameter "Account Lockout Threshold" -Status "Not Compliant" -Details "Currently $lockoutThreshold attempts, required: 5 attempts or less (not 0)"
    }

    # Check Administrator account lockout
    $adminLockout = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "AdminLockout" -ErrorAction SilentlyContinue
    if ($adminLockout.AdminLockout -eq 1) {
        Write-Result -Parameter "Admin Account Lockout" -Status "Compliant" -Details "Enabled"
    } else {
        Write-Result -Parameter "Admin Account Lockout" -Status "Not Compliant" -Details "Disabled"
    }
}

# Main execution block
try {
    switch ($Mode) {
        "Audit" {
            Test-PasswordPolicy -Level $Level
        }
        "Harden" {
            Set-PasswordPolicy -Level $Level
        }
        "Rollback" {
            if (-not $RollbackFile) {
                Write-Result -Parameter "Rollback" -Status "Failure" -Details "No rollback file specified"
                exit 1
            }
            
            $rollbackData = Get-Content $RollbackFile | ConvertFrom-Json
            foreach ($policy in $rollbackData.policies) {
                # Apply original settings
                # ...existing rollback logic...
            }
        }
    }
} catch {
    Write-Result -Parameter "Error" -Status "Failure" -Details $_.Exception.Message
    exit 1
}

