# Edge-Based Windows App Kiosk - Implementation Guide

**Navigation:** [🏠 Overview](README.md) | [🏗️ Solution Overview](SOLUTION_OVERVIEW.md) | ⚙️ Implementation Guide | [🔒 Architecture Guide](ARCHITECTURE.md)

---

## Table of Contents

- [Parameters](#parameters)
- [Manual Installation](#manual-installation)
- [Configuration Examples](#configuration-examples)
- [Manual Removal](#manual-removal)
- [Troubleshooting](#troubleshooting)
  - [Emergency Access](#emergency-access)
  - [Logging and Diagnostics](#logging-and-diagnostics)
  - [Common Issues](#common-issues)
  - [Configuration Verification](#configuration-verification)

## Parameters

The `Set-WindowsAppFromEdgeKioskSettings.ps1` script accepts the following parameters to customize your kiosk deployment.

### Core Parameters

**Table 1:** Primary Configuration Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:--------|:------------|
| `InstallWindowsApp` | Switch | No | Not set | Automatically downloads and installs the latest Windows App from Microsoft. Supports both online (automatic download) and offline (local MSIX file) installation. For air-gapped environments, place the Windows App MSIX file in `source/Apps/WindowsApp/` directory. **See [Windows App Deployment Guide](source/Apps/WindowsApp/README.md) for detailed offline installation instructions.** |
| `WindowsAppAutoLogoffConfig` | String | **Yes** | None | Determines Windows App automatic logoff behavior. **Values:** `Disabled`, `ResetAppOnCloseOnly`, `ResetAppAfterConnection`, `ResetAppOnCloseOrIdle`. See [Solution Overview](SOLUTION_OVERVIEW.md#windows-app-auto-logoff-behaviors) for detailed behavior descriptions. **Recommended:** Use `ResetAppOnCloseOrIdle` for public kiosks. |
| `WindowsAppAutoLogoffTimeInterval` | Integer | Conditional | 15 | Interval in minutes for Windows App to check OS inactivity. **Required when** `WindowsAppAutoLogoffConfig` is set to `ResetAppOnCloseOrIdle`. The app polls every N minutes and triggers reset if N+ minutes of inactivity detected. |
| `KioskUrl` | String | No | `file:///c:/kiosksettings/Index.html` | URL that Microsoft Edge displays in kiosk mode. Can be a local file path or web URL. Default uses included HTML file with AVD/W365 launch buttons. Custom URLs should include ms-avd:// protocol links to launch Windows App. |
| `AllowedUrls` | String[] | No | Protocol handlers | Array of URLs that Microsoft Edge is **allowed to navigate to**. All other URLs are blocked. Default includes `file://*`, `ms-avd://*`, `ms-cloudpc://*`, `evo://*`, and `workspaces://*`. Supports hostname patterns (e.g., `tailspintoys.com` matches all subdomains) and wildcards. **Note:** `ms-avd://*` and `ms-cloudpc://*` are always automatically included to ensure Windows App functionality. The `KioskUrl` is also automatically included if not already covered by an existing pattern. This controls browser navigation, not protocol handler permissions. |

> [!NOTE]
> **Understanding URL Controls:**
> - **`AllowedUrls`** (URLAllowlist) - Controls which URLs Edge **can navigate to**. This is a browser navigation restriction.
> - **AllowedOrigins** (AutoLaunchProtocolsFromOrigins) - Controls which websites can **auto-launch protocol handlers** (ms-avd://) without user interaction. This is configured via static file and allows all origins (`*`) by default.
> 
> Most kiosk scenarios need `AllowedUrls` to restrict browsing. The protocol origin setting is typically left at default.
>
> **Auto-Inclusion:** The script automatically ensures `ms-avd://*`, `ms-cloudpc://*`, and your specified `KioskUrl` are always in the allowlist (unless the KioskUrl is already covered by an existing pattern).
>
> **Subdomain Matching:** Per [Edge URL filter rules](https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format), a hostname like `tailspintoys.com` automatically matches ALL subdomains (e.g., `www.tailspintoys.com`, `internal.tailspintoys.com`) without needing wildcards.

### Maintenance and Power Management

**Table 2:** System Maintenance and Power Configuration Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:--------|:------------|
| `ConfigureAutomaticMaintenance` | Switch | No | Not set | Enables Windows automatic maintenance configuration via Local Group Policy. When set, Windows Update, security scanning, and disk maintenance run at scheduled times. |
| `MaintenanceActivationTime` | String | No | `00:00:00` | Time when automatic maintenance begins in HH:mm:ss format (24-hour). **Example:** `02:00:00` for 2:00 AM. Used with `ConfigureAutomaticMaintenance`. **Valid format:** `00:00:00` through `23:59:59`. |
| `MaintenanceRandomDelay` | Integer | No | 2 | Maximum random delay in hours added to maintenance start time. Prevents multiple kiosks from running maintenance simultaneously. **Valid range:** 0-6 hours. Used with `ConfigureAutomaticMaintenance`. |
| `SetPowerPolicies` | Switch | No | Not set | Configures power management policies via Local Group Policy. Sets power button actions, sleep settings, disables hibernation, enables standby states. **Requires** `IdleSleepTimeoutMinutes` parameter. |
| `IdleSleepTimeoutMinutes` | Integer | Conditional | None | Minutes of inactivity before system sleeps. **Required when** `SetPowerPolicies` is used. **Valid range:** 30-1440 minutes (30 minutes to 24 hours). |

### Cleanup and Reinstallation

**Table 3:** Removal and Cleanup Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:--------|:------------|
| `RemoveLegacySettings` | Switch | No | Not set | Removes legacy kiosk configurations from previous versions or other kiosk implementations before applying new configuration. Runs `Remove-LegacyKioskSettings.ps1` automatically. Useful when upgrading from older kiosk solutions. |
| `RemoveExistingSettings` | Switch | No | Not set | Removes existing Windows App kiosk settings before applying new configuration. Runs `Remove-WindowsAppKioskSettings.ps1` automatically with `-Reinstall` flag. Allows clean reinstallation on previously configured systems. |
| `Version` | Version | No | `1.0.0` | Version string written to `HKLM:\SOFTWARE\Kiosk\version` registry key. Allows tracking of deployed version using configuration management tools (Intune, ConfigMgr, etc.). |

### Parameter Dependencies

Some parameters have dependencies or requirements:

| Parameter | Depends On | Notes |
|:----------|:-----------|:------|
| `WindowsAppAutoLogoffTimeInterval` | `WindowsAppAutoLogoffConfig` = `ResetAppOnCloseOrIdle` | Must specify interval when using idle-based logoff |
| `IdleSleepTimeoutMinutes` | `SetPowerPolicies` switch | Sleep timeout requires power policies to be configured |
| `MaintenanceActivationTime` | `ConfigureAutomaticMaintenance` switch | Only used when automatic maintenance is enabled |
| `MaintenanceRandomDelay` | `ConfigureAutomaticMaintenance` switch | Only used when automatic maintenance is enabled |

## Manual Installation

> [!IMPORTANT]
> The PowerShell script **must be run with SYSTEM privileges** to properly configure all kiosk components. The easiest method is using [psexec64](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec) from Sysinternals.

### Step-by-Step Installation

**1. Download the Repository**

Either clone the repository or download as a ZIP file. If downloading as ZIP, extract to a new folder (e.g., `C:\KioskInstall`).

**2. Download psexec64**

- Download PSExec from [Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec)
- Extract `psexec64.exe` to any folder (the 64-bit version)
- Open an **elevated Command Prompt** (Run as Administrator)

**3. Launch PowerShell as SYSTEM**

From the elevated command prompt, run:

```cmd
psexec64 -s -i powershell
```

This launches PowerShell with SYSTEM privileges. A new PowerShell window will open.

**4. Set Execution Policy**

In the SYSTEM PowerShell window, allow script execution:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
```

**5. Navigate to Source Directory**

```powershell
cd C:\KioskInstall\source
```

Adjust the path to match your extraction location.

**6. Execute the Configuration Script**

Run the script with your desired parameters. See [Configuration Examples](#configuration-examples) below for common scenarios.

**7. Restart the System**

After the script completes successfully (exit code 3010), restart the computer:

```powershell
Restart-Computer -Force
```

The kiosk will be active after the restart.

## Configuration Examples

### Basic Configuration

Minimal configuration with automatic logoff on close:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOnly'
```

### Recommended Public Kiosk Configuration

Maximum security with idle timeout, Windows App installation, and maintenance:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -InstallWindowsApp `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 15 `
    -ConfigureAutomaticMaintenance `
    -MaintenanceActivationTime '02:00:00' `
    -MaintenanceRandomDelay 2 `
    -Version '1.0.1'
```

**What this does:**
- ✅ Downloads and installs Windows App
- ✅ Resets Windows App on close or after 15 minutes of idle time
- ✅ Schedules maintenance for 2:00 AM with up to 2-hour random delay
- ✅ Tracks deployment version as 1.0.1

### Configuration with Power Management

For devices that should sleep when not in use:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 10 `
    -SetPowerPolicies `
    -IdleSleepTimeoutMinutes 60 `
    -ConfigureAutomaticMaintenance
```

**What this does:**
- ✅ Resets Windows App after 10 minutes of idle time
- ✅ Configures power settings with 60-minute sleep timeout
- ✅ Enables automatic maintenance with default schedule (midnight)

### Custom Web Portal Configuration

Use your own web portal instead of the local HTML file:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'ResetAppAfterConnection' `
    -KioskUrl 'https://portal.tailspintoys.com/avd-kiosk' `
    -Version '2.0.0'
```

**What this does:**
- ✅ Opens custom web portal in Edge kiosk mode
- ✅ Resets Windows App after successful connection
- ✅ Local HTML file is not created (custom URL used instead)

### Restricted URL Navigation for Enhanced Security

Limit which URLs Edge can navigate to in kiosk mode:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 15 `
    -KioskUrl 'https://portal.tailspintoys.com/avd-kiosk' `
    -AllowedUrls @('https://portal.tailspintoys.com', 'file://*')
```

**What this does:**
- ✅ Blocks Edge from navigating to any URL except those specified
- ✅ Allows `portal.tailspintoys.com` and ALL its subdomains (e.g., `www.portal.tailspintoys.com`, `internal.portal.tailspintoys.com`)
- ✅ Allows local files and protocol handlers
- ✅ Automatically includes `ms-avd://*` and `ms-cloudpc://*` (required for Windows App)
- ✅ Automatically includes your `KioskUrl` (unless already covered)
- ✅ Prevents users from browsing to unauthorized websites

**Security benefit:** Even if a user tries to navigate to another site (via link, redirect, etc.), Edge will block it, keeping them contained to authorized URLs only.

> [!NOTE]
> **Subdomain Matching:**
> - Per [Edge URL filter rules](https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format), a hostname like `tailspintoys.com` automatically matches ALL subdomains without needing `*.tailspintoys.com`
> - You don't need to manually include `ms-avd://*`, `ms-cloudpc://*`, or your `KioskUrl` - they're automatically added to ensure Windows App functionality and kiosk accessibility

### Clean Reinstallation

Remove existing settings and install fresh configuration:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -RemoveLegacySettings `
    -RemoveExistingSettings `
    -InstallWindowsApp `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 15
```

**What this does:**
- ✅ Removes legacy kiosk configurations first
- ✅ Removes existing Windows App kiosk settings
- ✅ Installs fresh Windows App
- ✅ Applies new kiosk configuration

### Air-Gapped / Offline Installation

For environments without internet access:

1. Download Windows App MSIX file on a connected computer
2. Copy MSIX file to `Apps\WindowsApp\Dependencies\` directory
3. Run:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -InstallWindowsApp `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 20
```

The script will detect the local MSIX file and use it instead of downloading.

### Minimal Configuration for Testing

Fastest deployment for initial testing:

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'Disabled'
```

> [!WARNING]
> Using `Disabled` is not recommended for production kiosks. Credentials will not be automatically cleared.

## Manual Removal

To completely remove the kiosk configuration and restore the system to its original state:

### Using the Removal Script

**Step 1:** Launch PowerShell as SYSTEM (using psexec64):

```cmd
psexec64 -s -i powershell
```

**Step 2:** Set execution policy:

```powershell
Set-ExecutionPolicy Bypass -Scope Process
```

**Step 3:** Navigate to the source directory:

```powershell
cd C:\KioskInstall\source
```

**Step 4:** Run the removal script:

```powershell
.\Remove-WindowsAppKioskSettings.ps1
```

**Step 5:** Restart the computer:

```powershell
Restart-Computer -Force
```

### What Gets Removed

The removal script performs the following cleanup:

- ✅ Removes Shell Launcher configuration via WMI Bridge
- ✅ Removes Assigned Access configuration
- ✅ Deletes Non-Administrators Local Group Policy Objects
- ✅ Uninstalls provisioning packages
- ✅ Restores original AppLocker policy
- ✅ Resets registry values to original state
- ✅ Disables and uninstalls Keyboard Filter
- ✅ Removes scheduled tasks
- ✅ Deletes `C:\KioskSettings` directory
- ✅ Forces Group Policy update

### Selective Removal

To remove only legacy configurations (keep current kiosk settings):

```powershell
.\Remove-LegacyKioskSettings.ps1
```

## Troubleshooting

### Emergency Access

If you need to access Windows normally while kiosk mode is configured:

**During System Boot:**

1. As the system starts, **hold down the LEFT SHIFT key**
2. **Repeatedly press the ENTER key** until you see the normal Windows login screen
3. Release LEFT SHIFT
4. Sign in with an administrator account

This method bypasses the automatic logon and Shell Launcher, giving you full access to Windows for troubleshooting or reconfiguration.

> [!TIP]
> Practice this on a test system before deploying to production so you're familiar with the timing.

### Logging and Diagnostics

All script operations are logged to the Windows Event Log for auditing and troubleshooting.

**View Kiosk Configuration Logs:**

1. Open **Event Viewer** (eventvwr.msc)
2. Navigate to: **Applications and Services Logs** → **Windows-App-Kiosk**
3. Review events from these sources:
   - **ConfigScript** - Main configuration script operations
   - **RemovalScript** - Kiosk removal operations
   - **LegacyRemovalScript** - Legacy configuration cleanup
   - **AutoLogoff** - Windows App logoff events
   - **Keyboard Filter Configuration** - Keyboard filter setup

**Common Event IDs:**

| Event ID | Source | Type | Description |
|:---------|:-------|:-----|:------------|
| 1 | ConfigScript | Information | Script execution started |
| 2-5 | ConfigScript | Information | Removal scripts executed |
| 199 | ConfigScript | Information | Script completed successfully |
| 1618 | ConfigScript | Error | Configuration failed (reboot required) |
| 20 | RemovalScript | Information | Version detected, removal started |

**Export Logs for Analysis:**

```powershell
# Export to CSV for review
Get-WinEvent -LogName 'Windows-App-Kiosk' -MaxEvents 100 | 
    Select-Object TimeCreated, LevelDisplayName, Id, ProviderName, Message | 
    Export-Csv -Path C:\KioskLogs.csv -NoTypeInformation
```

### Common Issues

**Problem: Script fails with "Reboot Pending" error**

**Symptoms:** Script exits immediately with reboot pending message

**Solution:**
```powershell
# Force restart and retry
Restart-Computer -Force
# After restart, run script again as SYSTEM
```

**Problem: Windows App doesn't launch from Edge**

**Symptoms:** Clicking ms-avd:// links does nothing

**Solutions:**
1. Verify Windows App is installed:
   ```powershell
   Get-AppxPackage -Name "*WindowsApp*" -AllUsers
   ```
2. Check protocol handler registration:
   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Classes\ms-avd"
   ```
3. Reinstall Windows App:
   ```powershell
   .\Set-WindowsAppFromEdgeKioskSettings.ps1 -InstallWindowsApp -RemoveExistingSettings -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOnly'
   ```

**Problem: Automatic logon fails / KioskUser0 doesn't auto-login after reboot**

**Symptoms:** System boots to normal login screen instead of automatic KioskUser0 login, or KioskUser0 account not created

**Root Cause:** Group Policy settings for legal notices or machine inactivity timeout prevent Assigned Access autologon from functioning. These settings require interactive user acknowledgment and break automatic logon.

**Solutions:**

1. **Check if KioskUser0 account exists:**
   ```powershell
   Get-LocalUser -Name KioskUser0
   ```
   
2. **Check for settings that break autologon (VERIFIED):**
   ```powershell
   # Check for legal notices (these BREAK autologon)
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" | Select-Object LegalNoticeText, LegalNoticeCaption, InactivityTimeoutSecs
   ```
   
   **Settings that BREAK autologon:**
   - `LegalNoticeText` - Must be empty/not configured
   - `LegalNoticeCaption` - Must be empty/not configured
   - `InactivityTimeoutSecs` - Must be 0 or not configured
   
   **Settings that DO NOT break autologon:**
   - ✅ Password complexity requirements (works fine)
   - ✅ Minimum password length (works fine)
   - ✅ Maximum password age (works fine)
   - ✅ Account lockout threshold (works fine)

3. **Check for domain GPO conflicts (domain-joined systems):**
   ```powershell
   # Generate Group Policy results report
   gpresult /h C:\temp\gpreport.html
   
   # Open report and check:
   # Computer Configuration > Windows Settings > Security Settings > Local Policies > Security Options
   # Look for: Interactive logon: Message text/title for users attempting to log on
   # Look for: Interactive logon: Machine inactivity limit
   ```
   
   **Domain GPO Override Solutions:**
   - Contact your domain administrator to create a separate OU for kiosk devices
   - Request GPO exemption for legal notices and inactivity timeout
   - Apply a kiosk-specific GPO that sets these values to empty/disabled
   - Display legal notice within kiosk application as compensating control

4. **Check Shell Launcher status:**
   ```powershell
   # Verify Shell Launcher configuration exists
   Get-AssignedAccessShellLauncher
   
   # Check Shell Launcher event logs
   Get-WinEvent -LogName Microsoft-Windows-AssignedAccess/Admin -MaxEvents 20
   ```

6. **Manual KioskUser0 account fix (if account exists but won't auto-login):**
   ```powershell
   # Remove password requirement
   $User = [ADSI]"WinNT://./KioskUser0,user"
   $User.SetPassword("")
   $User.SetInfo()
   
   # Verify account settings
   Get-LocalUser -Name KioskUser0 | Select-Object Name, Enabled, PasswordRequired, PasswordLastSet
   ```

> [!WARNING]
> **For domain-joined systems:** Domain Group Policies override local policies. If the winning GPO for password complexity/length is from the domain, local configuration changes will have NO EFFECT. You MUST work with your domain administrator to resolve this.

**Related Documentation:** See [ARCHITECTURE.md - Group Policy Settings That Break Assigned Access Autologon](ARCHITECTURE.md#️-critical-group-policy-settings-that-break-assigned-access-autologon) for detailed technical explanation.

**Problem: Keyboard is completely unresponsive**

**Symptoms:** Cannot type anything in kiosk

**Solution:** Keyboard Filter may have blocked too many keys. Use emergency access to break out and reconfigure:
```powershell
# After emergency access, check keyboard filter status
Get-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter

# If needed, disable it
Disable-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter -NoRestart
```

**Problem: Edge displays error or blank page**

**Symptoms:** Edge opens but shows error page or blank screen

**Solutions:**
1. Check if custom URL is accessible:
   ```powershell
   # Test URL connectivity
   Invoke-WebRequest -Uri "https://your-portal-url" -UseBasicParsing
   ```
2. Verify local HTML file exists (if using default):
   ```powershell
   Test-Path "C:\KioskSettings\Index.html"
   ```
3. Check Edge kiosk configuration:
   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -ErrorAction SilentlyContinue
   ```

**Problem: Auto-logon doesn't work**

**Symptoms:** Normal login screen appears instead of automatic KioskUser0 logon

**Solution:**
1. Verify Assigned Access configuration is applied:
   ```powershell
   Get-AssignedAccessConfiguration
   ```
2. Check if KioskUser0 account exists:
   ```powershell
   Get-LocalUser | Where-Object { $_.Name -eq 'KioskUser0' }
   ```
3. If configuration is missing, reinstall:
   ```powershell
   .\Set-WindowsAppFromEdgeKioskSettings.ps1 -RemoveExistingSettings -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' -WindowsAppAutoLogoffTimeInterval 15
   ```

**Problem: Windows App auto-logoff is not working**

**Symptoms:** Windows App stays signed in after idle time

**Solutions:**
1. Verify Windows App registry settings:
   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsApp" -ErrorAction SilentlyContinue
   ```
2. Check expected values based on configuration:
   - `ResetAppOnCloseOnly`: `AutoLogoffEnable = 1`
   - `ResetAppAfterConnection`: `AutoLogoffOnSuccessfulConnect = 1`
   - `ResetAppOnCloseOrIdle`: `AutoLogoffTimeInterval = <your value>`

3. Review auto-logoff events in Event Viewer under Windows-App-Kiosk → AutoLogoff source

### Configuration Verification

After installation, verify the kiosk is properly configured:

**Quick Health Check Script:**

```powershell
# Check installed version
$Version = Get-ItemProperty "HKLM:\Software\Kiosk" -Name "version" -ErrorAction SilentlyContinue
Write-Host "Kiosk Version: $($Version.version)"

# Check Shell Launcher configuration
$ShellLauncher = Get-AssignedAccessConfiguration
if ($ShellLauncher) {
    Write-Host "✓ Shell Launcher: Configured" -ForegroundColor Green
} else {
    Write-Host "✗ Shell Launcher: Not Configured" -ForegroundColor Red
}

# Check Windows App installation
$WindowsApp = Get-AppxPackage -Name "*WindowsApp*" -AllUsers
if ($WindowsApp) {
    Write-Host "✓ Windows App: Installed (Version $($WindowsApp.Version))" -ForegroundColor Green
} else {
    Write-Host "✗ Windows App: Not Installed" -ForegroundColor Red
}

# Check Windows App auto-logoff configuration
$AutoLogoff = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsApp" -ErrorAction SilentlyContinue
if ($AutoLogoff) {
    Write-Host "✓ Windows App Auto-Logoff: Configured" -ForegroundColor Green
    if ($AutoLogoff.AutoLogoffEnable) { Write-Host "  - Mode: ResetAppOnCloseOnly" }
    if ($AutoLogoff.AutoLogoffOnSuccessfulConnect) { Write-Host "  - Mode: ResetAppAfterConnection" }
    if ($AutoLogoff.AutoLogoffTimeInterval) { Write-Host "  - Mode: ResetAppOnCloseOrIdle ($($AutoLogoff.AutoLogoffTimeInterval) min)" }
} else {
    Write-Host "✗ Windows App Auto-Logoff: Not Configured" -ForegroundColor Red
}

# Check Keyboard Filter
$KeyboardFilter = Get-WindowsOptionalFeature -Online -FeatureName Client-KeyboardFilter
if ($KeyboardFilter.State -eq 'Enabled') {
    Write-Host "✓ Keyboard Filter: Enabled" -ForegroundColor Green
} else {
    Write-Host "⚠ Keyboard Filter: Not Enabled (requires reboot)" -ForegroundColor Yellow
}

# Check AppLocker policy
$AppLockerPolicy = Get-AppLockerPolicy -Local
if ($AppLockerPolicy.RuleCollections) {
    Write-Host "✓ AppLocker: Configured ($($AppLockerPolicy.RuleCollections.Count) rule collections)" -ForegroundColor Green
} else {
    Write-Host "✗ AppLocker: Not Configured" -ForegroundColor Red
}

# Check KioskSettings directory
if (Test-Path "C:\KioskSettings") {
    Write-Host "✓ KioskSettings Directory: Exists" -ForegroundColor Green
} else {
    Write-Host "✗ KioskSettings Directory: Missing" -ForegroundColor Red
}
```

**Expected Results:**
- ✓ All checks should show green or yellow (yellow for Keyboard Filter before first reboot)
- ✓ Version should match your deployment version
- ✓ Windows App should be installed
- ✓ Auto-logoff configuration should match your parameters

**Test the Kiosk:**

After verification, restart and test as a normal user:

1. Restart the computer
2. System should auto-logon as KioskUser0
3. Edge should open in fullscreen kiosk mode
4. Default HTML or custom URL should display
5. Clicking ms-avd:// link should launch Windows App
6. Test idle timeout behavior (if configured)

## Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/en-us/windows-app/)
- [Windows App Auto Logoff](https://learn.microsoft.com/en-us/windows-app/windowsautologoff)
- [Shell Launcher Documentation](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
- [Assigned Access Overview](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [PSExec Documentation](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec)
- [Keyboard Filter Documentation](https://learn.microsoft.com/en-us/windows-hardware/customize/enterprise/keyboardfilter)
- [AppLocker Overview](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/applocker/applocker-overview)

---

**Need Help?** Check the Event Viewer logs at **Windows-App-Kiosk** for detailed operation logs. Use emergency access (LEFT SHIFT + ENTER during boot) if you need to break out of kiosk mode for troubleshooting.
