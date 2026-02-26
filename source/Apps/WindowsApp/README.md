# Windows App Deployment

This folder contains scripts and dependencies for deploying the **Windows App** (formerly Windows 365) as a provisioned package on Windows devices.

## Overview

The Windows App enables users to connect to Azure Virtual Desktop, Windows 365, and Remote Desktop Services from a single unified application. This deployment solution is designed to provision the app for all users on a device, making it ideal for kiosk and shared device scenarios.

## Files in This Folder

- **Deploy-WindowsApp.ps1** - Main deployment script for installing or uninstalling Windows App
- **Detect-WindowsApp.ps1** - Detection script to verify Windows App installation status
- **Dependencies/** - Required Visual C++ Runtime dependencies for Windows App
  - `Microsoft.VCLibs.140.00_14.0.30035.0_x64__8wekyb3d8bbwe.Appx`
  - `Microsoft.VCLibs.x64.14.00.Desktop.appx`

## Deployment Methods

### Method 1: Automatic Download (Requires Internet Connectivity)

Run the deployment script without placing the MSIX file in the folder. The script will automatically download the latest version from Microsoft:

```powershell
.\Deploy-WindowsApp.ps1
```

The script will:

1. Check for existing Windows App installations and remove them
2. Download the latest Windows App MSIX from Microsoft's download link
3. Install the app with required dependencies
4. Clean up temporary files

### Method 2: Offline Installation (No Internet Required)

For environments without internet connectivity or air-gapped systems, you can manually download and place the MSIX file in this folder.

#### Step 1: Download Windows App MSIX

On a device with internet access, download the Windows App MSIX package:

1. **Option A: Direct Download Link**

   - Visit: https://go.microsoft.com/fwlink/?linkid=2262633
   - The MSIX file will download automatically
   - Rename the downloaded file to `WindowsApp.msix` (optional, but recommended for clarity)

2. **Option B: Using PowerShell**

   ```powershell
   Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2262633' -OutFile 'WindowsApp.msix'
   ```

3. **Option C: Using WinGet (Recommended)**

   Download the entire package including the MSIX and updated dependencies using Windows Package Manager:

   ```powershell
   winget download --id 9N1F85V9T8BN --architecture=x64 -d <destination-folder> --accept-package-agreements --accept-source-agreements --skip-license
   ```

   Replace `<destination-folder>` with your desired download location (e.g., `C:\Temp\WindowsApp`).
   
   **Note:** This method automatically downloads the latest dependencies, ensuring you have the most up-to-date versions.

#### Step 2: Transfer Files

Transfer the downloaded MSIX file to the target device and place it in the same folder as the script.

Your folder structure should look like this:

```
WindowsApp/
├── Deploy-WindowsApp.ps1
├── Detect-WindowsApp.ps1
├── WindowsApp.msix          ← Your downloaded MSIX file
├── Dependencies/
│   ├── Microsoft.VCLibs.140.00_14.0.30035.0_x64__8wekyb3d8bbwe.Appx
│   └── Microsoft.VCLibs.x64.14.00.Desktop.appx
└── README.md
```

#### Step 3: Run Deployment Script

Execute the deployment script:

```powershell
.\Deploy-WindowsApp.ps1
```

The script will:

1. Detect the MSIX file in the current folder
2. Remove any existing Windows App installations
3. Install the Windows App with dependencies as a provisioned package

## Uninstallation

To remove Windows App from the device:

```powershell
.\Deploy-WindowsApp.ps1 -DeploymentType Uninstall
```

## Configuration Options

The deployment script supports several parameters to customize the Windows App installation:

### Automatic Updates

Control how Windows App handles automatic updates. Valid values are:

- **0** (default): Enable updates
- **1**: Disable updates
- **2**: Disable updates from the Microsoft Store
- **3**: Disable updates from the CDN location

```powershell
# Enable automatic updates (default)
.\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 0

# Disable all automatic updates
.\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 1

# Disable updates from Microsoft Store
.\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 2

# Disable updates from CDN location
.\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 3
```

For more information about configuring updates, see: [Configure Windows App updates](https://learn.microsoft.com/en-us/windows-app/configure-updates-windows)

### Skip First Run Experience

Skip the initial setup wizard when Windows App first launches (recommended for kiosk scenarios):

```powershell
.\Deploy-WindowsApp.ps1 -SkipFirstRunExperience
```

### Auto Logoff Configuration

Configure automatic user logoff behavior for kiosk scenarios:

```powershell
# Reset app when closed
.\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppOnCloseOnly

# Reset app after successful connection
.\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppAfterConnection

# Reset app on close or after idle timeout
.\Deploy-WindowsApp.ps1 -AutoLogoffConfig ResetAppOnCloseOrIdle -AutoLogoffTimeInterval 15
```

For more information, see: [Windows App auto logoff](https://learn.microsoft.com/en-us/windows-app/windowsautologoff)

### Combined Configuration Example

```powershell
.\Deploy-WindowsApp.ps1 -DisableAutomaticUpdates 1 -SkipFirstRunExperience -AutoLogoffConfig ResetAppOnCloseOnly
```

## Detection Script

Use the detection script to verify if Windows App is installed and check its version:

```powershell
.\Detect-WindowsApp.ps1
```

**Exit Codes:**

- `0` - Windows App is installed and meets or exceeds the target version
- `1` - Windows App is not installed or version is below target

The script currently checks for version **2.0.704.0** or higher.

## Requirements

- **Operating System:** Windows 10/11 (64-bit)
- **Permissions:** Administrator privileges required
- **PowerShell:** Version 5.1 or higher
- **Dependencies:** VC++ Runtime libraries (included in Dependencies folder)

## Deployment Logs

Installation logs are automatically created at:

```
C:\Windows\Logs\Software\Install-WindowsApp.log
```

Uninstallation logs:

```
C:\Windows\Logs\Software\UninstallWindowsApp.log
```

## Integration with Device Management

This deployment can be integrated with:

- **Microsoft Intune** - Deploy as Win32 app or PowerShell script
- **Configuration Manager (SCCM)** - Deploy as application or package
- **Group Policy** - Deploy via startup script
- **Provisioning Packages** - Include in device provisioning

## Troubleshooting

### Issue: "Windows App MSIX package not found"

- **Solution:** Download the MSIX file and place it in this folder, or ensure the device has internet connectivity for automatic download

### Issue: Installation fails with dependency errors

- **Solution:** Verify the Dependencies folder contains both required APPX files

### Issue: Script requires administrator privileges

- **Solution:** Run PowerShell as Administrator

### Issue: Execution policy prevents script from running

- **Solution:** Run `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` before executing the script

## Additional Resources

- [Windows App Documentation](https://learn.microsoft.com/windows-app/)
- [Configure Windows App Updates](https://learn.microsoft.com/en-us/windows-app/configure-updates-windows)
- [Windows App Auto Logoff](https://learn.microsoft.com/en-us/windows-app/windowsautologoff)
- [Azure Virtual Desktop](https://learn.microsoft.com/azure/virtual-desktop/)
- [Windows 365](https://learn.microsoft.com/windows-365/)

## Notes

- The Windows App is provisioned for all users on the device
- Existing versions are automatically removed before installing new versions
- The script automatically detects 32-bit PowerShell and relaunches in 64-bit mode if needed
- Downloaded MSIX files are temporarily stored in `C:\Windows\SystemTemp` and cleaned up after installation
- Configuration settings are stored in registry keys:
  - `HKLM:\SOFTWARE\Microsoft\WindowsApp` - Auto logoff and update settings
  - `HKLM:\SOFTWARE\Microsoft\Windows365` - First run experience settings
