<#
.SYNOPSIS
    Deploys or uninstalls Windows App with optional auto logoff configuration.

.DESCRIPTION
    This script provisions or removes the Windows App (Microsoft.Windows365) on Windows devices.
    It supports automatic download of the latest version or offline installation from a local MSIX file.
    The script also configures Windows App auto logoff settings to manage user sessions and app data
    based on inactivity, app closure, or successful connections.
    
    DEPLOYMENT METHODOLOGY:
    - For NEW users: Provisions the app so it's automatically registered on first logon
    - For EXISTING users: Configures Active Setup to register the app at next logon
    - Active Setup runs once per user per version, ensuring all users get the latest provisioned version
    
    UPGRADE SUPPORT:
    When you re-run this script with a newer Windows App version:
    - The provisioned package is updated
    - Active Setup version is automatically updated to match the provisioned package version
    - All existing users will get the updated version at their next logon
    - Active Setup's built-in version tracking ensures it runs only once per user per version
    
    For offline deployments, you can download the Windows App package including dependencies using:
    winget download --id 9N1F85V9T8BN --architecture=x64 -d <destination-folder> --accept-package-agreements --accept-source-agreements --skip-license
    
    This winget command downloads the MSIX package and the latest dependency files, ensuring you have
    the most up-to-date versions for offline installation.

.PARAMETER DeploymentType
    Specifies the deployment action. Valid values are 'Install' (default) or 'Uninstall'.

.PARAMETER AutoLogoffConfig
    Configures the auto logoff behavior for Windows App. Valid values:
    - Disabled (default): No auto logoff behavior
    - ResetAppOnCloseOnly: Logs off and resets when the app is closed
    - ResetAppAfterConnection: Logs off and resets after successful connection to a resource
    - ResetAppOnCloseOrIdle: Logs off on app close OR after idle timeout

.PARAMETER AutoLogoffTimeInterval
    Specifies the idle timeout interval in minutes (1-1440). Default is 60 minutes.
    Required when AutoLogoffConfig is set to 'ResetAppOnCloseOrIdle'.
    Windows App checks OS inactivity signals at this interval.

.PARAMETER SkipFirstRunExperience
    When specified, skips the First Run Experience (FRE) after Windows App is launched.
    Recommended for kiosk scenarios to streamline the user experience.

.PARAMETER DisableAutomaticUpdates
    Controls automatic updates for Windows App. Valid values (0-3):
    - 0 (default): Enable updates
    - 1: Disable updates
    - 2: Disable updates from the Microsoft Store
    - 3: Disable updates from the CDN location
    For more information, see: https://learn.microsoft.com/en-us/windows-app/configure-updates-windows

.EXAMPLE
    .\Deploy-WindowsApp.ps1
    Installs Windows App with default settings (no auto logoff configured).

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppOnCloseOnly -SkipFirstRunExperience
    Installs Windows App and configures it to reset only when the app is closed, skipping FRE.

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppAfterConnection -SkipFirstRunExperience
    Installs Windows App and configures it to reset after a successful connection to a resource.

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppOnCloseOrIdle -AutoLogoffTimeInterval 15 -SkipFirstRunExperience
    Installs Windows App with 15-minute idle timeout. Resets on app close or after 15 minutes of OS inactivity.

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -DeploymentType Uninstall
    Uninstalls Windows App from the system.

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 1 -SkipFirstRunExperience
    Installs Windows App with automatic updates disabled.

.EXAMPLE
    .\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 2 -SkipFirstRunExperience
    Installs Windows App with updates from Microsoft Store disabled.

.EXAMPLE
    .\Deploy-WindowsApp.ps1
    Run this again with a newer MSIX file to upgrade Windows App.
    The provisioned package is updated and Active Setup triggers registration for all existing users at their next logon.

.NOTES
    File Name      : Deploy-WindowsApp.ps1
    Prerequisite   : Windows 10/11 with AppX support
    Copyright      : Microsoft Corporation
    
    Registry Keys Configured:
    - HKLM:\SOFTWARE\Microsoft\WindowsApp
      - AutoLogoffEnable (DWORD): 0=Disabled, 1=Enabled
      - AutoLogoffOnSuccessfulConnect (DWORD): 1=Reset after connection
      - AutoLogoffTimeInterval (DWORD): Idle interval in minutes
      - DisableAutomaticUpdates (DWORD): 0=Enable updates, 1=Disable updates, 2=Disable Store updates, 3=Disable CDN updates
    - HKLM:\SOFTWARE\Microsoft\Windows365
      - SkipFRE (DWORD): 1=Skip First Run Experience
    - HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{B5F6E1A9-4D79-4C1F-9D8B-7E2F4A3C6D8E}
      - Version (String): Provisioned package version (e.g., "1.24324.2316.0")
      - StubPath (ExpandString): Command to register Windows App for each user
      - Note: Active Setup runs once per user when HKLM Version differs from HKCU Version
    
    Active Setup Behavior:
    - Automatically registers Windows App for existing users at next logon
    - Runs once per user per provisioned version
    - Windows manages version tracking in each user's HKCU registry
    - Upgrading the provisioned package triggers re-registration for all users

.LINK
    https://learn.microsoft.com/en-us/windows-app/overview

.LINK
    https://learn.microsoft.com/en-us/windows-app/windowsautologoff

.LINK
    https://learn.microsoft.com/en-us/windows-app/configure-updates-windows

.LINK
    https://helgeklein.com/blog/active-setup-explained/
#>

Param
(
    [Parameter(Mandatory = $false)]
    [string]$DeploymentType = "Install",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Disabled', 'ResetAppOnCloseOnly', 'ResetAppAfterConnection', 'ResetAppOnCloseOrIdle')]
    [string]$AutoLogoffConfig = 'Disabled',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1440)]
    [int]$AutoLogoffTimeInterval = 60,

    [Parameter(Mandatory = $false)]
    [switch]$SkipFirstRunExperience,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 3)]
    [int]$DisableAutomaticUpdates = 0
)

#region Initialization

$SoftwareName = 'Windows App'
$Url = 'https://go.microsoft.com/fwlink/?linkid=2262633'
$Script:FullName = $MyInvocation.MyCommand.Path
$Script:File = $MyInvocation.MyCommand.Name
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($Script:File)
$Script:Args = $null
$Script:LogDir = Join-Path -Path "$Env:SystemRoot\Logs" -ChildPath 'Software'
$Script:TempDir = "$env:SystemRoot\SystemTemp"


If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {

        foreach ($k in $MyInvocation.BoundParameters.keys) {
            switch ($MyInvocation.BoundParameters[$k].GetType().Name) {
                "SwitchParameter" { if ($MyInvocation.BoundParameters[$k].IsPresent) { $Script:Args += "-$k " } }
                "String" { $Script:Args += "-$k `"$($MyInvocation.BoundParameters[$k])`" " }
                "Int32" { $Script:Args += "-$k $($MyInvocation.BoundParameters[$k]) " }
                "Boolean" { $Script:Args += "-$k `$$($MyInvocation.BoundParameters[$k]) " }
            }
        }
        If ($Script:Args) {
            Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$($Script:FullName)`" $($Script:Args)" -Wait -NoNewWindow
        }
        Else {
            Start-Process -FilePath "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -ArgumentList "-File `"$($Script:FullName)`"" -Wait -NoNewWindow
        }
    }
    Catch {
        Throw "Failed to start 64-bit PowerShell"
    }
    Exit
}

If (-not (Test-Path -Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
}

If ($DeploymentType -ne "Uninstall") {
    [string]$Script:LogName = "Install-" + ($SoftwareName -Replace ' ', '') + ".log"
    Start-Transcript -Path (Join-Path -Path $Script:LogDir -ChildPath $Script:LogName) -Force
    $CurrentVersion = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "MicrosoftCorporationII.Windows365" }
    If ($CurrentVersion) {
        Write-Output "Removing existing version of $SoftwareName"
        $CurrentVersion | Remove-AppxProvisionedPackage -Online
    }
    $MSIXPath = (Get-ChildItem -Path $PSScriptRoot -filter *.msix).FullName
    If (-not ($MSIXPath)) {
        Write-Output "Windows App MSIX package not found in $PSScriptRoot"
        Write-Output "Attempting to download from '$Url'"
        $tempDir = Join-Path -Path $Script:TempDir -ChildPath "$($Script:Name)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        $MSIXPath = Join-Path -Path $TempDir -ChildPath 'WindowsApp.msix'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $MSIXPath -UseBasicParsing
        If (Test-Path -Path $MSIXPath) {
            Write-Output "Windows App MSIX package downloaded to: $MSIXPath"
        }
        else {
            Write-Error "Windows App MSIX package not found"
            Exit 1
        }
    }
    Else {
        Write-Output "Windows App MSIX package found in $PSScriptRoot"
    }

    $DependenciesPath = (Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Dependencies") -filter *.appx).FullName

    # Provision the app for NEW users (created after this script runs)
    Write-Output "Provisioning Windows App for new user profiles"
    Add-AppxProvisionedPackage -Online -PackagePath $MSIXPath -DependencyPackagePath $DependenciesPath -SkipLicense
    
    if ($tempDir -and (Test-Path -Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Get the provisioned package version to use in Active Setup
    $ProvisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "MicrosoftCorporationII.Windows365" }
    if ($ProvisionedPackage) {
        $PackageVersion = $ProvisionedPackage.Version
        Write-Output "Provisioned package version: $PackageVersion"
    } else {
        Write-Warning "Could not retrieve provisioned package version. Using timestamp for Active Setup version."
        $PackageVersion = (Get-Date).ToString("yyyy.MM.dd.HHmm")
    }

    # Configure Active Setup to register Windows App for existing users at next logon
    Write-Output "Configuring Active Setup to register Windows App for existing users"
    
    $ActiveSetupGuid = "{B5F6E1A9-4D79-4C1F-9D8B-7E2F4A3C6D8E}"
    $ActiveSetupPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$ActiveSetupGuid"
    
    # Create or update Active Setup entry
    if (-not (Test-Path $ActiveSetupPath)) {
        New-Item -Path $ActiveSetupPath -Force | Out-Null
    }
    
    # The Version value is key - updating this will cause Active Setup to run again for all users
    New-ItemProperty -Path $ActiveSetupPath -Name "(Default)" -Value "Windows App Registration" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $ActiveSetupPath -Name "Version" -Value $PackageVersion -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $ActiveSetupPath -Name "StubPath" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -Command `"try { Add-AppxPackage -RegisterByFamilyName -MainPackage MicrosoftCorporationII.Windows365_8wekyb3d8bbwe -ErrorAction Stop } catch { `$_ | Out-File -FilePath `$env:LOCALAPPDATA\WindowsApp_Registration.log -Append }`"" -PropertyType ExpandString -Force | Out-Null
    
    Write-Output "Active Setup configured successfully (Version: $PackageVersion)"
    Write-Output "Windows App will be registered automatically for each existing user at their next logon"
    Write-Output "When you upgrade Windows App, re-running this script will update the version and trigger registration for all users again"

    # Configure Windows App Auto Logoff settings
    $WindowsAppRegPath = "HKLM:\SOFTWARE\Microsoft\WindowsApp"

    # Ensure registry paths exist
    if (-not (Test-Path $WindowsAppRegPath)) {
        New-Item -Path $WindowsAppRegPath -Force | Out-Null
    }

    if ($AutoLogoffConfig -and $AutoLogoffConfig -ne 'Disabled') {
        Write-Output "Configuring Windows App Auto Logoff settings..."

        switch ($AutoLogoffConfig) {
            'ResetAppOnCloseOnly' {
                Write-Output "Setting Auto Logoff to Reset App On Close Only"
                New-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffEnable" -PropertyType DWORD -Value 1 -Force | Out-Null
                # Remove other trigger settings
                Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffOnSuccessfulConnect" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffTimeInterval" -ErrorAction SilentlyContinue
            }
            'ResetAppAfterConnection' {
                Write-Output "Setting Auto Logoff to Reset App After Connection"
                New-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffOnSuccessfulConnect" -PropertyType DWORD -Value 1 -Force | Out-Null
                # AutoLogoffEnable is automatically enabled when AutoLogoffOnSuccessfulConnect is set
                Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffEnable" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffTimeInterval" -ErrorAction SilentlyContinue
            }
            'ResetAppOnCloseOrIdle' {
                if (-not $AutoLogoffTimeInterval) {
                    Write-Error "AutoLogoffTimeInterval parameter is required when AutoLogoffConfig is set to 'ResetAppOnCloseOrIdle'"
                    Exit 1
                }
                Write-Output "Setting Auto Logoff to Reset App On Close Or Idle (Interval: $AutoLogoffTimeInterval minutes)"
                New-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffEnable" -PropertyType DWORD -Value 1 -Force | Out-Null
                New-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffTimeInterval" -PropertyType DWORD -Value $AutoLogoffTimeInterval -Force | Out-Null
                # Remove AutoLogoffOnSuccessfulConnect if it exists
                Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffOnSuccessfulConnect" -ErrorAction SilentlyContinue
            }
        }
    }

    # Configure DisableAutomaticUpdates
    Write-Output "Configuring Windows App automatic updates (DisableAutomaticUpdates=$DisableAutomaticUpdates)"
    New-ItemProperty -Path $WindowsAppRegPath -Name "DisableAutomaticUpdates" -PropertyType DWORD -Value $DisableAutomaticUpdates -Force | Out-Null

    # Configure SkipFRE if specified
    $Windows365RegPath = "HKLM:\SOFTWARE\Microsoft\Windows365"
    if ($SkipFirstRunExperience) {
        Write-Output "Configuring Windows App to skip First Run Experience"
        if (-not (Test-Path $Windows365RegPath)) {
            New-Item -Path $Windows365RegPath -Force | Out-Null
        }
        New-ItemProperty -Path $Windows365RegPath -Name "SkipFRE" -PropertyType DWORD -Value 1 -Force | Out-Null
    }
    else {
        # Ensure FRE is enabled (default behavior)
        if (Test-Path $Windows365RegPath) {
            Remove-ItemProperty -Path $Windows365RegPath -Name "SkipFRE" -ErrorAction SilentlyContinue
        }
    } 

    Write-Output "Windows App configuration completed successfully"
}
Else {
    [string]$Script:LogName = "Uninstall" + ($SoftwareName -Replace ' ', '') + ".log"
    Start-Transcript -Path (Join-Path -Path $Script:LogDir -ChildPath $Script:LogName) -Force
    
    # Remove Windows App
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "MicrosoftCorporationII.Windows365" } | Remove-AppxProvisionedPackage -Online
    
    # Remove Active Setup entry
    Write-Output "Removing Windows App Active Setup registration..."
    $ActiveSetupGuid = "{B5F6E1A9-4D79-4C1F-9D8B-7E2F4A3C6D8E}"
    $ActiveSetupPath = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$ActiveSetupGuid"
    if (Test-Path $ActiveSetupPath) {
        Remove-Item -Path $ActiveSetupPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Removed Active Setup entry"
    }
    
    # Remove Auto Logoff registry keys
    Write-Output "Removing Windows App Auto Logoff registry settings..."
    $WindowsAppRegPath = "HKLM:\SOFTWARE\Microsoft\WindowsApp"
    $Windows365RegPath = "HKLM:\SOFTWARE\Microsoft\Windows365"
    
    if (Test-Path $WindowsAppRegPath) {
        Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffEnable" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffOnSuccessfulConnect" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $WindowsAppRegPath -Name "AutoLogoffTimeInterval" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $WindowsAppRegPath -Name "DisableAutomaticUpdates" -ErrorAction SilentlyContinue
        Write-Output "Removed Auto Logoff and update settings from Windows App registry key"
    }
    
    if (Test-Path $Windows365RegPath) {
        Remove-ItemProperty -Path $Windows365RegPath -Name "SkipFRE" -ErrorAction SilentlyContinue
        Write-Output "Removed SkipFRE setting from Windows 365 registry key"
    }
}

Stop-Transcript