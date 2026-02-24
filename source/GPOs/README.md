# Group Policy Configuration Files

This folder contains Local Group Policy configuration files used by the Windows App Kiosk solution.

## File Types

### LGPO Text Files (.txt)
These files use the LGPO.exe tool format for configuring registry-based Group Policy settings. Examples:
- `Ctrl+Alt+Del-*.txt` - Control removal of Ctrl+Alt+Del menu options
- `Edge.txt` - Microsoft Edge browser policies
- `DisablePasswordForUnlock.txt` - Disable password for screen saver and wake from sleep
- `PowerSettings.txt` - Power management policies

### Security Templates (.inf)
These files use the Windows Security Template format for configuring Local Security Policy settings that cannot be set via registry.

#### S4U-PasswordPolicies.inf

**Purpose:** Configures Local Security Policy password settings to support S4U (Service-for-User) passwordless autologon used by Shell Launcher.

**Settings Configured:**
- `PasswordComplexity = 0` - Disables password complexity requirements (allows blank passwords)
- `MinimumPasswordLength = 0` - Sets minimum password length to 0 characters (allows blank passwords)
- `MaximumPasswordAge = 99999` - Sets password to never expire (99999 days = ~273 years)
- `MinimumPasswordAge = 0` - Allows immediate password changes
- `PasswordHistorySize = 0` - Disables password history
- `LockoutBadCount = 0` - Disables account lockout policy

**Why This Is Required:**

The KioskUser0 account created by Shell Launcher uses S4U autologon, which generates a logon token WITHOUT requiring a password. This is a **security improvement** over legacy methods that stored passwords in the registry.

However, if Local Security Policy enforces password complexity or minimum length requirements, Windows will:
1. Prevent creation of accounts with blank/no password
2. Require the KioskUser0 account to have a complex password
3. Break S4U autologon (defeats the entire purpose)

**Applied By:** `Set-WindowsAppFromEdgeKioskSettings.ps1` using the `secedit /configure` command

**Format:** Windows Security Template (.inf) - Unicode text file

**Domain Considerations:**

⚠️ **WARNING:** On domain-joined systems, domain Group Policies may override these local settings. If S4U autologon fails after configuration:

1. Check for domain policy conflicts:
   ```powershell
   gpresult /h C:\temp\gpreport.html
   ```

2. Work with your domain administrator to:
   - Create a separate OU for kiosk devices
   - Link a GPO that exempts kiosk OU from password policy requirements
   - Or use WMI filtering to exclude kiosk machines from password policies

3. Verify current policy settings:
   ```powershell
   secedit /export /cfg C:\temp\current_policy.inf
   Get-Content C:\temp\current_policy.inf | Select-String "PasswordComplexity|MinimumPasswordLength|MaximumPasswordAge|LockoutBadCount"
   ```

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
