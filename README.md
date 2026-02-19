# Edge-Based Windows App Kiosk Solution

## 📋 Introduction

This repository contains a **customized kiosk solution** for Azure Virtual Desktop (AVD) and Windows 365 access based on specific customer requirements. It configures a Windows client to use **Microsoft Edge in kiosk mode** to display a web interface that launches the **Windows App** for remote desktop connections.

> [!NOTE]
> This is a **custom version** tailored to specific deployment needs. Many configuration options have been streamlined to focus on a particular use case.

## 🎯 Solution Overview

This solution configures Microsoft Edge in kiosk mode as the Windows shell, replacing the traditional Explorer interface with a locked-down browser experience that provides access to Azure Virtual Desktop and Windows 365 resources.

**Key Features:**

✅ **Automatic Logon** - Uses Windows 11 Assigned Access to create KioskUser0 with automatic sign-in  
✅ **Edge Kiosk Mode** - Microsoft Edge replaces the Windows shell using Shell Launcher  
✅ **Configurable URL** - Display a custom web portal or use the included local HTML file  
✅ **Windows App Integration** - Native ms-avd:// protocol support to launch connections  
✅ **Automatic Logoff** - Windows App security with credential reset on close or idle  
✅ **Locked-Down Interface** - AppLocker, Group Policy, and Keyboard Filter prevent unauthorized access  
✅ **Simplified Configuration** - Streamlined parameters focused on the essential settings  
✅ **Easy Removal** - Dedicated scripts to cleanly remove legacy or current configurations

## 🔒 How It Works

1. **Boot** → System automatically logs on with the KioskUser0 account
2. **Launch** → Microsoft Edge starts in kiosk mode (replaces Explorer shell)
3. **Navigate** → Edge displays your configured URL (default: local HTML with AVD/W365 launch buttons)
4. **Connect** → User clicks links with ms-avd:// protocol to launch Windows App
5. **Session** → User accesses their Azure Virtual Desktop or Windows 365 resources
6. **Reset** → When closed or idle, Windows App automatically logs off and resets for the next user

## ✅ Prerequisites

### Required

1. **💻 Operating System:** A currently supported version of **Windows 10** (version 1903+) or **Windows 11**

2. **📀 Windows Editions:** The following editions support Shell Launcher:
   - Windows 10/11 Education
   - Windows 10/11 Enterprise
   - Windows 10/11 Enterprise LTSC
   - Windows 10/11 IoT Enterprise
   - Windows 10/11 IoT Enterprise LTSC

3. **🔑 Administrative Access:** The ability to run installation scripts with SYSTEM privileges (instructions in documentation)

### Optional

- **🌐 Internet Connection:** Required only if using `-InstallWindowsApp` to auto-download Windows App. For offline/air-gapped environments, see [Windows App Offline Installation Guide](source/Apps/WindowsApp/README.md)
- **🔐 Device Management:** For some scenarios, devices should be [joined to Entra ID](https://learn.microsoft.com/en-us/entra/identity/devices/concept-directory-join) or [Entra ID Hybrid Joined](https://learn.microsoft.com/en-us/entra/identity/devices/concept-hybrid-join)

## 🚀 Quick Start

1. **Download** or clone this repository
2. **Read** the [Solution Overview](SOLUTION_OVERVIEW.md) to understand the architecture
3. **Follow** the [Implementation Guide](IMPLEMENTATION.md) for installation steps
4. **Navigate** to the `source/` directory and run the configuration script with your preferred parameters

### Basic Installation Example

```powershell
# Run with SYSTEM privileges (see documentation for PSExec instructions)
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -InstallWindowsApp `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 15 `
    -KioskUrl 'file:///c:/kiosksettings/Index.html'
```

### With Custom Web Portal

```powershell
.\Set-WindowsAppFromEdgeKioskSettings.ps1 `
    -WindowsAppAutoLogoffConfig 'ResetAppOnCloseOrIdle' `
    -WindowsAppAutoLogoffTimeInterval 10 `
    -KioskUrl 'https://portal.tailspintoys.com/kiosk'
```

## 📚 Documentation

- **[Solution Overview](SOLUTION_OVERVIEW.md)** - Architecture, how it works, and key concepts
- **[Implementation Guide](IMPLEMENTATION.md)** - Complete parameter reference, installation steps, and troubleshooting

## 🔧 Configuration Options

The script provides several configuration parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `InstallWindowsApp` | Auto-download and install Windows App (supports offline installation) | Not installed |
| `WindowsAppAutoLogoffConfig` | Auto-logoff behavior (Disabled, ResetAppOnCloseOnly, ResetAppAfterConnection, ResetAppOnCloseOrIdle) | Required parameter |
| `WindowsAppAutoLogoffTimeInterval` | Minutes of idle time before Windows App resets | 15 |
| `KioskUrl` | URL Edge displays in kiosk mode | file:///c:/kiosksettings/Index.html |
| `AllowedUrls` | Array of URLs Edge is allowed to navigate to | Protocol handlers (\*auto-includes ms-avd, ms-cloudpc & KioskUrl) |
| `ConfigureAutomaticMaintenance` | Enable scheduled Windows maintenance | Not configured |
| `SetPowerPolicies` | Configure power settings for shared devices | Not configured |
| `RemoveLegacySettings` | Remove old kiosk configurations before install | No removal |
| `RemoveExistingSettings` | Remove current kiosk settings before install | No removal |

For complete parameter documentation, see the [Implementation Guide](IMPLEMENTATION.md).

## 🛠️ Removal Scripts

Two dedicated scripts are provided for cleanup:

- **`Remove-LegacyKioskSettings.ps1`** - Removes legacy kiosk configurations from previous versions
- **`Remove-WindowsAppKioskSettings.ps1`** - Completely removes the current Edge-based kiosk configuration

These can be called automatically using the `-RemoveLegacySettings` and `-RemoveExistingSettings` parameters, or run independently.

## 🎨 Customization

### Custom Web Portal

Replace the default local HTML file with your own web portal:

1. Create a web portal with buttons/links using the `ms-avd://` protocol
2. Use `-KioskUrl` parameter to point to your portal URL
3. Ensure your portal is accessible from the kiosk device

### Custom HTML File

Modify the default HTML file located at:

- **Source:** `source/AssignedAccess/ShellLauncher/windowsapp.html`
- **Deployed to:** `C:\KioskSettings\Index.html`

## ⚠️ Important Notes

> [!IMPORTANT]
>
> - This solution **requires Windows 10 (version 1903+) or Windows 11** with editions that support Shell Launcher
> - The script **must be run with SYSTEM privileges** (use PSExec or similar)
> - A **system restart is required** after installation to activate kiosk mode
> - Use **emergency access** (hold LEFT SHIFT + press ENTER during boot) if you need to break out of kiosk mode

> [!TIP]
>
> - Set `WindowsAppAutoLogoffConfig` to `'ResetAppOnCloseOrIdle'` for maximum security
> - Use automatic maintenance and power policies for shared/public kiosks
> - Test thoroughly in a non-production environment first

## 🔍 Use Cases

This solution is ideal for:

- 🏢 **Lobby Kiosks** - Public access points for guest Azure Virtual Desktop connections
- 👥 **Shared Workstations** - Hot-desk environments with automatic credential reset
- 🎓 **Education Labs** - Computer labs accessing Windows 365 Cloud PCs
- 🏥 **Healthcare Stations** - Secure access to clinical virtual desktops
- 🏭 **Manufacturing Floor** - Shop floor devices accessing business applications
- 📍 **Retail Locations** - Point-of-presence devices for remote corporate access

## 📚 Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/en-us/windows-app/)
- [Azure Virtual Desktop Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Windows 365 Documentation](https://learn.microsoft.com/en-us/windows-365/)
- [Shell Launcher Documentation](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
- [Windows Assigned Access (Kiosk Mode)](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/)
- [Entra ID Device Management](https://learn.microsoft.com/en-us/entra/identity/devices/)

## 💬 Support

For issues, questions, or contributions:

1. Check the [Implementation Guide](IMPLEMENTATION.md) for troubleshooting guidance
2. Review the Event Viewer logs at: **Applications and Services Logs > Windows-App-Kiosk**
3. Use emergency access to break out of kiosk mode if needed (hold LEFT SHIFT + press ENTER during boot)
4. Review repository issues for known problems
5. Create a new issue with detailed information about your environment and problem

---

**Version:** 2026.02.19  
**Maintained by:** Shawn Meyer, Microsoft
