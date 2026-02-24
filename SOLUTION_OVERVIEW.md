# Edge-Based Windows App Kiosk - Solution Overview

**Navigation:** [🏠 Overview](README.md) | 🏗️ Solution Overview | [⚙️ Implementation Guide](IMPLEMENTATION.md) | [🔒 Architecture Guide](ARCHITECTURE.md)

---

## Introduction

This repository contains a **customized kiosk solution** for Azure Virtual Desktop and Windows 365 access, tailored to specific customer requirements. The solution configures Microsoft Edge in kiosk mode to replace the Windows shell, displaying a web interface that launches the Windows App for remote desktop connections.

**Configuration Characteristics:**

- **Customized for Requirements** - Tailored to specific deployment needs and preferences
- **Multi-Layered Security** - Shell Launcher with comprehensive access controls
- **Automatic Logon** - Zero-touch user experience with KioskUser0 account
- **Edge as Shell** - Browser-based interface for flexibility and familiarity
- **Windows App Integration** - Native ms-avd:// protocol support

This custom configuration is designed for specific use cases such as lobby stations, shared workstations, hot-desk environments, or public access points requiring secure Azure Virtual Desktop or Windows 365 connectivity.

## Prerequisites

### Required

1️⃣ **Operating System**

A currently supported version of **Windows 10** (version 1903 or later) or **Windows 11** with one of the following editions that support Shell Launcher [^1]:

- Windows 10/11 Education
- Windows 10/11 Enterprise
- Windows 10/11 Enterprise LTSC
- Windows 10/11 IoT Enterprise
- Windows 10/11 IoT Enterprise LTSC

> [!IMPORTANT]  
> **Windows 10 requires version 1903 or later** for Shell Launcher v2 support used by this solution.

2️⃣ **Administrative Access**

The ability to run the installation script with **SYSTEM privileges**. The easiest method is using [PSExec](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec). Instructions are provided in the [Implementation Guide](IMPLEMENTATION.md#manual-installation).

### Optional

3️⃣ **Internet Connection**

Required only when using the `-InstallWindowsApp` parameter to automatically download Windows App from Microsoft. For air-gapped environments, place the Windows App MSIX file in the `source/Apps/WindowsApp/` directory and the script will use the local copy. **See [Windows App Deployment Guide](source/Apps/WindowsApp/README.md) for detailed offline installation instructions.**

## How It Works

### Architecture Overview

This solution uses multiple Windows technologies working together to create a secure, locked-down kiosk environment:

```
┌─────────────────────────────────────────────────────────────┐
│  Boot Sequence                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Windows 11 Boots                                        │
│  2. Assigned Access Auto-Logon → KioskUser0                 │
│  3. Shell Launcher Replaces Explorer.exe with Edge          │
│  4. Edge Opens in Kiosk Mode (Single-App)                   │
│  5. Edge Displays Configured URL                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  User Experience                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  • User sees only Edge browser in fullscreen                │
│  • Default: Local HTML with AVD/W365 launch buttons         │
│  • Custom: Your web portal with ms-avd:// links             │
│  • User clicks link → Windows App launches                  │
│  • User connects to Azure Virtual Desktop / Windows 365     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Security & Session Management                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  • Windows App auto-logoff on close or idle                 │
│  • Keyboard Filter blocks Windows key combinations          │
│  • AppLocker prevents unauthorized apps                     │
│  • Group Policy locks down system controls                  │
│  • No access to Start, Settings, Task Manager, Explorer     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **Shell Launcher** | Replaces Explorer with Edge | Assigned Access WMI Bridge CSP |
| **Automatic Logon** | Creates and auto-signs in KioskUser0 | Assigned Access Configuration |
| **Edge Kiosk Mode** | Single-app fullscreen browser | Shell Launcher XML configuration |
| **AppLocker** | Blocks unauthorized applications | Local AppLocker policy |
| **Group Policy** | System lockdown and restrictions | Multi-user LGPO (non-administrators) |
| **Keyboard Filter** | Blocks key combinations | Windows Optional Feature |
| **Provisioning Packages** | Privacy and interface optimization | .ppkg files |
| **Registry Settings** | Windows App and protocol handlers | HKLM registry keys |

## User Experience Flow

### Sign-In and Launch

The kiosk provides a zero-touch experience:

1. **Power On** → System boots to Windows 11
2. **Automatic Logon** → KioskUser0 account signs in automatically (no password)
3. **Shell Replacement** → Shell Launcher starts Edge instead of Explorer
4. **Kiosk Mode** → Edge opens in fullscreen single-app kiosk mode
5. **Default Page** → Edge displays your configured URL

**Default URL:** `file:///c:/kiosksettings/Index.html` (local HTML file with launch buttons)  
**Custom URL:** Any web URL you specify with the `-KioskUrl` parameter

### Connecting to Resources

**Option 1: Default Local HTML** (Included)

The default HTML file provides a simple interface with buttons to launch Windows App:

- Large, clear buttons for easy navigation
- Uses ms-avd:// protocol to launch Windows App
- Can be customized to match your branding
- No internet connection required

**Option 2: Custom Web Portal** (Your URL)

Point to your own web portal that includes:

- ms-avd:// protocol links to specific resources
- Custom branding and instructions
- Dynamic content based on location/role
- Integration with your identity systems

### Windows App Behavior

Once a user clicks an ms-avd:// link:

1. **Windows App Launches** → Browser invokes the protocol handler
2. **User Authenticates** → Windows App authentication (SSO if Entra joined)
3. **Resource Listing** → User sees their assigned AVD/W365 resources
4. **Connection** → User connects to their virtual desktop or app
5. **Usage** → User works in their remote session

### Session Reset and Security

The solution provides automatic credential protection:

| Auto-Logoff Mode | When It Triggers | Security Impact |
|------------------|------------------|-----------------|
| **ResetAppOnCloseOnly** | User closes Windows App | Credentials cleared when app closes |
| **ResetAppAfterConnection** | Successful AVD/W365 connection | Credentials cleared after connecting |
| **ResetAppOnCloseOrIdle** | App closes OR idle timeout | Maximum security: idle + close protection |

**Recommended:** Use `ResetAppOnCloseOrIdle` with a 10-15 minute interval for public kiosks.

When reset triggers:

- All users signed out of Windows App
- App data completely cleared
- Cached credentials removed
- Next user starts with clean slate

## Windows App Auto Logoff Behaviors

The solution supports four automatic logoff configurations for Windows App. For detailed information, see [Configure auto logoff on Windows](https://learn.microsoft.com/en-us/windows-app/windowsautologoff).

### Auto Logoff Configuration Options

**Table 1:** Windows App Auto Logoff Configuration Summary

| Configuration | Behavior | Use Case | Security Level |
|:--------------|:---------|:---------|:---------------|
| **Disabled** | No automatic sign-out or data reset | Non-public kiosks with controlled access | ⚠️ Low |
| **ResetAppOnCloseOnly** | Sign out and reset when Windows App closes | Semi-public environments, supervised access | 🔒 Medium |
| **ResetAppAfterConnection** | Sign out and reset after successful connection | Single-resource scenarios | 🔒 Medium |
| **ResetAppOnCloseOrIdle** | Sign out and reset on close OR idle timeout | Public kiosks, high-security environments | 🔒🔒 High |

### Recommended Configuration

For most kiosk deployments, use **ResetAppOnCloseOrIdle** for maximum security:

```powershell
-WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
-WindowsAppAutoLogoffTimeInterval 60
```

This configuration:

- ✅ Protects credentials if user walks away without closing Windows App
- ✅ Automatically resets after defined idle period
- ✅ Also triggers reset when user closes the app
- ✅ Provides comprehensive security for public access scenarios

### How Idle Detection Works

When `ResetAppOnCloseOrIdle` is configured:

1. Windows App polls the OS for inactivity every `N` minutes (your specified interval)
2. If OS reports `N` or more minutes of inactivity, logout initiates
3. All accounts are signed out and app data is cleared
4. Next user gets a fresh Windows App instance

**Example:** With `WindowsAppAutoLogoffTimeInterval = 60`:

- App checks every 60 minutes
- If 60+ minutes of OS idle time detected → reset
- User can walk away and credentials are protected after 60 minutes

## Power Management and Maintenance

### Automatic Maintenance

Configure Windows automatic maintenance to run during off-hours:

```powershell
-ConfigureAutomaticMaintenance `
-MaintenanceActivationTime '02:00:00' `
-MaintenanceRandomDelay 2
```

**What it does:**

- Windows Update, security scanning, disk defrag run at specified time
- Random delay prevents all kiosks from starting maintenance simultaneously
- Ensures devices stay current without user intervention

**Recommended for:** All kiosk deployments

### Power Policies

Configure power settings for shared device scenarios:

```powershell
-SetPowerPolicies `
-IdleSleepTimeoutMinutes 60
```

**What it does:**

- Configures power button, sleep button, and lid actions
- Sets idle sleep timeout
- Disables hibernation
- Enables standby states for faster wake
- Optimizes battery and AC power settings

**Recommended for:** Kiosks that should sleep when not in use (battery-powered, after-hours power saving)

## Security Architecture

### Multi-Layer Security Model

The solution implements defense-in-depth with multiple security layers:

**Layer 1: Shell Replacement**

- Explorer.exe replaced with Edge.exe
- No Start menu, taskbar, or desktop access
- User cannot access Windows UI elements

**Layer 2: AppLocker**

- Blocks notepad.exe, search app (SearchHost.exe)
- Only allows authorized applications for KioskUser0

**Layer 3: Group Policy**

- Task Manager disabled
- Drive access hidden and restricted
- Ctrl+Alt+Del options removed
- Privacy settings optimized

**Layer 4: Keyboard Filter**

- Windows key combinations blocked
- Alt+Tab disabled
- Ctrl+Alt+Del restricted
- F11 (fullscreen toggle) blocked

**Layer 5: Windows App Auto Logoff**

- Automatic credential reset
- Prevents credential theft from abandoned sessions
- Configurable idle timeouts

**Layer 6: URL Navigation Restriction**

- Controls which URLs Edge can navigate to
- Blocks all URLs except explicitly allowed list
- Prevents browsing to unauthorized websites
- Supports wildcards for flexible domain matching

**Layer 7: Provisioning & Registry**

- Windows Spotlight disabled
- Advertising ID disabled
- First-run experiences skipped
- Privacy-focused configuration

### Attack Surface Reduction

The solution removes or restricts:

- ❌ Built-in Windows apps (News, Weather, Xbox, etc.)
- ❌ OneDrive synchronization
- ❌ Start menu access
- ❌ Settings app
- ❌ Task Manager
- ❌ File Explorer
- ❌ Run dialog
- ❌ Command prompt and PowerShell (for kiosk user)
- ❌ Device Manager and system tools

### Emergency Access

If you need to break out of kiosk mode for troubleshooting:

**During Boot:** Hold **LEFT SHIFT** and repeatedly press **ENTER** until the normal login screen appears.

This bypasses the auto-logon and Shell Launcher, allowing you to sign in as an administrator.

## Customization Options

### Custom Web Portal

Replace the default local HTML with your own portal:

1. Create a web portal accessible from the kiosk
2. Include links using the `ms-avd://` protocol
3. Use the `-KioskUrl` parameter to specify your URL

**Example ms-avd:// Links:**

```html
<!-- Launch Windows App to specific workspace -->
<a href="ms-avd:subscribe?url=https://rdweb.wvd.microsoft.com">Connect to AVD</a>

<!-- Launch to Windows 365 -->
<a href="ms-avd:subscribe?url=https://rdweb.wvd.microsoft.com/api/arm/feeddiscovery">Windows 365</a>

<!-- Custom feed URL -->
<a href="ms-avd:subscribe?url=https://your-feed-url">Custom Feed</a>
```

### Custom Local HTML

Modify the default HTML file for offline branding:

1. **Source file:** `source/AssignedAccess/ShellLauncher/windowsapp.html`
2. Edit the HTML to include your branding, logos, colors
3. Deploy the solution (script copies HTML to `C:\KioskSettings\Index.html`)

### URL Parameter

The `-KioskUrl` parameter supports:

- **Local file:** `file:///c:/kiosksettings/Index.html` (default)
- **Web URL:** `https://portal.tailspintoys.com/kiosk`
- **Intranet URL:** `http://kiosk-portal.local/`

### URL Navigation Restriction

The `-AllowedUrls` parameter controls which URLs Microsoft Edge can navigate to. By default, Edge blocks ALL URLs (`*`) and only allows those explicitly specified in the allowlist.

**Default Configuration:**

```powershell
-AllowedUrls @(
    'file://*',
    'ms-avd://*',
    'ms-cloudpc://*',
    'workspaces://*',
    'evo://*'
)
```

> [!IMPORTANT]
> **Automatic Inclusions:**
> 
> - The protocols `ms-avd://*` and `ms-cloudpc://*` are **always automatically included** in the allowlist, even if you don't specify them. This ensures Windows App can launch Azure Virtual Desktop and Windows 365 connections properly.
> - Your specified `KioskUrl` is also automatically included (unless already covered by a wildcard like `file://*` or `https://*.tailspintoys.com`).

**Custom Configuration:**

```powershell
-AllowedUrls @(
    'https://portal.tailspintoys.com',  # Automatically allows all *.portal.tailspintoys.com subdomains
    'https://avd.microsoft.com',        # Automatically allows all *.avd.microsoft.com subdomains
    'file://*'                          # Allows local files
    # Note: ms-avd://* and ms-cloudpc://* are automatically added
)
```

**With Explicit Subdomain-Only Restriction:**

```powershell
-AllowedUrls @(
    '.tailspintoys.com',  # ONLY subdomains like www.tailspintoys.com, NOT tailspintoys.com itself
    'file://*'
)
```

**How It Works:**

1. Edge URLBlocklist is set to `*` (block everything)
2. Edge URLAllowlist contains only your specified URLs
3. Users attempting to navigate elsewhere are blocked
4. Hostname patterns automatically match all subdomains per [Edge filter rules](https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format)
   - `tailspintoys.com` matches `tailspintoys.com`, `www.tailspintoys.com`, `internal.tailspintoys.com`, etc.
   - `.tailspintoys.com` (with leading dot) matches ONLY subdomains, not the root

**Security Considerations:**

- **Critical protocols are always included:** `ms-avd://*` and `ms-cloudpc://*` are automatically added to ensure Windows App works
- **Your KioskUrl is always included:** The script intelligently checks if it's already covered before adding
- **Include `file://*`** if using local HTML files
- **Include other protocols if needed:** `evo://*` and `workspaces://*` for other Windows App features
- **Understand subdomain matching:** `tailspintoys.com` automatically matches ALL subdomains - you don't need `*.tailspintoys.com`
- **Use `.tailspintoys.com`** (with leading dot) if you want to match ONLY subdomains and exclude the root domain
- Test thoroughly - overly restrictive lists may break functionality

**Common Patterns:**

| Pattern | Matches | Use Case |
|---------|---------|----------|
| `https://portal.tailspintoys.com` | `https://portal.tailspintoys.com` <br> `https://www.portal.tailspintoys.com` <br> `https://internal.portal.tailspintoys.com` | Portal + all subdomains (Edge auto-matches subdomains) |
| `portal.tailspintoys.com` | `https://portal.tailspintoys.com` <br> `http://portal.tailspintoys.com` <br> `https://www.portal.tailspintoys.com` | Domain + subdomains (any scheme) |
| `.tailspintoys.com` | `https://www.tailspintoys.com` <br> `https://internal.tailspintoys.com` <br> **NOT** `https://tailspintoys.com` | Subdomains only (excludes root domain) |
| `https://*.tailspintoys.com` | `https://www.tailspintoys.com` <br> `https://internal.tailspintoys.com` <br> **NOT** `https://tailspintoys.com` | Explicit subdomain wildcard |
| `https://portal.tailspintoys.com/*` | All paths under portal | Portal with multiple pages |
| `file://*` | All local files | Local HTML kiosk pages |
| `ms-avd://*` | All ms-avd protocol links | Auto-included for Windows App |
| `ms-cloudpc://*` | All ms-cloudpc protocol links | Auto-included for Windows 365 |

> [!TIP]
> **Key Rule:** A hostname like `contoso.com` automatically matches ALL subdomains (`www.contoso.com`, `internal.contoso.com`, etc.) without needing a wildcard. This follows [Edge URL filter format](https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format).

**Example Attack Scenario Prevented:**

If your kiosk page has a link that redirects through an external site:

1. User clicks link → Edge attempts to load `https://redirect.badsite.com`
2. URLBlocklist blocks it because it's not in the allowlist
3. User cannot navigate away from authorized URLs

> [!NOTE]
> **URL Matching Behavior:**
> - Hostname patterns like `contoso.com` automatically match ALL subdomains (per [Edge URL filter rules](https://learn.microsoft.com/en-us/DeployEdge/edge-learnmmore-url-list-filter%20format))
> - Example: `portal.company.com` allows `portal.company.com`, `www.portal.company.com`, `internal.portal.company.com`, etc.
> - To match ONLY subdomains (not root), use `.portal.company.com` (leading dot)
> - The script intelligently checks if your `KioskUrl` is already covered before adding it explicitly

This is different from AutoLaunchProtocolsFromOrigins (in AllowedOrigins.txt), which only controls whether protocol handlers auto-launch without prompting.

## Removal and Cleanup

### Automatic Removal with Parameters

Call removal scripts automatically during installation:

```powershell
# Remove legacy kiosk configurations before installing
-RemoveLegacySettings

# Remove existing Windows App kiosk settings before installing
-RemoveExistingSettings

# Remove both
-RemoveLegacySettings -RemoveExistingSettings
```

### Manual Removal Scripts

Run the removal scripts independently:

**Remove Current Configuration:**

```powershell
.\Remove-WindowsAppKioskSettings.ps1
```

**Remove Legacy Configurations:**

```powershell
.\Remove-LegacyKioskSettings.ps1
```

### What Gets Removed

Both removal scripts:

- ✅ Remove Assigned Access and Shell Launcher configurations
- ✅ Delete Local Group Policy Objects
- ✅ Uninstall provisioning packages
- ✅ Restore original AppLocker policy
- ✅ Reset registry values to original state
- ✅ Remove Keyboard Filter feature
- ✅ Delete scheduled tasks
- ✅ Clean up KioskSettings directory
- ✅ Force Group Policy updates

**System restart is required** after removal to complete the cleanup.

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| 🚫 **Can't break out of kiosk** | Hold LEFT SHIFT + press ENTER repeatedly during boot |
| 📋 **Need to check logs** | Event Viewer → Applications and Services Logs → Windows-App-Kiosk |
| 🔍 **Verify configuration** | Check `HKLM:\Software\Kiosk` registry key for version |
| 🔄 **Reinstall needed** | Use `-RemoveExistingSettings` parameter |
| 🧹 **Clean up legacy config** | Use `-RemoveLegacySettings` parameter |
| ⚙️ **Check Shell Launcher** | `Get-AssignedAccessConfiguration` in PowerShell |

For complete troubleshooting guidance, see the [Implementation Guide](IMPLEMENTATION.md#troubleshooting).

## Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/en-us/windows-app/)
- [Windows App Auto Logoff Configuration](https://learn.microsoft.com/en-us/windows-app/windowsautologoff)
- [Shell Launcher Documentation](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
- [Assigned Access Overview](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [Azure Virtual Desktop Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Windows 365 Documentation](https://learn.microsoft.com/en-us/windows-365/)
- [Keyboard Filter Documentation](https://learn.microsoft.com/en-us/windows-hardware/customize/enterprise/keyboardfilter)

---

[^1]: For more information see [Shell Launcher Windows Edition Requirements](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/#windows-edition-requirements)
