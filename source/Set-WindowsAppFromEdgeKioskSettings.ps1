<# 
.SYNOPSIS
    This script creates a custom Edge-based kiosk configuration for Azure Virtual Desktop and Windows 365 access.
    It uses Microsoft Edge in kiosk mode with Shell Launcher to display a web interface that can launch the Windows App
    via the ms-avd protocol. The configuration uses a combination of Assigned Access policies, AppLocker rules, local 
    group policy settings, provisioning packages, and registry edits to create a secure kiosk environment.

    The solution provides:
    * Automatic logon with the KioskUser0 account
    * Microsoft Edge in single-app kiosk mode as the shell
    * A configurable URL (default: local HTML file) that can launch Windows App connections
    * Windows App automatic logoff and reset behaviors for enhanced security
    * Locked-down user experience preventing access to unauthorized applications
    
    This is a customized configuration tailored to specific deployment requirements and customer preferences.

.DESCRIPTION 
    This script completes a series of configuration tasks to create a secure kiosk environment:

    * Shell Launcher configuration to replace Explorer with Microsoft Edge in kiosk mode
    * Automatic logon with the KioskUser0 account created by Assigned Access
    * Windows App provisioning from the Microsoft download site or via a local source file
    * Windows App automatic logoff and reset configuration to protect credentials
    * AppLocker policy to restrict unauthorized application execution
    * Local Group Policy configuration to lock down the user interface
    * Provisioning packages to disable Windows Spotlight, first logon animation, and advertising ID
    * Built-in application removal to reduce attack surface and improve performance
    * Power management and automatic maintenance configuration for shared device scenarios
    * Keyboard filter to block common Windows key combinations
    * Registry modifications to enforce security and kiosk behaviors

.NOTES 
    Author: Shawn Meyer, Microsoft
    Creation Date: 02/15/2023
    Last Modified: 02/19/2026
    Version: 2026.02.19.1
    
    This is a custom version of the Windows App kiosk solution tailored to specific customer requirements. 
    The configuration has been streamlined to focus on a particular deployment scenario: an auto-logon 
    Edge kiosk that launches Windows App connections.
    
    The script can optionally remove legacy configurations and existing kiosk settings using the 
    -RemoveLegacySettings and -RemoveExistingSettings parameters respectively.

.PARAMETER InstallWindowsApp
This switch parameter determines if the latest Windows App is automatically downloaded from the Internet and installed on the system prior to configuration. Supports both online (automatic download) and offline (local MSIX file) installation. When a local MSIX file is present in the Apps\WindowsApp directory, no internet connection is required and the local file will be used instead. For detailed offline installation instructions, see Apps\WindowsApp\README.md.

.PARAMETER WindowsAppAutoLogoffConfig
This string parameter determines the automatic logoff configuration for the Windows App. The possible values are:
- Disabled - Disables automatic sign-out and app data reset for the Windows App. (Not recommended for kiosk scenarios)
- ResetAppOnCloseOnly - Sign all users out of Windows App and reset app data when the user closes the app
- ResetAppAfterConnection - Sign all users out of Windows App and reset app data when a successful connection is made to an Azure Virtual Desktop session host or Windows 365 Cloud PC
- ResetAppOnCloseOrIdle - Sign all users out of Windows App and reset app data when the operating system is idle for the specified time interval in minutes or the user closes the app

For kiosk security, it is strongly recommended to use 'ResetAppOnCloseOrIdle' to ensure credentials are protected during idle periods.

.PARAMETER WindowsAppAutoLogoffTimeInterval
This integer parameter determines the interval in minutes at which Windows App checks the Windows OS for inactivity. For example, if set to 5, the app will poll the OS for inactivity every 5 minutes and the logout process will initiate if the OS reports 5 or more minutes of inactivity. This parameter is required when WindowsAppAutoLogoffConfig is set to 'ResetAppOnCloseOrIdle'. Default value is 15 minutes
This integer value determines the number of minutes of idle time before the user is automatically logged off. This parameter is only valid when the AutoLogonKiosk switch parameter is not used. When used with other idle timeout parameters, this must be at least 15 minutes greater than IdleLockTimeoutMinutes and at least 15 minutes less than IdleSleepTimeoutMinutes.

.PARAMETER ConfigureAutomaticMaintenance
This switch parameter determines if Windows automatic maintenance settings are configured via Local Group Policy. When enabled, maintenance tasks will run at the specified activation time with optional random delay.

.PARAMETER MaintenanceActivationTime
This string parameter specifies the time of day when automatic maintenance should begin in HH:mm:ss format (e.g., "02:00:00" for 2:00 AM). The time is converted to ISO 8601 format internally with date 2000-01-01T for policy application. Default is "00:00:00" (midnight).

.PARAMETER MaintenanceRandomDelay
This integer parameter specifies the maximum random delay in hours that can be added to the maintenance activation time to prevent multiple systems from running maintenance simultaneously. Valid values are 1-6 hours. The value is converted to ISO 8601 duration format (PT#H) internally. Default is 2 hours.

.PARAMETER SetPowerPolicies
This switch parameter determines if power management policies are configured via Local Group Policy to optimize behavior for shared PC scenarios. When enabled, configures power button, sleep button, and lid switch actions to sleep, enables energy saver settings, disables hibernation, and enables standby states while turning off hybrid sleep for both battery and plugged-in scenarios. Requires IdleSleepTimeoutMinutes parameter to be specified.

.PARAMETER IdleSleepTimeoutMinutes
This integer parameter specifies the number of minutes of user inactivity before the system automatically goes to sleep. This parameter is required when SetPowerPolicies is used and works in conjunction with it to manage power consumption in shared PC environments. When used with other idle timeout parameters, this must be at least 15 minutes greater than both IdleLockTimeoutMinutes and IdleLogoffTimeoutMinutes to ensure proper escalation sequence (lock → logoff → sleep).

.PARAMETER KioskUrl
This string parameter specifies the URL that Microsoft Edge will open in kiosk mode. The default value is 'file:///c:/kiosksettings/Index.html' which uses a local HTML file containing buttons to launch Windows App connections. When set to a different URL (e.g., a custom web portal), the local HTML file will not be created and Edge will be configured to open the specified URL directly. Your custom URL should include ms-avd:// protocol links to launch Windows App.

.PARAMETER AllowedUrls
This string array parameter specifies which URLs Microsoft Edge is allowed to navigate to in kiosk mode. The default includes file:// for local content and protocol handlers (ms-avd://, ms-cloudpc://, evo://, workspaces://). All other navigation is blocked. Customize this list to include your specific allowed domains. Examples: 'https://portal.tailspintoys.com', 'tailspintoys.com', 'http://intranet.local'. **Note:** The protocols ms-avd://* and ms-cloudpc://* are always automatically included to ensure Windows App functionality. The KioskUrl is also automatically included unless already covered by an existing pattern.

.PARAMETER RemoveLegacySettings
This switch parameter removes legacy kiosk configurations from previous versions or other kiosk implementations before applying the new configuration. This ensures a clean slate by running the Remove-LegacyKioskSettings.ps1 script.

.PARAMETER RemoveExistingSettings
This switch parameter removes existing Windows App kiosk settings before applying the new configuration. This allows the script to be re-run on a system that has already been configured by running the Remove-WindowsAppKioskSettings.ps1 script.

.PARAMETER Version
This version parameter allows tracking of the installed version using configuration management software such as Microsoft Endpoint Manager or Microsoft Endpoint Configuration Manager by querying the value of the registry value: HKLM\Software\Kiosk\version.

#>
[CmdletBinding()]
param (
    [switch]$InstallWindowsApp,

    [ValidateSet('Disabled', 'ResetAppOnCloseOnly', 'ResetAppAfterConnection', 'ResetAppOnCloseOrIdle')]
    [string]$WindowsAppAutoLogoffConfig,
    
    [int]$WindowsAppAutoLogoffTimeInterval = 60,

    [Parameter()]
    [switch]$ConfigureAutomaticMaintenance,

    [Parameter()]
    [ValidateScript({
            if ($_ -match '^\d{2}:\d{2}:\d{2}$') {
                $timeSpan = [TimeSpan]::ParseExact($_, 'hh\:mm\:ss', $null)
                if ($timeSpan -ge [TimeSpan]::Zero -and $timeSpan -lt [TimeSpan]::FromHours(24)) {
                    return $true
                }
                throw "Time must be between 00:00:00 and 23:59:59"
            }
            throw "Time must be in HH:mm:ss format (e.g., 02:00:00, 14:30:00, 23:59:59)"
        })]
    [string]$MaintenanceActivationTime = '00:00:00',

    [Parameter()]
    [ValidateRange(0, 6)]
    [Int]$MaintenanceRandomDelay = 2,

    [Parameter()]
    [switch]$SetPowerPolicies,

    [Parameter()]
    [ValidateRange(30, 1440)]
    [int]$IdleSleepTimeoutMinutes,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$KioskUrl = 'file:///c:/kiosksettings/index.html',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$AllowedUrls = @('file://*', 'ms-avd://*', 'ms-cloudpc://*', 'workspaces://*', 'evo://*'),

    [Parameter()]
    [switch]$RemoveLegacySettings,

    [Parameter()]
    [switch]$RemoveExistingSettings,

    [version]$Version = '1.0.0'
)

If ($WindowsAppAutoLogoffConfig -eq 'ResetAppOnCloseOrIdle' -and ($null -eq $WindowsAppAutoLogoffTimeInterval -or $WindowsAppAutoLogoffTimeInterval -eq '')) {
    Throw "You must specify a value for 'WindowsAppAutoLogoffTimeInterval' when 'WindowsAppAutoLogoffConfig' = 'ResetAppOnCloseOrIdle'"
} 

If ($SetPowerPolicies -and $null -eq $IdleSleepTimeoutMinutes) {
    Throw "You must specify a value for 'IdleSleepTimeoutMinutes' when 'SetPowerPolicies' is used"
} 

# Restart in 64-Bit PowerShell if not already running in 64-bit mode
# primarily designed to support Microsoft Endpoint Manager application deployment
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    $scriptArguments = $null
    Try {
        foreach ($k in $PSBoundParameters.keys) {
            switch ($PSBoundParameters[$k].GetType().Name) {
                "SwitchParameter" { If ($PSBoundParameters[$k].IsPresent) { $scriptArguments += "-$k " } }
                "String" { If ($PSBoundParameters[$k] -match '_') { $scriptArguments += "-$k `"$($PSBoundParameters[$k].Replace('_',' '))`" " } Else { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " } }
                "String[]" { $ScriptArguments += "-$k @('$($PSBoundParameters[$k] -join "','")') " }
                "Int32" { $scriptArguments += "-$k $($PSBoundParameters[$k]) " }
                "Boolean" { $scriptArguments += "-$k `$$($PSBoundParameters[$k]) " }
                "Version" { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " }
            }
        }
        If ($null -ne $scriptArguments) {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`" $scriptArguments" -PassThru -Wait -NoNewWindow
        }
        Else {
            $RunScript = Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$PSCommandPath`"" -PassThru -Wait -NoNewWindow
        }
    }
    Catch {
        Throw "Failed to start 64-bit PowerShell"
    }
    Exit $RunScript.ExitCode
}

$Script:FullName = $MyInvocation.MyCommand.Path
$Script:Dir = Split-Path $Script:FullName
# Windows Event Log (.evtx)
$EventLog = 'Windows-App-Kiosk'
$EventSource = 'ConfigScript'
# Find LTSC OS (and Windows IoT Enterprise)
$OS = Get-WmiObject -Class Win32_OperatingSystem
[string]$FullOSVersion = [string]$OS.Version + '.' + (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
# Detect Windows 11
If ($OS.Name -match 'LTSC') { $LTSC = $true }
# Source Directories and supporting files
$DirAppLocker = Join-Path -Path $Script:Dir -ChildPath "AppLocker"
$FileAppLockerClear = Join-Path -Path $DirAppLocker -ChildPath "ClearAppLockerPolicy.xml"
$DirApps = Join-Path -Path $Script:Dir -ChildPath 'Apps'
$DirAssignedAccess = Join-Path -Path $Script:Dir -ChildPath 'AssignedAccess'
$DirProvisioningPackages = Join-Path -Path $Script:Dir -ChildPath 'ProvisioningPackages'
$DirShellLauncherSettings = Join-Path -Path $DirAssignedAccess -ChildPath 'ShellLauncher'
$DirGPO = Join-Path -Path $Script:Dir -ChildPath "GPOs"
$DirKiosk = Join-Path -Path $env:SystemDrive -ChildPath "KioskSettings"
$DirTools = Join-Path -Path $Script:Dir -ChildPath "Tools"
$DirFunctions = Join-Path -Path $Script:Dir -ChildPath "Scripts\Functions"
$DirSchedTasksScripts = Join-Path -Path $Script:Dir -ChildPath "Scripts\ScheduledTasks"
  
#region Load Functions

If (Test-Path -Path $DirFunctions) {
    $Functions = Get-ChildItem -Path $DirFunctions -Filter '*.ps1'
    ForEach ($Function in $Functions) {
        Try {
            . "$($Function.FullName)"
        }
        Catch {
            Write-Error "Failed to load function from $($Function.FullName): $($_.Exception.Message)"
            Exit 1
        }
    }
}
Else {
    Write-Error "Functions directory not found at: $DirFunctions"
    Exit 1
}

#endregion Functions

#region Initialization

If (-not [System.Diagnostics.EventLog]::SourceExists($EventSource) -or -not [System.Diagnostics.EventLog]::Exists($EventLog)) {
    Write-Verbose "Creating $EventLog | $EventSource log..."
    New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
    Do {
        Start-Sleep -Seconds 1
    } Until ([System.Diagnostics.EventLog]::SourceExists($EventSource) -and [System.Diagnostics.EventLog]::Exists($EventLog))
}

If (-not [System.Diagnostics.EventLog]::SourceExists('AutoLogoff')) {
    New-EventLog -LogName $EventLog -Source 'AutoLogoff' -ErrorAction SilentlyContinue
}

$message = @"
Starting Windows App Kiosk Configuration Script
Script Full Name: $($Script:FullName)
Parameters:
    $($PSBoundParameters | Out-String)
Running on: $($OS.Caption) version $FullOSVersion
"@
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 1 -Message $message

If (Get-PendingReboot) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 0 -Message "There is a reboot pending. This application cannot be installed when a reboot is pending.`nRebooting the computer in 15 seconds."
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 15' -NoNewWindow
    Exit
}

# Copy lgpo to system32 for future use.
Copy-Item -Path "$DirTools\lgpo.exe" -Destination "$env:SystemRoot\System32" -Force

#endregion Initialization

#region Parameter Conversions
If ($ConfigureAutomaticMaintenance) {
    # Convert MaintenanceRandomDelay integer to PT4H format
    $MaintenanceRandomDelayPT = "PT$($MaintenanceRandomDelay)H"
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 4 -Message "Converted MaintenanceRandomDelay of $MaintenanceRandomDelay hours to ISO 8601 duration format: $MaintenanceRandomDelayPT"
    # Convert MaintenanceActivationTime to ISO 8601 format with date 2000-01-01T
    $MaintenanceActivationTimeISO = "2000-01-01T$MaintenanceActivationTime"
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 5 -Message "Converted MaintenanceActivationTime of $MaintenanceActivationTime to ISO 8601 format: $MaintenanceActivationTimeISO"
}
#endregion Parameter Conversions

#region Validate and Update AllowedUrls

# Ensure critical protocol URLs are always included for Windows App functionality
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 2 -Message "Validating AllowedUrls parameter to ensure required protocol handlers for Windows App functionality are included."
$RequiredProtocols = @('ms-avd://*', 'ms-cloudpc://*', 'workspaces://*', 'evo://*')
foreach ($protocol in $RequiredProtocols) {
    if ($AllowedUrls -notcontains $protocol) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 3 -Message "Adding required protocol '$protocol' to AllowedUrls"
        $AllowedUrls += $protocol
    }
} 
# Ensure the KioskUrl is included in AllowedUrls (if not already covered by a filter pattern)

$KioskUrlCovered = $false
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information 73 -Message "Checking if KioskUrl '$KioskUrl' is already covered by existing AllowedUrls patterns or explicitly included in the list."
# Check if KioskUrl is already explicitly in the list
if ($AllowedUrls -contains $KioskUrl) {
    $KioskUrlCovered = $true
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information 74 -Message "KioskUrl '$KioskUrl' is already explicitly in AllowedUrls"
}

# Check if KioskUrl is covered by any filter patterns using Edge URL filter format rules
# Reference: https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format
if (-not $KioskUrlCovered) {
    $KioskUrlCovered = Test-UrlCoveredByFilter -Url $KioskUrl -AllowedUrls $AllowedUrls
}

# If not covered, add it explicitly
if (-not $KioskUrlCovered) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information 74 -Message "KioskUrl '$KioskUrl' is not covered by existing AllowedUrls patterns. Adding it explicitly to the list."
    $AllowedUrls += $KioskUrl
} Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information 74 -Message "KioskUrl '$KioskUrl' is already covered by existing AllowedUrls patterns"
}

#endregion Validate and Update AllowedUrls

#region Remove Previous Versions

If ($RemoveLegacySettings) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 10 -Message "RemoveLegacySettings switch detected. Legacy kiosk configurations will be removed before applying new configuration."
    $LegacyRemovalScript = Join-Path -Path $Script:Dir -ChildPath "Remove-LegacyKioskSettings.ps1"
    If (Test-Path -Path $LegacyRemovalScript) {
        & $LegacyRemovalScript
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 11 -Message "Legacy kiosk settings removal completed."
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 12 -Message "Remove-LegacyKioskSettings.ps1 not found at expected location."
    }
}

If ($RemoveExistingSettings) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 13 -Message "RemoveExistingSettings switch detected. Existing Windows App kiosk settings will be removed before applying new configuration."
    $RemovalScript = Join-Path -Path $Script:Dir -ChildPath "Remove-WindowsAppKioskSettings.ps1"
    If (Test-Path -Path $RemovalScript) {
        & $RemovalScript -Reinstall
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 14 -Message "Windows App kiosk settings removal completed."
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 15 -Message "Remove-WindowsAppKioskSettings.ps1 not found at expected location."
    }
}

#endregion Previous Version Removal

#region Remove Apps

# Remove Built-in Windows 11 Apps on non LTSC builds of Windows
If (-not $LTSC) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 20 -Message "Starting Remove Apps Script."
    Remove-BuiltInApps
}
# Remove OneDrive
If (Test-Path -Path "$env:SystemRoot\Syswow64\onedrivesetup.exe") {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 21 -Message "Removing Per-User installation of OneDrive."
    Start-Process -FilePath "$env:SystemRoot\Syswow64\onedrivesetup.exe" -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
    $OneDrivePresent = $true
}
ElseIf (Test-Path -Path "$env:ProgramFiles\Microsoft OneDrive") {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 22 -Message "Removing Per-Machine Installation of OneDrive."
    $OneDriveSetup = Get-ChildItem -Path "$env:ProgramFiles\Microsoft OneDrive" -Filter 'onedrivesetup.exe' -Recurse
    If ($OneDriveSetup) {
        Start-Process -FilePath $OneDriveSetup[0].FullName -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
        $OneDrivePresent = $true
    }
}

#endregion Remove Apps

#region Install Windows App

If ($InstallWindowsApp) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 30 -Message "Running Script to install or update the Windows App."
    & "$DirApps\WindowsApp\Deploy-WindowsApp.ps1"
}

#endregion Install Windows App

#region KioskSettings Directory

#Create the KioskSettings Directory
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 40 -Message "Creating KioskSettings Directory at root of system drive."
If (-not (Test-Path $DirKiosk)) {
    New-Item -Path $DirKiosk -ItemType Directory -Force | Out-Null
}

# Setting ACLs on the Kiosk Settings directory to prevent Non-Administrators from changing files. Defense in Depth.
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 41 -Message "Configuring Kiosk Directory ACLs"
$AdminsSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$Group = $AdminsSID.Translate([System.Security.Principal.NTAccount])
$ACL = Get-ACL $DirKiosk
$ACL.SetOwner($Group)
Set-ACL -Path $DirKiosk -AclObject $ACL
Update-ACL -Path $DirKiosk -Identity 'S-1-5-32-544' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'S-1-5-32-545' -FileSystemRights 'ReadAndExecute' -Type 'Allow'
Update-ACL -Path $DirKiosk -Identity 'S-1-5-18' -FileSystemRights 'FullControl' -Type 'Allow'
Update-ACLInheritance -Path $DirKiosk -DisableInheritance $true -PreserveInheritedACEs $false

#endregion KioskSettings Directory

# Copy Website file only if using the default local file URL
If ($KioskUrl -eq 'file:///c:/kiosksettings/index.html') {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 42 -Message "Copying Website file to KioskSettings Directory."
    Copy-Item -Path (Join-Path -Path $DirShellLauncherSettings -childPath 'index.html') -Destination "$DirKiosk\index.html" -Force
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 43 -Message "Using custom URL '$KioskUrl' for kiosk mode. Local HTML file will not be created."
}

#region Assigned Access Configuration

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 50 -Message "Starting Assigned Access Configuration Section."

$ConfigFile = Join-Path -Path $DirShellLauncherSettings -ChildPath "Edge_AutoLogon.xml"
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 51 -Message "Enabling Windows App Shell Launcher with Autologon via WMI MDM bridge. This could take several minutes."
        
$XmlFile = Join-Path -Path $DirKiosk -ChildPath "AssignedAccessShellLauncher.xml"
Copy-Item -Path $ConfigFile -Destination $XmlFile -Force

# Replace the placeholder with the actual Kiosk URL
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 52 -Message "Configuring Shell Launcher with URL: $KioskUrl"
$XmlContent = Get-Content -Path $XmlFile -Raw
$XmlContent = $XmlContent -replace '\{\{KIOSK_URL\}\}', $KioskUrl
$XmlContent | Set-Content -Path $XmlFile -Force

Set-AssignedAccessShellLauncher -FilePath $XmlFile
If (Get-AssignedAccessShellLauncher) {
    [xml]$Xml = Get-Content -Path $XmlFile
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 53 -Message "Shell Launcher configuration successfully applied."
    
    # Validate that KioskUser0 account was created (may not exist until after reboot)
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 54 -Message "Checking for KioskUser0 account creation..."
    $KioskUser = Get-LocalUser -Name 'KioskUser0' -ErrorAction SilentlyContinue
    
    If ($KioskUser) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 55 -Message "SUCCESS: KioskUser0 account exists. Assigned Access autologon should function after reboot."
        
        # Check if account has a password set (Assigned Access auto-generates one)
        # Note: Windows automatically generates a random, highly complex password stored in LSA secrets
        $UserInfo = Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='KioskUser0' AND LocalAccount=TRUE"
        If ($UserInfo.PasswordRequired) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 56 -Message "WARNING: KioskUser0 account has PasswordRequired=True. This is expected for Assigned Access autologon (Windows auto-generates a password). If autologon fails, verify that legal notices (LegalNoticeText/Caption) and InactivityTimeoutSecs are not configured."
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 57 -Message "KioskUser0 account not found yet. This is normal - the account will be created by Shell Launcher on first reboot. If account is NOT created after reboot, check: 1) Local Security Policy password settings (secedit /export /cfg C:\temp\policy.inf), 2) Domain GPO conflicts (gpresult /h C:\temp\gp.html), 3) Event Viewer for Shell Launcher errors."
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 58 -Message "Shell Launcher configuration failed. Computer should be restarted first."
    Exit 1618
}

#endregion Assigned Access Launcher

#region Provisioning Packages

$ProvisioningPackages = @()

$ProvisioningPackages += [PSCustomObject]@{
    Name    = 'DisableWindowsSpotlight.ppkg'
    Purpose = "Disable Windows Spotlight features to prevent unwanted content on lock screen and optimize performance"
}


# These settings are already included in the SharedPC provisioning package, so only add it when not using SharedPC mode.
$ProvisioningPackages += [PSCustomObject]@{
    Name    = 'DisableFirstLogonAnimation.ppkg'
    Purpose = "Disable first sign-in animation to speed up initial logon"
}
$ProvisioningPackages += [PSCustomObject]@{
    Name    = 'DisableAdvertisingId.ppkg'
    Purpose = "Disable advertising ID for privacy and to prevent targeted ads"
}


New-Item -Path "$DirKiosk\ProvisioningPackages" -ItemType Directory -Force | Out-Null
ForEach ($Package in $ProvisioningPackages) {
    $SourcePath = Join-Path -Path $DirProvisioningPackages -ChildPath $Package.Name
    $DestPath = Join-Path -Path $DirKiosk -ChildPath "ProvisioningPackages\$($Package.Name)"
    Copy-Item -Path $SourcePath -Destination $DestPath -Force | Out-Null
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 60 -Message "Installing $($Package.Name). Purpose: $($Package.Purpose)"
    Install-ProvisioningPackage -PackagePath $DestPath -ForceInstall -QuietInstall
}

#endregion Provisioning Packages

#region Local GPO Settings

# Copy ADMX files to PolicyDefinitions folder
$DirADMXSource = Join-Path -Path $DirGPO -ChildPath 'admx'
$AdmxFiles = Get-ChildItem -Path $DirADMXSource -Filter "*.admx" -File
foreach ($AdmxFile in $AdmxFiles) {
    Copy-Item -Path $AdmxFile.FullName -Destination "$env:SystemRoot\PolicyDefinitions" -Force
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 68 -Message "Copied $($AdmxFile.Name) to PolicyDefinitions folder."
}

# Copy ADML files to PolicyDefinitions\en-US folder
$AdmlPath = Join-Path -Path $DirADMXSource -ChildPath "en-US"
if (Test-Path -Path $AdmlPath) {
    $PolicyDefEnUS = "$env:SystemRoot\PolicyDefinitions\en-US"
    $AdmlFiles = Get-ChildItem -Path $AdmlPath -Filter "*.adml" -File
    foreach ($AdmlFile in $AdmlFiles) {
        Copy-Item -Path $AdmlFile.FullName -Destination $PolicyDefEnUS -Force
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 69 -Message "Copied $($AdmlFile.Name) to PolicyDefinitions\en-US folder."
    }
}

$null = cmd /c lgpo.exe /t "$DirGPO\AllowedOrigins.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 70 -Message "Configured ms-avd or ms-cloudpc url protocol to launch windows app automatically via Local Group Policy Machine Settings.`nlgpo.exe Exit Code: [$LastExitCode]"

# Generate Edge URLAllowlist configuration dynamically based on parameter
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 71 -Message "Generating Edge URLAllowlist for: $($AllowedUrls -join ', ')"

# Start with base Edge settings from static file
$EdgeContent = Get-Content -Path "$DirGPO\Edge.txt" -Raw

# Append URLBlocklist configuration
$EdgeContent += @(
    "",
    "User:Non-Administrators",
    "SOFTWARE\Policies\Microsoft\Edge\URLBlocklist",
    "*",
    "DELETEALLVALUES",
    "",
    "User:Non-Administrators",
    "SOFTWARE\Policies\Microsoft\Edge\URLBlocklist",
    "1",
    "SZ:*"
)
# Append URLAllowlist configuration
$EdgeContent += @(
    "",
    "User:Non-Administrators",
    "SOFTWARE\Policies\Microsoft\Edge\URLAllowlist",
    "*",
    "DELETEALLVALUES"
)
# Add each allowed URL to the allowlist
$urlIndex = 1
foreach ($url in $AllowedUrls) {
    $EdgeContent += @(
        "",
        "User:Non-Administrators",
        "SOFTWARE\Policies\Microsoft\Edge\URLAllowlist",
        "$urlIndex",
        "SZ:$url"
    )
    $urlIndex++
}

$EdgeFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'Edge.txt'
$EdgeContent | Out-File -FilePath $EdgeFile -Encoding ascii -Force

$null = cmd /c lgpo.exe /t "$EdgeFile" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 72 -Message "Configuring Microsoft Edge policies via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
Remove-Item -Path $EdgeFile -Force -ErrorAction SilentlyContinue

$null = cmd /c lgpo.exe /t "$DirGPO\Ctrl+Alt+Del-HideTaskManager.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 80 -Message "Disabled Task Manager via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"

$null = cmd /c lgpo.exe /t "$DirGPO\HideAndRestrictDrives.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 81 -Message "Hid and restricted access to drives via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    
$null = cmd /c lgpo.exe /t "$DirGPO\Ctrl+Alt+Del-HideLock-HideSignOut-HideSwitchUser.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 82 -Message "Removed logoff, change password, lock workstation, and fast user switching entry points via Local Group Policy Non-Administrators Settings.`nlgpo.exe Exit Code: [$LastExitCode]"  

$null = cmd /c lgpo.exe /t "$DirGPO\DisablePrivacyExperience.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 83 -Message "Disabled the First Logon Privacy Experience via the Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    
$null = cmd /c lgpo.exe /t "$DirGPO\DisablePasswordForUnlock.txt" '2>&1'
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 84 -Message "Disabled password requirement for screen saver lock and wake from sleep via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"

# Check for Group Policy settings that actually break S4U autologon
# NOTE: Password policies do NOT break S4U autologon (verified 2026-02-25)
# S4U autologon stores password in LSA secrets and Windows manages it automatically
# Reference: https://learn.microsoft.com/en-us/windows/win32/secauthn/protecting-the-automatic-logon-password
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 87 -Message "Checking for Group Policy settings that break S4U autologon (legal notices and inactivity timeout)."

# Check for legal notices (these BREAK autologon)
$LegalNoticeText = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LegalNoticeText" -ErrorAction SilentlyContinue
$LegalNoticeCaption = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LegalNoticeCaption" -ErrorAction SilentlyContinue
$InactivityTimeout = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "InactivityTimeoutSecs" -ErrorAction SilentlyContinue

$AutologonBlockers = @()

If ($LegalNoticeText.LegalNoticeText -and $LegalNoticeText.LegalNoticeText.Length -gt 0) {
    $AutologonBlockers += "LegalNoticeText (Interactive logon: Message text for users attempting to log on)"
}

If ($LegalNoticeCaption.LegalNoticeCaption -and $LegalNoticeCaption.LegalNoticeCaption.Length -gt 0) {
    $AutologonBlockers += "LegalNoticeCaption (Interactive logon: Message title for users attempting to log on)"
}

If ($InactivityTimeout.InactivityTimeoutSecs -and $InactivityTimeout.InactivityTimeoutSecs -gt 0) {
    $AutologonBlockers += "InactivityTimeoutSecs (Interactive logon: Machine inactivity limit) = $($InactivityTimeout.InactivityTimeoutSecs) seconds"
}

If ($AutologonBlockers.Count -gt 0) {
    $BlockersList = $AutologonBlockers -join "; "
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 88 -Message "WARNING: The following Group Policy settings WILL BREAK Assigned Access autologon: $BlockersList. These settings require interactive user acknowledgment and prevent automatic sign-in. Create a GPO exemption for kiosk devices or set these values to empty/disabled. Reference: https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon"
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 89 -Message "No autologon-blocking Group Policy settings detected (legal notices and inactivity timeout are not configured)."
}

# Check for domain membership and warn about potential GPO conflicts
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
If ($ComputerSystem.PartOfDomain) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Warning -EventId 91 -Message "This system is domain-joined. Domain Group Policies for legal notices (LegalNoticeText/LegalNoticeCaption) or machine inactivity timeout will prevent Assigned Access autologon. Password policies (complexity, length, age) are fully compatible with Assigned Access and do not need exemptions. Work with your domain administrator to create GPO exemptions for kiosk devices if autologon fails."
}

If ($ConfigureAutomaticMaintenance) {
    # Configure Automatic Maintenance settings via Local Group Policy
    $sourceFile = Join-Path -Path $DirGPO -ChildPath 'AutomaticMaintenance.txt'
    $outFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'AutomaticMaintenance.txt'
    
    If ($MaintenanceRandomDelay -eq 0) {
        # No random delay - just replace activation boundary
        ((Get-Content -Path $SourceFile).Replace('<ActivationBoundary>', $MaintenanceActivationTimeISO)) | Out-File $OutFile
    }
    Else {
        # Include random delay - replace both values and add randomized setting
        $content = (Get-Content -Path $SourceFile).Replace('<ActivationBoundary>', $MaintenanceActivationTimeISO)
        $content += @(
            "",
            "Computer",
            "Software\Policies\Microsoft\Windows\Task Scheduler\Maintenance",
            "Randomized",
            "DWORD:1",
            "",
            "Computer",
            "Software\Policies\Microsoft\Windows\Task Scheduler\Maintenance",
            "RandomDelay",
            "SZ:$MaintenanceRandomDelayPT"
        )
        $content | Out-File $OutFile
    }    
    $null = cmd /c lgpo /s "$outFile" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 85 -Message "Configured Automatic Maintenance settings via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue
}

If ($SetPowerPolicies) {
    # Configure Power Settings via Local Group Policy
    $sourceFile = Join-Path -Path $DirGPO -ChildPath 'PowerSettings.txt'
    $outFile = Join-Path -Path "$env:SystemRoot\SystemTemp" -ChildPath 'PowerSettings.txt'
    (Get-Content -Path $SourceFile).Replace('<SleepTimeOut>', ($IdleSleepTimeoutMinutes * 60)) | Out-File $OutFile
    $null = cmd /c lgpo /s "$outFile" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 86 -Message "Configured Power Settings with idle sleep timeout = $IdleSleepTimeoutMinutes minutes via Local Group Policy Computer Settings.`nlgpo.exe Exit Code: [$LastExitCode]"
    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 120 -Message "Configuring Non-Administrators Group Policy logon/logoff scripts."

# Get the SID for the BUILTIN\Users group (Non-Administrators)
$UsersGroup = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$UsersSID = $UsersGroup.Value

# Create Group Policy Users folder structure for Non-Administrators
$GPUsersBase = "$env:SystemRoot\System32\GroupPolicyUsers\$UsersSID"
$GPUserScripts = "$GPUsersBase\User\Scripts"
$GPUserLogonScripts = "$GPUserScripts\Logon"
$GPUserLogoffScripts = "$GPUserScripts\Logoff"

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 121 -Message "Creating Group Policy folder structure for Non-Administrators at: $GPUsersBase"

# Create directories if they don't exist
@($GPUsersBase, "$GPUsersBase\User", $GPUserScripts, $GPUserLogonScripts, $GPUserLogoffScripts) | ForEach-Object {
    If (-not (Test-Path -Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# Create the logon script batch file to launch LocalUserlogoff.vbs
$LogonScriptName = "LaunchCitrixConnectionMonitor.bat"
$LogonScriptPath = Join-Path -Path $GPUserLogonScripts -ChildPath $LogonScriptName
$LogonScriptContent = @"
@echo off
REM Launch user logoff monitoring script
cscript.exe //B //Nologo "C:\Program Files\Kiosk Portal\LocalUserlogoff.vbs"
exit /b 0
"@

Set-Content -Path $LogonScriptPath -Value $LogonScriptContent -Encoding ASCII -Force
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 122 -Message "Created logon script at: $LogonScriptPath"

# Create the logoff script batch file for certificate cleanup
$LogoffScriptName = "ClearCertificates.bat"
$LogoffScriptPath = Join-Path -Path $GPUserLogoffScripts -ChildPath $LogoffScriptName
$LogoffScriptContent = @"
@echo off
REM Certificate cleanup script for Non-Administrators
certutil.exe -user -delstore MY *.* >nul 2>&1
exit /b 0
"@

Set-Content -Path $LogoffScriptPath -Value $LogoffScriptContent -Encoding ASCII -Force
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 123 -Message "Created logoff script at: $LogoffScriptPath"

# Create scripts.ini file with both logon and logoff scripts
$ScriptsIniPath = Join-Path -Path $GPUserScripts -ChildPath "scripts.ini"
$ScriptsIniContent = @"
[Logon]
0CmdLine=$LogonScriptName
0Parameters=

[Logoff]
0CmdLine=$LogoffScriptName
0Parameters=
"@

Set-Content -Path $ScriptsIniPath -Value $ScriptsIniContent -Encoding Unicode -Force
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 124 -Message "Created scripts.ini at: $ScriptsIniPath"

# Force Group Policy update to apply the logon/logoff scripts
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 125 -Message "Forcing Group Policy update to apply logon/logoff script configuration."
$GPUpdateResult = Start-Process -FilePath 'gpupdate.exe' -ArgumentList '/force' -Wait -PassThru -NoNewWindow
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 126 -Message "Group Policy update completed with exit code: $($GPUpdateResult.ExitCode)"

#endregion Local GPO Settings

#region Registry Edits

# Import registry keys file
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 90 -Message "Setting Registry Keys."
$RegValues = @()

$RegValues += [PSCustomObject]@{
    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
    Name         = 'BlockAADWorkplaceJoin'
    PropertyType = 'DWord'
    Value        = 1
    Description  = 'Disable "Stay Signed in to all your apps" pop-up'
}

If ($OneDrivePresent) {
    # Remove OneDrive from starting for each user.
    $RegValues += [PSCustomObject]@{
        Path         = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        Name         = 'OneDriveSetup'
        PropertyType = 'String'
        Value        = ''
        Description  = 'Remove OneDriveSetup from starting for each user.'
    }
}

if ($WindowsAppAutoLogoffConfig -ne 'Disabled') {
    # Streamline the user experience by disabling First Run Experience
    # https://learn.microsoft.com/en-us/windows-app/windowsautologoff#skipfre
    $RegValues += [PSCustomObject]@{
        Path         = 'HKLM:\SOFTWARE\Microsoft\Windows365'
        Name         = 'SkipFRE'
        PropertyType = 'DWord'
        Value        = 1
        Description  = 'Disable First Run Experience in Windows App'
    }
}

#Configure AutoLogoff for the Windows App
#https://learn.microsoft.com/en-us/windows-app/windowsautologoff
Switch ($WindowsAppAutoLogoffConfig) {
    'ResetAppOnCloseOnly' {
        $RegValues += [PSCustomObject]@{
            Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
            Name         = 'AutoLogoffEnable'
            PropertyType = 'DWORD'
            Value        = 1
            Description  = 'Sign all users out of Windows App and reset app data when the user closes the app.'
        }
    }
    'ResetAppAfterConnection' {
        $RegValues += [PSCustomObject]@{
            Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
            Name         = 'AutoLogoffOnSuccessfulConnect'
            PropertyType = 'DWord'
            Value        = 1
            Description  = 'Sign all users out of Windows App and reset app data when a successful connection to an Azure Virtual Desktop session host or Windows 365 Cloud PC is made.'
        }
    }
    'ResetAppOnCloseOrIdle' {
        $RegValues += [PSCustomObject]@{
            Path         = 'HKLM:\SOFTWARE\Microsoft\WindowsApp'
            Name         = 'AutoLogoffTimeInterval'
            PropertyType = 'DWord'
            Value        = $WindowsAppAutoLogoffTimeInterval
            Description  = 'Sign all users out of Windows App and reset app data when the operating system is idle for the specified time interval in minutes or the user closes the app.'
        }     
    }
}

# create the reg key restore file if it doesn't exist, else load it to compare for appending new rows.
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 91 -Message "Creating a Registry key restore file for Kiosk Mode uninstall."
$FileRestore = "$DirKiosk\RegKeyRestore.csv"
New-Item -Path $FileRestore -ItemType File -Force | Out-Null
Add-Content -Path $FileRestore -Value 'Path,Name,PropertyType,Value,Description'

# Check if any registry keys require HKCU access before loading the hive     
If ($RegValues | Where-Object { $_.Path -like 'HKCU:*' }) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 92 -EntryType Information -Message "Loading Default User Hive for HKCU registry operations."
    Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\Default", "$env:SystemDrive\Users\default\ntuser.dat" -Wait
}

# Loop through the registry key file and perform actions.
ForEach ($Entry in $RegValues) {
    #reset from previous values
    $Path = $null
    $Name = $null
    $PropertyType = $null
    $Value = $null
    $Description = $Null
    $PathHKLM = $Null
    #set values
    $Path = $Entry.Path
    $Name = $Entry.Name
    $PropertyType = $Entry.PropertyType
    $Value = $Entry.Value
    $Description = $Entry.Description
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 93 -Message "Processing Registry Value to '$Description'."

    If ($Path -like 'HKCU:*') {
        $PathHKLM = $Path.Replace("HKCU:\", "HKLM:\Default\")
    }
    Else {
        $PathHKLM = $Path
    }
    $CurrentRegValue = $null
    If (Get-ItemProperty -Path $PathHKLM -Name $Name -ErrorAction SilentlyContinue) {
        $CurrentRegValue = Get-ItemPropertyValue -Path $PathHKLM -Name $Name
        Add-Content -Path $FileRestore -Value "$Path,$Name,$PropertyType,$CurrentRegValue"
    }
    Else {
        Add-Content -Path $FileRestore -Value "$Path,$Name,,"
    }

    If ($Value -ne '' -and $null -ne $Value) {
        # This is a set action
        Set-RegistryValue -Path $PathHKLM -Name $Name -PropertyType $PropertyType -Value $Value       
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 94 -Message "Setting '$PropertyType' Value '$Name' with Value '$Value' to '$Path'"
    }
    Elseif ($CurrentRegValue) {     
        Remove-ItemProperty -Path $PathHKLM -Name $Name -ErrorAction SilentlyContinue
        Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 95 -Message "Deleted Value '$Name' from '$Path'."
    }               
}    

If (Test-Path -Path 'HKLM:\Default') {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 96 -Message "Unloading Default User Hive Registry Keys via Reg.exe."
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 5
    $null = cmd /c REG UNLOAD "HKLM\Default" '2>&1'
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 97 -Message "Reg.exe Exit Code: [$LastExitCode]"
}

#endregion Registry Edits


#region AppLocker Configuration

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 110 -Message "Applying AppLocker Policy to disable Edge, Notepad, and Search for the Kiosk User."
# If there is an existing applocker policy, back it up and store its XML for restore.
# Else, copy a blank policy to the restore location.
# Then apply the new AppLocker Policy
$FileAppLockerKiosk = Join-Path -Path $DirAppLocker -ChildPath "ShellLauncher.xml"

[xml]$Policy = Get-ApplockerPolicy -Local -XML
If ($Policy.AppLockerPolicy.RuleCollection) {
    Get-ApplockerPolicy -Local -XML | out-file "$DirKiosk\ApplockerPolicy.xml" -force
}
Else {
    Copy-Item -Path $FileAppLockerClear -Destination "$DirKiosk\ApplockerPolicy.xml" -Force
}
Set-AppLockerPolicy -XmlPolicy $FileAppLockerKiosk
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 111 -Message "Enabling and Starting Application Identity Service"
Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction SilentlyContinue
#endregion AppLocker Configuration

#region Keyboard Filter
$SchedTasksScriptsDir = Join-Path -Path $DirKiosk -ChildPath 'ScheduledTasksScripts'

If (-not (Test-Path -Path $SchedTasksScriptsDir)) {
    New-Item -Path $SchedTasksScriptsDir -ItemType Directory -Force | Out-Null
}
$TaskScriptName = 'Set-KeyboardFilterConfiguration.ps1'
Copy-Item -Path (Join-Path -Path $DirSchedTasksScripts -ChildPath $TaskScriptName) -Destination $SchedTasksScriptsDir -Force
$TaskScriptFullName = Join-Path -Path $SchedTasksScriptsDir -ChildPath $TaskScriptName
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 127 -Message "Enabling Keyboard filter."
Enable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -All -NoRestart
# Configure Keyboard Filter after reboot
$TaskName = "Windows-App-Kiosk - Configure Keyboard Filter"
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 128 -Message "Creating Scheduled Task: '$TaskName'."
$TaskScriptEventSource = 'Keyboard Filter Configuration'
$TaskDescription = "Configures the Keyboard Filter"
New-EventLog -LogName $EventLog -Source $TaskScriptEventSource -ErrorAction SilentlyContinue     
$TaskTrigger = New-ScheduledTaskTrigger -AtStartup
$TaskScriptArgs = "-TaskName `"$TaskName`" -EventLog `"$EventLog`" -EventSource `"$TaskScriptEventSource`""
$TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-executionpolicy bypass -file $TaskScriptFullName $TaskScriptArgs"
$TaskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$TaskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $TaskAction -Settings $TaskSettings -Principal $TaskPrincipal -Trigger $TaskTrigger
If (Get-ScheduledTask | Where-Object { $_.TaskName -eq "$TaskName" }) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 129 -Message "Scheduled Task created successfully."
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Error -EventId 130 -Message "Scheduled Task not created."
    Exit 1618
}

#endregion Keyboard Filter

Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 150 -Message "Updating Group Policy"
$GPUpdate = Start-Process -FilePath 'GPUpdate' -ArgumentList '/force' -Wait -PassThru
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventID 151 -Message "GPUpdate Exit Code: [$($GPUpdate.ExitCode)]"
$null = cmd /c reg add 'HKLM\Software\Kiosk' /v Version /d "$($Version.ToString())" /t REG_SZ /f
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 199 -Message "Ending Kiosk Mode Configuration version '$($Version.ToString())' with Exit Code: 3010"
Exit 3010
