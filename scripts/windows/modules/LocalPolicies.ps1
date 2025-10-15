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

# Import common functions
. "$PSScriptRoot\..\common\Common.ps1"

# Initialize results array and rollback data
$results = @()
$rollbackData = @()

function Set-UserRightsAssignment {
    param (
        [string]$Right,
        [string[]]$DesiredUsers,
        [bool]$Audit = $false
    )
    
    try {
        $currentUsers = (Get-UserRights -Right $Right) -split ","
        $currentUsers = $currentUsers | ForEach-Object { $_.Trim() }
        
        if ($Audit) {
            $isCompliant = Compare-Object -ReferenceObject $currentUsers -DifferenceObject $DesiredUsers -IncludeEqual
            if (!$isCompliant) {
                return @{
                    status = "Not Compliant"
                    parameter = "User Rights: $Right"
                    details = "Current: $($currentUsers -join ', ') | Expected: $($DesiredUsers -join ', ')"
                }
            }
            return @{
                status = "Compliant"
                parameter = "User Rights: $Right"
                details = "Settings match requirements"
            }
        } else {
            # Store current setting for rollback
            $rollbackData += @{
                setting = "UserRights"
                right = $Right
                value = $currentUsers
            }
            
            # Apply new setting
            Set-UserRights -Right $Right -Users $DesiredUsers
            return @{
                status = "Success"
                parameter = "User Rights: $Right"
                details = "Updated to: $($DesiredUsers -join ', ')"
            }
        }
    } catch {
        return @{
            status = "Failure"
            parameter = "User Rights: $Right"
            details = $_.Exception.Message
        }
    }
}

function Set-SecurityOption {
    param (
        [string]$Path,
        [string]$Key,
        [string]$Value,
        [bool]$Audit = $false
    )
    
    try {
        $currentValue = (Get-ItemProperty -Path $Path).$Key
        
        if ($Audit) {
            if ($currentValue -ne $Value) {
                return @{
                    status = "Not Compliant"
                    parameter = "Security Option: $Key"
                    details = "Current: $currentValue | Expected: $Value"
                }
            }
            return @{
                status = "Compliant"
                parameter = "Security Option: $Key"
                details = "Settings match requirements"
            }
        } else {
            # Store current setting for rollback
            $rollbackData += @{
                setting = "Registry"
                path = $Path
                key = $Key
                value = $currentValue
            }
            
            # Apply new setting
            Set-ItemProperty -Path $Path -Name $Key -Value $Value
            return @{
                status = "Success"
                parameter = "Security Option: $Key"
                details = "Updated to: $Value"
            }
        }
    } catch {
        return @{
            status = "Failure"
            parameter = "Security Option: $Key"
            details = $_.Exception.Message
        }
    }
}

# Main execution block
try {
    # User Rights Assignment checks/modifications
    $checks = @(
        @{Right="SeTrustedCredManAccessPrivilege"; Users=@()},
        @{Right="SeNetworkLogonRight"; Users=@("Administrators", "Remote Desktop Users")},
        @{Right="SeIncreaseQuotaPrivilege"; Users=@("Administrators", "LOCAL SERVICE", "NETWORK SERVICE")},
        @{Right="SeInteractiveLogonRight"; Users=@("Administrators", "Users")},
        @{Right="SeBackupPrivilege"; Users=@("Administrators")},
        @{Right="SeSystemtimePrivilege"; Users=@("Administrators", "LOCAL SERVICE")},
        @{Right="SeTimeZonePrivilege"; Users=@("Administrators", "LOCAL SERVICE", "Users")}
    )

    foreach ($check in $checks) {
        $results += Set-UserRightsAssignment -Right $check.Right -DesiredUsers $check.Users -Audit ($Mode -eq 'Audit')
    }

    # Security Options checks/modifications
    $securityOptions = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Key="NoConnectedUser"; Value="3"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"; Key="LimitBlankPasswordUse"; Value="1"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Key="DisableCAD"; Value="0"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Key="DontDisplayLastUserName"; Value="1"}
        # ... Add more security options here
    )

    foreach ($option in $securityOptions) {
        $results += Set-SecurityOption -Path $option.Path -Key $option.Key -Value $option.Value -Audit ($Mode -eq 'Audit')
    }

    # Handle rollback data if in Harden mode
    if ($Mode -eq 'Harden') {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $rollbackPath = Join-Path $PSScriptRoot "..\..\..\rollback\${timestamp}_LocalPolicies.json"
        $rollbackData | ConvertTo-Json | Out-File $rollbackPath
    }

    # Output results
    $results | ForEach-Object { $_ | ConvertTo-Json }

} catch {
    @{
        status = "Failure"
        parameter = "LocalPolicies"
        details = $_.Exception.Message
    } | ConvertTo-Json
}
