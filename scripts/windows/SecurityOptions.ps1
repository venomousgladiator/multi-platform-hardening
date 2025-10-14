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

# --- Module: Accounts Security ---
function Set-AccountsOptions {
    Write-Result "Module: Accounts Security Options" "Info" "Applying L1 account security options..."
    
    # Policy: 3.a.ii - Ensure 'Accounts: Guest account status' is set to 'Disabled'
    try {
        $guest = Get-LocalUser -Name "Guest" -ErrorAction Stop
        if ($guest.Enabled) {
            Disable-LocalUser -Name "Guest"
            Write-Result "Guest Account Status" "Success" "Guest account has been disabled."
        } else {
            Write-Result "Guest Account Status" "Success" "Guest account is already disabled."
        }
    } catch { Write-Result "Guest Account Status" "Failure" "Could not find or modify the Guest account. Error: $_.Exception.Message" }

    # Policy: 3.a.iii - Ensure 'Accounts: Limit local account use of blank passwords...' is set to 'Enabled'
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Set-ItemProperty -Path $regPath -Name "limitblankpassworduse" -Value 1 -Type DWord -Force
        Write-Result "Limit Blank Passwords" "Success" "Set to 'Enabled'. Only console logon is allowed for blank passwords."
    } catch { Write-Result "Limit Blank Passwords" "Failure" "Could not set registry key. Requires Administrator privileges. Error: $_.Exception.Message" }
}

# --- Module: Interactive Logon ---
function Set-InteractiveLogonOptions {
    Write-Result "Module: Interactive Logon Options" "Info" "Applying L1 interactive logon policies..."

    # Policy: 3.b.i - Ensure 'Interactive logon: Do not require CTRL+ALT+DEL' is set to 'Disabled'
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        # Setting DisableCAD to 0 means CTRL+ALT+DEL is REQUIRED, which matches the policy goal.
        Set-ItemProperty -Path $regPath -Name "DisableCAD" -Value 0 -Type DWord -Force
        Write-Result "Require CTRL+ALT+DEL" "Success" "Set to 'Enabled' (DisableCAD registry value is 0)."
    } catch { Write-Result "Require CTRL+ALT+DEL" "Failure" "Could not set registry key. Requires Administrator privileges. Error: $_.Exception.Message" }

    # Policy: 3.b.ii - Ensure 'Interactive logon: Don't display last signed in' is set to 'Enabled'
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        Set-ItemProperty -Path $regPath -Name "dontdisplaylastusername" -Value 1 -Type DWord -Force
        Write-Result "Don't Display Last User" "Success" "Set to 'Enabled'."
    } catch { Write-Result "Don't Display Last User" "Failure" "Could not set registry key. Requires Administrator privileges. Error: $_.Exception.Message" }
}

# --- Main script execution logic ---
if ($Level -ge "L1") {
    Set-AccountsOptions
    Set-InteractiveLogonOptions
}

# No L2 or L3 specific policies in this module, but the structure is here for future expansion.