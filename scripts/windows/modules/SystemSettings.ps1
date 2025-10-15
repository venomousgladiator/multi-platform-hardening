param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Audit','Harden','Rollback')]
    [string]$Mode,
    
    [Parameter(Mandatory=$false)]
    [string]$RollbackFile
)

# Initialize rollback data storage
$rollbackData = @{}

function Write-Output-Json {
    param(
        [string]$Parameter,
        [string]$Status,
        [string]$Details
    )
    $output = @{
        parameter = $Parameter
        status = $Status
        details = $Details
    }
    Write-Output ($output | ConvertTo-Json -Compress)
}

# UAC Settings Configuration
$uacSettings = @{
    "EnableLUA" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "EnableLUA"
        Value = 1
        Type = "DWord"
        Description = "User Account Control: Run all administrators in Admin Approval Mode"
    }
    "ConsentPromptBehaviorAdmin" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "ConsentPromptBehaviorAdmin"
        Value = 2
        Type = "DWord"
        Description = "UAC: Behavior of elevation prompt for administrators"
    }
    "ConsentPromptBehaviorUser" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "ConsentPromptBehaviorUser"
        Value = 0
        Type = "DWord"
        Description = "UAC: Behavior of elevation prompt for standard users"
    }
    "FilterAdministratorToken" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "FilterAdministratorToken"
        Value = 1
        Type = "DWord"
        Description = "UAC: Admin Approval Mode for Built-in Administrator"
    }
    "EnableInstallerDetection" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "EnableInstallerDetection"
        Value = 1
        Type = "DWord"
        Description = "UAC: Detect application installations and prompt for elevation"
    }
    "PromptOnSecureDesktop" = @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Name = "PromptOnSecureDesktop"
        Value = 1
        Type = "DWord"
        Description = "UAC: Switch to secure desktop when prompting for elevation"
    }
}

# Services to be disabled
$servicesToDisable = @(
    @{ Name = "BTAGService"; DisplayName = "Bluetooth Audio Gateway Service" },
    @{ Name = "bthserv"; DisplayName = "Bluetooth Support Service" },
    @{ Name = "Browser"; DisplayName = "Computer Browser" },
    @{ Name = "lfsvc"; DisplayName = "Geolocation Service" },
    @{ Name = "SharedAccess"; DisplayName = "Internet Connection Sharing (ICS)" },
    @{ Name = "SessionEnv"; DisplayName = "Remote Desktop Configuration" },
    @{ Name = "TermService"; DisplayName = "Remote Desktop Services" },
    @{ Name = "UmRdpService"; DisplayName = "Remote Desktop Services UserMode Port Redirector" },
    @{ Name = "RpcLocator"; DisplayName = "RPC Locator" },
    @{ Name = "RemoteRegistry"; DisplayName = "Remote Registry" },
    @{ Name = "RemoteAccess"; DisplayName = "Routing and Remote Access" },
    @{ Name = "simptcp"; DisplayName = "Simple TCP/IP Services" },
    @{ Name = "SNMP"; DisplayName = "SNMP Service" },
    @{ Name = "upnphost"; DisplayName = "UPnP Device Host" },
    @{ Name = "WMSvc"; DisplayName = "Web Management Service" },
    @{ Name = "WerSvc"; DisplayName = "Windows Error Reporting Service" },
    @{ Name = "Wecsvc"; DisplayName = "Windows Event Collector" },
    @{ Name = "WMPNetworkSvc"; DisplayName = "Windows Media Player Network Sharing Service" },
    @{ Name = "icssvc"; DisplayName = "Windows Mobile Hotspot Service" },
    @{ Name = "PushToInstall"; DisplayName = "Windows PushToInstall Service" },
    @{ Name = "WinRM"; DisplayName = "Windows Remote Management" },
    @{ Name = "W3SVC"; DisplayName = "World Wide Web Publishing Service" },
    @{ Name = "XboxGipSvc"; DisplayName = "Xbox Accessory Management Service" },
    @{ Name = "XblAuthManager"; DisplayName = "Xbox Live Auth Manager" },
    @{ Name = "XblGameSave"; DisplayName = "Xbox Live Game Save" },
    @{ Name = "XboxNetApiSvc"; DisplayName = "Xbox Live Networking Service" }
)

function Set-UACSettings {
    foreach ($setting in $uacSettings.GetEnumerator()) {
        $currentValue = Get-ItemProperty -Path $setting.Value.Path -Name $setting.Value.Name -ErrorAction SilentlyContinue
        
        if ($Mode -eq 'Audit') {
            if ($currentValue.$($setting.Value.Name) -eq $setting.Value.Value) {
                Write-Output-Json -Parameter $setting.Value.Description -Status "Compliant" -Details "Current setting is correct"
            } else {
                Write-Output-Json -Parameter $setting.Value.Description -Status "Not Compliant" -Details "Current value: $($currentValue.$($setting.Value.Name)), Expected: $($setting.Value.Value)"
            }
        } elseif ($Mode -eq 'Harden') {
            try {
                # Store current value for rollback
                $rollbackData[$setting.Key] = $currentValue.$($setting.Value.Name)
                
                # Set new value
                Set-ItemProperty -Path $setting.Value.Path -Name $setting.Value.Name -Value $setting.Value.Value -Type $setting.Value.Type -Force
                Write-Output-Json -Parameter $setting.Value.Description -Status "Success" -Details "Setting applied successfully"
            } catch {
                Write-Output-Json -Parameter $setting.Value.Description -Status "Failure" -Details $_.Exception.Message
            }
        }
    }
}

function Set-ServiceStates {
    foreach ($service in $servicesToDisable) {
        $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
        
        if ($Mode -eq 'Audit') {
            if ($null -eq $svc) {
                Write-Output-Json -Parameter $service.DisplayName -Status "Compliant" -Details "Service is not installed"
            } elseif ($svc.StartType -eq 'Disabled') {
                Write-Output-Json -Parameter $service.DisplayName -Status "Compliant" -Details "Service is disabled"
            } else {
                Write-Output-Json -Parameter $service.DisplayName -Status "Not Compliant" -Details "Service is $($svc.StartType)"
            }
        } elseif ($Mode -eq 'Harden') {
            if ($null -ne $svc) {
                try {
                    # Store current state for rollback
                    $rollbackData[$service.Name] = @{
                        StartType = $svc.StartType
                        Status = $svc.Status
                    }
                    
                    Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service.Name -StartupType Disabled
                    Write-Output-Json -Parameter $service.DisplayName -Status "Success" -Details "Service disabled successfully"
                } catch {
                    Write-Output-Json -Parameter $service.DisplayName -Status "Failure" -Details $_.Exception.Message
                }
            }
        }
    }
}

# Main execution
try {
    if ($Mode -eq 'Rollback' -and $RollbackFile) {
        $rollbackData = Get-Content $RollbackFile | ConvertFrom-Json
        # Implement rollback logic here
    } else {
        Set-UACSettings
        Set-ServiceStates
        
        if ($Mode -eq 'Harden') {
            # Save rollback data
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $rollbackPath = Join-Path $PSScriptRoot "..\..\..\rollback"
            if (-not (Test-Path $rollbackPath)) {
                New-Item -ItemType Directory -Path $rollbackPath | Out-Null
            }
            $rollbackFile = Join-Path $rollbackPath "${timestamp}_SystemSettings.json"
            $rollbackData | ConvertTo-Json | Out-File $rollbackFile
        }
    }
} catch {
    Write-Output-Json -Parameter "System Settings" -Status "Failure" -Details $_.Exception.Message
}
