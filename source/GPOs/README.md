# Group Policy Configuration Files

This folder contains Local Group Policy configuration files used by the Windows App Kiosk solution.

## File Types

### LGPO Text Files (.txt)
These files use the LGPO.exe tool format for configuring registry-based Group Policy settings. Examples:
- `Ctrl+Alt+Del-*.txt` - Control removal of Ctrl+Alt+Del menu options
- `Edge.txt` - Microsoft Edge browser policies
- `DisablePasswordForUnlock.txt` - Disable password for screen saver and wake from sleep
- `EnableAutomaticRootCertificateUpdates.txt` - Ensure automatic root certificate updates are enabled
- `PowerSettings.txt` - Power management policies

## What Breaks Assigned Access Autologon (VERIFIED)

Based on real-world verification, only the following Group Policy settings **actually break** Assigned Access autologon:

### ❌ Interactive Logon Legal Notices

**Settings:**
- `LegalNoticeCaption` - Interactive logon: Message title for users attempting to log on
- `LegalNoticeText` - Interactive logon: Message text for users attempting to log on

**Registry Location:**
```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeCaption
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeText
```

**Why it breaks autologon:**
- Forces interactive user acknowledgment (clicking OK)
- Microsoft documentation explicitly states this breaks autologon
- [Reference: Turn on automatic logon](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon)

**Mitigation:**
- Set to empty/not configured for kiosk devices
- Display legal notice within kiosk application instead
- Create GPO exemption for kiosk OU

### ❌ Machine Inactivity Timeout

**Setting:**
- `InactivityTimeoutSecs` - Interactive logon: Machine inactivity limit

**Registry Location:**
```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs
```

**Why it breaks kiosk:**
- Forces logoff/lock after inactivity period
- Requires re-authentication
- Disrupts kiosk user experience

**Mitigation:**
- Set to 0 (disabled) for kiosk devices
- Create GPO exemption for kiosk OU

## What Does NOT Break Autologon (VERIFIED)

### ✅ Password Policies - ALL COMPATIBLE

**Verified Facts:**
- Assigned Access autologon stores password in LSA secrets (encrypted storage)
- Windows automatically generates a random, highly complex password
- Password is automatically managed by Windows
- Password policies do not affect autologon functionality
- [Microsoft documentation reference](https://learn.microsoft.com/en-us/windows/win32/secauthn/protecting-the-automatic-logon-password)

**STIG Compliance - Good News:**

All STIG password policies are fully compatible with Assigned Access autologon:
- ✅ V-253304 (Password complexity = Enabled) - Works fine
- ✅ V-253303 (Minimum password length ≥14 chars) - Works fine
- ✅ V-253301 (Maximum password age ≤60 days) - Works fine
- ✅ Account lockout threshold - Works fine
- ✅ Password history - Works fine

## Domain-Joined STIG Deployments

For domain-joined STIG-compliant deployments:

1. **Check for domain policy conflicts:**
   ```powershell
   gpresult /h C:\temp\gpreport.html
   ```

2. **Look for these policies that BREAK autologon:**
   - Interactive logon: Message text for users attempting to log on (LegalNoticeText)
   - Interactive logon: Message title for users attempting to log on (LegalNoticeCaption)
   - Machine inactivity limit (InactivityTimeoutSecs)

3. **Work with your domain administrator to:**
   - Create a separate OU for kiosk devices
   - Link a GPO that sets legal notices to empty/disabled for kiosk OU
   - Set machine inactivity timeout to 0 or very high value
   - Apply ALL password policies (these work fine with Assigned Access autologon)

4. **For detailed STIG compliance analysis:** 
   - See [STIG_AUTOLOGON_ANALYSIS.md](../../STIG_AUTOLOGON_ANALYSIS.md)
   - See [VERIFIED_AUTOLOGON_FINDINGS.md](../../VERIFIED_AUTOLOGON_FINDINGS.md)

## Usage

These configuration files are automatically applied by the installation script. Manual application is not typically needed, but if required:

### Apply LGPO Text File
```powershell
lgpo.exe /t "C:\path\to\config.txt"
```

### Apply Security Template
```powershell
secedit /configure /db C:\Windows\security\database\custom.sdb /cfg "C:\path\to\template.inf" /overwrite
gpupdate /force
```

## References

- [LGPO Tool Documentation](https://techcommunity.microsoft.com/t5/microsoft-security-baselines/lgpo-exe-local-group-policy-object-utility/ba-p/701045)
- [Security Templates Overview](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/security-templates)
- [Password Policy Settings](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-policy)
- [Shell Launcher Configuration](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/shell-launcher/)
