# Edge-Based Windows App Kiosk - Architecture and Security Guide

**Navigation:** [🏠 Overview](README.md) | [🏗️ Solution Overview](SOLUTION_OVERVIEW.md) | [⚙️ Implementation Guide](IMPLEMENTATION.md) | 🔒 Architecture Guide

**Target Audience:** IT Professionals, System Administrators, Security Evaluators, and Technical Decision Makers

---

## Table of Contents

- [Quick Reference](#quick-reference)
- [Architectural Evolution](#architectural-evolution)
  - [Legacy Architecture: GPO-Driven Shell Replacement](#legacy-architecture-gpo-driven-shell-replacement)
  - [Modern Architecture: Shell Launcher with Edge](#modern-architecture-shell-launcher-with-edge)
  - [Why the Change Was Necessary](#why-the-change-was-necessary)
- [Technical Comparison](#technical-comparison)
- [Security Architecture](#security-architecture)
  - [Defense in Depth Approach](#defense-in-depth-approach)
  - [Application Control (AppLocker)](#application-control-applocker)
  - [Network Access Control (Edge URL Filtering)](#network-access-control-edge-url-filtering)
  - [Session Management and Certificate Cleanup](#session-management-and-certificate-cleanup)
  - [System Lockdown](#system-lockdown)
- [Protocol Handler Architecture](#protocol-handler-architecture)
- [Group Policy Implementation](#group-policy-implementation)
- [Migration Considerations](#migration-considerations)
- [Security Validation](#security-validation)
- [Threat Model and Mitigations](#threat-model-and-mitigations)

---

## Quick Reference

**📖 Document Purpose:** Technical justification for migrating from legacy GPO-driven kiosk to modern Shell Launcher architecture.

### 🎯 Why This Change?

**Problem:** Windows App (Microsoft's UWP remote desktop client) **does not work** with GPO-based shell replacement.

**Root Cause:** GPO registry-based shell replacement (`HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Shell`) breaks UWP protocol handler activation. When clicking ms-avd:// or ms-cloudpc:// links, protocol handlers **fail silently**.

**Key Insight:** Both legacy and modern approaches replace Explorer with Edge in kiosk mode using similar command-line arguments. The difference is **HOW** the shell is replaced:

- **Legacy:** GPO registry → kiosk.bat → Edge ❌ Breaks protocol handlers
- **Modern:** Shell Launcher (WMI Bridge CSP) → Edge ✅ Provides proper UWP shell context

**Solution:** Shell Launcher v2 provides native shell environment for UWP protocol handler activation while still replacing Explorer with Edge.

### ⚡ Key Differences at a Glance

| What | Legacy (GPO Registry) | Modern (Shell Launcher) |
|------|-------------------|------------------------|
| **Shell Replacement Method** | GPO: `Policies\System\Shell=kiosk.bat` | WMI Bridge CSP (Shell Launcher v2) |
| **kiosk.bat Location** | `c:\Program Files\Kiosk Portal\kiosk.bat` | Not used (Edge launched directly) |
| **Edge Kiosk Mode** | ✅ Yes (via kiosk.bat) | ✅ Yes (via Shell Launcher) |
| **Explorer Running** | ❌ Not running (replaced) | ❌ Not running (replaced) |
| **Edge Command** | Similar `--kiosk --edge-kiosk-type=fullscreen` | Similar `--kiosk --edge-kiosk-type=fullscreen` |
| **Windows App (UWP)** | ❌ Broken (protocol handlers fail silently) | ✅ Works (native UWP support) |
| **Auto-Logon** | Registry-based (password in registry for 'wes10_user') | Assigned Access autologon (auto-generated password in encrypted LSA secrets) |
| **GPO Settings in Non-Administrators** | 100+ settings (mostly dead weight) | 5 settings (Ctrl+Alt+Del only) |
| **Maintenance** | High (unnecessary complexity) | Low (component-based) |

### 🔒 Security Comparison

**Legacy Security:** 100+ Group Policy settings in Non-Administrators GPO, but **most have no effect** because Explorer is already replaced with Edge via kiosk.bat. These are legacy bloat from previous configurations.

**Modern Security:** 6-layer defense-in-depth approach:

1. **Shell Isolation** - Shell Launcher replaces Explorer (same as legacy, but better UWP support)
2. **AppLocker** - Modern allowlist-based application execution control (replaces legacy DisallowRun list GPO with many unnecessary executables)
3. **Edge URL Filtering** - Block all URLs except allowlist (deny-by-default)
4. **Keyboard Filter** - Block Windows key, Alt+Tab, Alt+F4, etc.
5. **Session Management** - Auto-logoff + certificate cleanup on close/idle
6. **GPO Lockdown** - Ctrl+Alt+Del restrictions (5 essential settings, removed 95+ dead weight)

**Verdict:** ✅ Modern approach is **more secure** (auto-generated password in encrypted LSA secrets vs. registry-stored password) and **vastly simpler** (removed unnecessary complexity).

### 📊 GPO Settings Reduction

**Legacy Configuration:**

- 100+ settings in Non-Administrators GPO
- Settings for Start Menu, Taskbar, Desktop, Windows Components, Network, etc.
- **Most have NO EFFECT** because Explorer is already replaced by kiosk.bat
- These are legacy bloat from previous configurations (dead weight)

**Modern Configuration:**

- Remove Task Manager (Ctrl+Alt+Del)
- Remove Lock Computer (Ctrl+Alt+Del)
- Remove Change Password (Ctrl+Alt+Del)
- Remove Sign Out (Ctrl+Alt+Del)
- Disable switching users (Ctrl+Alt+Del)

**Why so few?** Both legacy and modern replace Explorer entirely with Edge. The 100+ legacy settings were never needed. Modern approach uses only the 5 essential Ctrl+Alt+Del restrictions (the only UI not replaced by shell replacement).

### 🚀 Migration Path

**Recommended: Clean Reinstall**

**Recommended Migration Approach:**

1. Run `Remove-LegacyKioskSettings.ps1` (removes kiosk.bat, GPO, scripts)
2. Restart
3. Run `Set-WindowsAppFromEdgeKioskSettings.ps1 -InstallWindowsApp -WindowsAppAutoLogoffConfig ResetAppOnCloseOrIdle -WindowsAppAutoLogoffTimeInterval 15`
4. Restart
5. Verify functionality

### 🎓 Key Takeaways for Decision Makers

✅ **Technical Necessity** - GPO registry-based shell replacement breaks UWP protocol handlers (silent fail); Shell Launcher fixes this  
✅ **Security Improvement** - Assigned Access autologon (auto-generated password in encrypted LSA secrets) vs. registry-based autologon (password stored in less-secure registry)  
✅ **Architectural Simplification** - Removes 95+ unnecessary GPO settings (dead weight with no effect)  
✅ **Maintenance Reduction** - 5 essential GPO settings vs. 100+ legacy bloat  
✅ **Equivalent User Experience** - Both replace Explorer with Edge in kiosk mode (same end result)  
✅ **Future-Proof** - Aligned with Microsoft's modern Windows direction and UWP application model

### 📋 Testing Checklist

After migration, verify:

- [ ] Auto-logon works (KioskUser0 signs in automatically)
- [ ] Edge launches fullscreen (no Explorer/Start/Taskbar)
- [ ] Kiosk URL displays correctly
- [ ] Windows App launches via ms-avd:// link
- [ ] AVD/W365 connection succeeds
- [ ] Auto-logoff triggers on close or idle
- [ ] Certificates cleared on logoff (run `certutil -user -store MY` as different user)
- [ ] Windows key blocked (Keyboard Filter)
- [ ] Ctrl+Alt+Del shows limited options only
- [ ] Cannot launch Explorer, cmd, PowerShell, Settings (AppLocker blocks)

### 📚 Where to Learn More

- **Architectural details:** See [Architectural Evolution](#architectural-evolution) section below
- **Security deep-dive:** See [Security Architecture](#security-architecture) section below
- **Migration planning:** See [Migration Considerations](#migration-considerations) section below
- **Threat analysis:** See [Threat Model and Mitigations](#threat-model-and-mitigations) section below

---

## Architectural Evolution

### Legacy Architecture: GPO-Based Shell Replacement

#### Overview

The legacy kiosk implementation used Windows Group Policy registry settings to replace the default Windows Explorer shell (`explorer.exe`) with a custom batch file (`kiosk.bat`) located at `c:\Program Files\Kiosk Portal\kiosk.bat`. This batch file then launched Microsoft Edge in kiosk mode using similar command-line arguments to the modern approach. The **Non-Administrators Group Policy** contained 100+ settings, though most had no effect since Explorer was already replaced.

#### Key Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                      Legacy Kiosk Architecture                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Registry-Based Auto-Logon                                   │
│     - User account: wes10_user (requires password)              │
│     - Registry: HKLM\SOFTWARE\Microsoft\Windows NT\             │
│       CurrentVersion\Winlogon                                   │
│       AutoAdminLogon = "1"                                      │
│       DefaultUserName = "wes10_user"                            │
│       DefaultPassword = "<password>" (stored in registry!)      │
│     - [!] SECURITY RISK: Password stored on disk (extractable)  │
│                                                                 │
│  2. User Logon → Non-Administrators GPO Applied                 │
│                                                                 │
│  3. Shell Replacement via GPO Registry                          │
│     HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\             │
│     Policies\System\Shell = "c:\Program Files\Kiosk Portal\     │
│     kiosk.bat"                                                  │
│                                                                 │
│  4. kiosk.bat Executes                                          │
│     - Calls cscript localuserlogoff.vbs (session monitoring)    │
│     - Launches Edge in kiosk mode:                              │
│       msedge.exe --kiosk "URL" --edge-kiosk-type=fullscreen     │
│       --no-first-run                                            │
│     - Explorer.exe NEVER RUNS (fully replaced)                  │
│                                                                 │
│  5. Non-Administrators GPO (100+ settings)                      │
│     - Start Menu restrictions (no effect - no Explorer)         │
│     - Taskbar restrictions (no effect - no Explorer)            │
│     - Desktop restrictions (no effect - no Explorer)            │
│     - Ctrl+Alt+Del restrictions (5 settings - EFFECTIVE)        │
│     - File Explorer restrictions (no effect - can't launch)     │
│     - Windows Settings restrictions (no effect - can't launch)  │
│     - Drive restrictions (no effect - no Explorer)              │
│     - DisallowRun list (many blocked executables - dead weight) │
│     - ... (90+ settings with NO EFFECT - legacy bloat)          │
│                                                                 │
│  6. Logon/Logoff Scripts via GPO                                │
│     - Logoff script: Certificate cleanup (certutil)             │
│     - Stored in C:\Windows\System32\GroupPolicyUsers\{SID}\     │
│     - scripts.ini configuration file                            │
│                                                                 │
│  [X] PROBLEM 1: UWP Protocol Handlers Fail Silently             │
│     GPO-based shell replacement breaks protocol handler         │
│     activation pipeline. Clicking ms-avd:// links does nothing. │
│                                                                 │
│  [X] PROBLEM 2: Password Stored in Registry (Security Risk)     │
│     Registry-based autologon requires wes10_user password       │
│     stored in Winlogon registry (HKLM). Extractable with        │
│     physical access or admin tools. Password rotation difficult.│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Technical Implementation

**Auto-Logon Registry Keys:**

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
    AutoAdminLogon = "1" (DWORD)
    DefaultUserName = "wes10_user"
    DefaultPassword = "<password>" (plain text or LSA secret)
```

**Security Concern:** Password must be stored in registry for autologon to work. This can be extracted by:

- Someone with physical access to the device
- Administrator-level malware or tools
- Registry export/backup
- LSA secret extraction tools (if using LSA storage)

**Shell Replacement Registry Key:**

```text
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
    Shell = "c:\Program Files\Kiosk Portal\kiosk.bat"
```

**kiosk.bat Contents (Simplified):**

```batch
@echo off
REM Start session monitoring VBScript
cscript //B //Nologo localuserlogoff.vbs

REM Launch Edge in kiosk mode (similar to Shell Launcher command)
start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --kiosk "https://vdi.tailspintoys.com/portal" --edge-kiosk-type=fullscreen --no-first-run
```

**Key Points:**

- Explorer.exe never runs (fully replaced by kiosk.bat → Edge)
- Edge command is very similar to modern Shell Launcher approach
- The difference is the HOW, not the WHAT

**Group Policy Structure:**

```text
C:\Windows\System32\GroupPolicyUsers\
└── {SID-of-Non-Administrators-Group}\
    ├── Registry.pol         (compiled GPO settings)
    ├── User\
    │   └── Scripts\
    │       ├── scripts.ini  (logon/logoff configuration)
    │       ├── Logon\
    │       │   └── *.bat, *.vbs
    │       └── Logoff\
    │           └── *.bat, *.vbs
    └── GPT.INI
```

#### Limitations and Challenges

1. **UWP Protocol Handler Failure** (CRITICAL)
   - GPO registry-based shell replacement (`HKLM\...\Policies\System\Shell`) breaks UWP protocol handler activation
   - When users click ms-avd:// or ms-cloudpc:// links, protocol handlers **fail silently** (no error, nothing happens)
   - Windows App (UWP application) cannot be launched via protocol links
   - Root cause: GPO method does not provide proper shell context for UWP activation pipeline
   - This is THE primary reason for migrating to Shell Launcher

2. **Maintenance Complexity**
   - 100+ Group Policy settings in Non-Administrators GPO
   - **95+ settings have NO EFFECT** (legacy bloat from previous configurations)
   - Only 5 Ctrl+Alt+Del restrictions are actually needed
   - Difficult to identify which settings are actually doing something
   - Configuration audit and troubleshooting complicated by dead weight

3. **Architectural Confusion**
   - Two-step shell replacement (GPO → kiosk.bat → Edge) adds unnecessary complexity
   - kiosk.bat stored in `c:\Program Files\Kiosk Portal\` (external dependency)
   - Harder to understand and document than direct Shell Launcher approach

4. **Windows Update Compatibility**
   - GPO registry settings sometimes affected by Windows Updates
   - Shell replacement via registry can be reset or conflicted
   - Requires validation after major updates

5. **Maintenance Complexity**
   - 100+ Group Policy settings in Non-Administrators GPO
   - **95+ settings have NO EFFECT** (legacy bloat from previous configurations)
   - Only 5 Ctrl+Alt+Del restrictions are actually needed
   - Difficult to identify which settings are actually doing something
   - Configuration audit and troubleshooting complicated by dead weight

6. **Architectural Confusion**
   - Two-step shell replacement (GPO → kiosk.bat → Edge) adds unnecessary complexity
   - kiosk.bat stored in `c:\Program Files\Kiosk Portal\` (external dependency)
   - Harder to understand and document than direct Shell Launcher approach

7. **Windows Update Compatibility**
   - GPO registry settings sometimes affected by Windows Updates
   - Shell replacement via registry can be reset or conflicted
   - Requires validation after major updates

**Key Insight:** The legacy configuration already achieves shell replacement with Edge (same end result as modern approach). The problem is **HOW** it's done - GPO registry method breaks UWP, and carries 95+ unnecessary GPO settings.

### Modern Architecture: Shell Launcher with Edge

#### Overview

The modern implementation leverages **Shell Launcher v2** (introduced in Windows 10 version 1903) to replace the Windows Explorer shell entirely with Microsoft Edge running in kiosk mode. This approach provides a purpose-built kiosk environment with native support for UWP applications and modern protocol handlers.

#### Key Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                     Modern Kiosk Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Shell Launcher v2 Configuration                             │
│     - Assigned Access WMI Bridge CSP                            │
│     - XML configuration defines shell replacement               │
│     - System-level enforcement (not user-level)                 │
│                                                                 │
│  2. Automatic Logon                                             │
│     - Assigned Access auto-logon configuration                  │
│     - KioskUser0 account (auto-generated complex password)      │
│     - Assigned Access autologon (encrypted LSA secrets)         │
│                                                                 │
│  3. Shell Replacement with Edge                                 │
│     Shell Launcher → msedge.exe (Single App Kiosk Mode)         │
│       --kiosk "https://vdi.tailspintoys.com/portal"             │
│       --edge-kiosk-type=fullscreen                              │
│       --no-first-run                                            │
│       --disable-features=msEdgeShoppingAssistantEnabled         │
│       --disable-pinch                                           │
│                                                                 │
│  4. Edge as Kiosk Shell                                         │
│     - Full-screen browser interface                             │
│     - No address bar, tabs, or browser controls                 │
│     - URL filtering (allowlist-based)                           │
│     - Protocol handler support for ms-avd://, ms-cloudpc://     │
│                                                                 │
│  5. Defense in Depth Security                                   │
│     - AppLocker: Application execution control                  │
│     - Edge URLBlocklist/URLAllowlist: Network access control    │
│     - Keyboard Filter: Key combination blocking                 │
│     - Minimal GPO: Ctrl+Alt+Del restrictions only               │
│     - Group Policy Scripts: Logon/logoff automation             │
│                                                                 │
│  6. UWP Support                                                 │
│     - Windows App (UWP) launches via protocol handlers          │
│     - Native ms-avd://, ms-cloudpc://, workspaces:// support    │
│     - Proper shell context for UWP lifecycle                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Technical Implementation

**Shell Launcher XML Configuration:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<ShellLauncherConfiguration xmlns="http://schemas.microsoft.com/ShellLauncher/2019/Configuration">
  <Profiles>
    <DefaultProfile>
      <Shell Shell="explorer.exe">
        <DefaultAction Action="RestartShell"/>
      </Shell>
    </DefaultProfile>
    <Profile Id="{GUID}">
      <Shell Shell="%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe --kiosk https://vdi.tailspintoys.com/portal --edge-kiosk-type=fullscreen --no-first-run" V2:AppType="Desktop">        
        <ReturnCodeActions>
          <ReturnCodeAction ReturnCode="0" Action="RestartShell"/>
          <ReturnCodeAction ReturnCode="1" Action="RestartShell"/>
          <ReturnCodeAction DefaultAction="RestartShell"/>
        </ReturnCodeActions>
      </Shell>
    </Profile>
  </Profiles>
  <Configs>
    <Config>
      <AutoLogonAccount/>      
      <Profile Id="{GUID}"/>
    </Config>
  </Configs>
</ShellLauncherConfiguration>
```

**Assigned Access WMI Bridge CSP:**

```text
OMA-URI: ./Device/Vendor/MSFT/AssignedAccess/ShellLauncher
Configuration: [Base64-encoded XML content]
```

**Group Policy Structure (Simplified):**

```text
C:\Windows\System32\GroupPolicyUsers\
└── S-1-5-32-545\  (Non-Administrators SID)
    ├── Registry.pol
    ├── User\
    │   └── Scripts\
    │       ├── scripts.ini
    │       ├── Logon\
    │       │   ├── LaunchUserMonitor.bat
    │       │   └── LocalUserlogoff.vbs
    │       └── Logoff\
    │           └── ClearCertificates.bat
    └── GPT.INI
```

#### Advantages Over Legacy Approach

1. **Native UWP Support** (PRIMARY BENEFIT)
   - Shell Launcher provides proper shell context for UWP protocol handler activation
   - Windows App (UWP) launches correctly via ms-avd://, ms-cloudpc:// links
   - Legacy GPO method breaks protocol handlers (silent fail)
   - Critical for Windows App functionality

2. **Enhanced Autologon Security** (MAJOR SECURITY IMPROVEMENT)
   - Modern: Assigned Access autologon - **password stored in encrypted LSA secrets (auto-generated)**
   - Legacy: Registry-based autologon - password stored in registry (**extractable**)
   - See detailed analysis in [Autologon Security](#autologon-security-legacy-vs-modern) section

3. **Simplified Architecture**
   - Direct shell replacement (Shell Launcher → Edge) vs. two-step (GPO → kiosk.bat → Edge)
   - No external dependency on `c:\Program Files\Kiosk Portal\kiosk.bat`
   - Easier to understand, document, and troubleshoot
   - Single XML configuration file vs. GPO registry + batch script

4. **Configuration Cleanup**
   - Removes 95+ unnecessary GPO settings (legacy bloat with no effect)
   - Reduces from 100+ GPO settings to 5 essential settings (Ctrl+Alt+Del restrictions)
   - Replaces DisallowRun list GPO (many blocked executables - dead weight) with AppLocker (modern targeted allowlist)
   - Cleaner GPO structure (easier to audit)
   - Simplified maintenance

5. **Improved Reliability**
   - System-level enforcement (WMI Bridge CSP) vs. GPO registry
   - Shell Launcher automatically restarts Edge if it crashes
   - Less affected by Windows Updates
   - More robust error handling

6. **Same User Experience**
   - Both approaches replace Explorer with Edge fullscreen
   - Same Edge kiosk mode command-line arguments
   - Same visible behavior to end users
   - Modern approach just "does it better" under the hood

### Why the Change Was Necessary

#### Business Requirements

**Windows App Adoption:**
Microsoft is consolidating remote desktop clients under the **Windows App** brand, which is a Universal Windows Platform (UWP) application. Key features include:

- **Azure Virtual Desktop** connections (ms-avd:// protocol)
- **Windows 365** connections (ms-cloudpc:// protocol)
- **Microsoft Dev Box** connections
- **Remote Desktop Services** connections
- Modern authentication (Entra ID, Conditional Access, MFA)
- Automatic updates via Microsoft Store

**Protocol Handler Requirements:**
The Windows App relies on protocol handlers to launch connections directly from web portals:

```html
<!-- Example connection link -->
<a href="ms-avd:connect?workspaceId={ID}&resourceId={ID}">
  Launch My Desktop
</a>
```

#### Technical Constraints

**GPO Registry-Based Shell Replacement Limitations:**

1. **Protocol Handler Activation Failure** (CRITICAL)
   - GPO method: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Shell`
   - This registry location breaks UWP protocol handler activation pipeline
   - When users click ms-avd:// or ms-cloudpc:// links: **SILENT FAIL** (nothing happens)
   - Windows reports no error, but Windows App never launches
   - Root cause: UWP activation system requires proper shell context

2. **Shell Context Missing**
   - GPO registry-based shell replacement does not provide full shell context for UWP subsystem
   - Shell Launcher provides native shell services to Windows while replacing Explorer
   - UWP protocol handler activation requires shell services that GPO method doesn't provide

3. **Architectural Mismatch**
   - GPO registry shell replacement is a legacy method from Windows XP era
   - UWP applications and modern protocol handlers expect Shell Launcher or Explorer
   - Two-step replacement (GPO → kiosk.bat → Edge) adds unnecessary complexity

**Key Point:** Both approaches achieve the same END RESULT (Edge replaces Explorer), but the GPO METHOD breaks UWP functionality.

#### Migration Drivers

| Driver | Impact | Benefit of Modern Architecture |
|--------|--------|-------------------------------|
| **Windows App Functionality** | Critical | GPO method breaks protocol handlers (silent fail); Shell Launcher fixes this |
| **Autologon Security** | Critical | Assigned Access autologon (encrypted LSA secrets) vs. registry password (extractable) |
| **Configuration Cleanup** | High | Remove 95+ unnecessary GPO settings (dead weight); replace DisallowRun list with AppLocker |
| **Architectural Simplification** | High | Direct shell replacement vs. two-step (GPO → kiosk.bat → Edge) |
| **Maintenance** | Medium | 5 essential GPO settings vs. 100+ (easier to audit and troubleshoot) |
| **Application Control** | Medium | AppLocker (modern targeted allowlist) vs. DisallowRun list GPO (many unnecessary executables) |
| **Compliance** | Medium | No stored passwords (aligns with NIST, industry best practices) |
| **Future Compatibility** | High | Aligned with Microsoft's modern Windows direction and UWP model |

---

## Technical Comparison

### Side-by-Side Comparison Matrix

| Component | Legacy GPO Approach | Modern Shell Launcher Approach |
|-----------|---------------------|-------------------------------|
| **Shell Replacement Mechanism** | GPO Registry: `HKCU\...\Policies\System\Shell="kiosk.bat"` | Shell Launcher v2: WMI Bridge CSP with XML config |
| **Enforcement Level** | Non-Administrators User GPO registry | System-level (CSP/WMI Bridge) |
| **Shell Process** | kiosk.bat → Edge (kiosk mode) | msedge.exe (kiosk mode) directly |
| **Explorer.exe Running** | ❌ No (fully replaced) | ❌ No (fully replaced) |
| **Edge Kiosk Mode** | ✅ Yes (via kiosk.bat) | ✅ Yes (via Shell Launcher) |
| **Edge Command Arguments** | Similar (--kiosk --app=https://vdi.tailspintoys.com/portal --edge-kiosk-type=fullscreen) | Similar (--kiosk https://vdi.tailspintoys.com/portal --edge-kiosk-type=fullscreen) |
| **Start Menu Access** | ❌ Not applicable (no Explorer) | ❌ Not applicable (no Explorer) |
| **Taskbar Access** | ❌ Not applicable (no Explorer) | ❌ Not applicable (no Explorer) |
| **Desktop Icons** | ❌ Not applicable (no Explorer) | ❌ Not applicable (no Explorer) |
| **File Explorer Access** | ❌ Cannot launch (no Explorer) | ❌ Cannot launch (AppLocker blocks) |
| **Settings App Access** | ❌ Cannot launch (no Explorer) | ❌ Cannot launch (AppLocker blocks) |
| **Ctrl+Alt+Del Controls** | 5 GPO settings to hide options | 5 GPO settings (same - still needed) |
| **Application Launching** | Protocol handlers from Edge (broken for UWP) | Protocol handlers from Edge (working) |
| **Win32 Application Support** | ✅ Yes | ✅ Yes |
| **UWP Application Support** | ❌ No (protocol handlers fail silently) | ✅ Yes (native support) |
| **Protocol Handler Support** | ❌ Broken (ms-avd://, ms-cloudpc:// fail) | ✅ Full (ms-avd://, ms-cloudpc://, workspaces://) |
| **Application Control** | DisallowRun list GPO (many executables blocked - dead weight) | AppLocker (modern execution control - targeted allowlist) |
| **Network Access Control** | Edge URL filtering (URLBlocklist/URLAllowlist) | Edge URL filtering (URLBlocklist/URLAllowlist) - **SAME** |
| **Logon Scripts** | GPO scripts.ini (logon section) | GPO scripts.ini (logon section) - **UNCHANGED** |
| **Logoff Scripts** | GPO scripts.ini (logoff section) | GPO scripts.ini (logoff section) - **UNCHANGED** |
| **Certificate Cleanup** | `certutil -user -delstore MY *.*` via logoff script | `certutil -user -delstore MY *.*` via logoff script - **UNCHANGED** |
| **Keyboard Filtering** | Windows Keyboard Filter (optional feature) | Windows Keyboard Filter (optional feature) - **UNCHANGED** |
| **Auto-Logon Method** | Registry-based (Winlogon AutoAdminLogon) | Assigned Access autologon |
| **Auto-Logon User** | wes10_user (password in registry) | KioskUser0 (auto-generated password) |
| **Password Storage** | ⚠️ Stored in registry (HKLM\...\Winlogon) | ✅ Encrypted LSA secrets (auto-generated complex password) |
| **Password Security Risk** | ⚠️ Extractable with admin tools | ✅ Requires SYSTEM-level access to LSA secrets |
| **User Account Name** | wes10_user | KioskUser0 |
| **Session Reset** | Manual logoff or scheduled task | Windows App auto-logoff feature |
| **Configuration Complexity** | High (100+ GPO settings) | Low (5 GPO settings + AppLocker + Edge policies) |
| **Maintenance Effort** | High (many interdependent settings) | Low (component-based, modular) |
| **Troubleshooting Difficulty** | High (many potential failure points) | Low (fewer components, clear responsibilities) |
| **Windows Update Compatibility** | Medium (GPO settings sometimes reset) | High (CSP-based, less affected by updates) |
| **Security Auditability** | Low (distributed settings, hard to assess) | High (centralized: AppLocker XML, Edge policies, GPO minimal) |

### Configuration File Comparison

#### Legacy Approach: kiosk.bat Example

**File Location:** `c:\Program Files\Kiosk Portal\kiosk.bat`

```batch
@echo off
REM Legacy kiosk shell replacement script (GPO registry method)
REM Called when: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Shell

REM Start session monitoring VBScript (monitors for Windows App close)
cscript //B //Nologo localuserlogoff.vbs

REM Launch Edge in kiosk mode (similar to Shell Launcher command)
start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --kiosk "https://vdi.tailspintoys.com/portal" --edge-kiosk-type=fullscreen --no-first-run --disable-features=msEdgeShoppingAssistantEnabled --disable-pinch
```

**Characteristics:**

- Two-step replacement (GPO → kiosk.bat → Edge)
- Edge command similar to Shell Launcher
- **PROBLEM: GPO method breaks UWP protocol handlers (silent fail)**
- Explorer never runs (fully replaced, same as modern approach)

#### Modern Approach: Shell Launcher Configuration

**See detailed XML configuration in the [Modern Architecture](#modern-architecture-shell-launcher-with-edge) section above.**

**Characteristics:**

- System-level enforcement (not user-modifiable)
- Automatic crash recovery (RestartShell action)
- Modern application support (Edge with protocol handlers)
- Built-in idle timeout support (`--kiosk-idle-timeout-minutes=15`)
- Assigned Access autologon with encrypted LSA secrets (`<AutoLogonAccount/>`)
- Requires minimal additional GPO restrictions

### Group Policy Settings Reduction

**Legacy GPO Settings: 100+ in Non-Administrators GPO**

**KEY INSIGHT:** ~95% of these settings have **NO EFFECT** because Explorer is already replaced by kiosk.bat → Edge. These are legacy bloat from previous configurations. Only the 5 Ctrl+Alt+Del restrictions are actually doing something.

<details>
<summary>Expand to see complete list of legacy GPO settings (most are dead weight)</summary>

**Start Menu and Taskbar (40+ settings) - NO EFFECT (no Explorer running):**

- Remove Run menu from Start Menu
- Remove Taskbar properties from Start Menu and taskbar
- Remove common program groups from Start menu
- Remove user's folders from the Start menu
- Remove Downloads link from Start menu
- Remove Recent Items menu from Start menu
- Remove Search link from Start menu
- Remove Help menu from Start menu
- Remove All Programs list from the Start menu
- Turn off personalized menus
- Remove and prevent access to the Shut Down, Restart, Sleep, and Hibernate commands
- Remove Logoff on the Start Menu
- Prevent changes to Taskbar and Start Menu Settings
- Do not keep history of recently opened documents
- Clear history of recently opened documents on exit
- Remove Pinned Programs list from the Start Menu
- Remove frequent programs list from the Start Menu
- Turn off notification area cleanup
- Hide the notification area
- Turn off all balloon notifications

**Desktop (15+ settings) - NO EFFECT (no Explorer/desktop):**

- Hide and disable all items on the desktop
- Prohibit user from changing My Documents path
- Remove Computer icon on the desktop
- Remove Network icon on the desktop
- Remove user's folders from the desktop
- Remove properties from the Computer icon context menu
- Remove properties from the Recycle Bin context menu
- Remove properties from the Documents icon context menu
- Hide these specified drives in My Computer
- Prevent access to drives from My Computer

**Windows Components (20+ settings) - MIXED (some effective, most not):**

- Remove File Explorer access (NO EFFECT - can't launch without Explorer) (NO EFFECT - can't launch without Explorer)
- Remove Windows Settings access (NO EFFECT - can't launch without Explorer)
- Disable Windows Settings app (NO EFFECT - can't launch without Explorer)
- Do not allow Cortana (NO EFFECT - can't launch without Explorer)
- Allow search and search highlights (NO EFFECT - can't launch without Explorer)
- Remove Task Manager (✅ EFFECTIVE - blocks Ctrl+Alt+Del option)
- Remove Windows Security from Ctrl+Alt+Del (✅ EFFECTIVE)
- Disable lock workstation from Ctrl+Alt+Del (✅ EFFECTIVE)
- Remove Change Password from Ctrl+Alt+Del (✅ EFFECTIVE)
- Remove Sign Out from Ctrl+Alt+Del (✅ EFFECTIVE)
- Disable switching users (✅ EFFECTIVE)
- Do not show Windows tips (NO EFFECT - can't launch without Explorer)
- Turn off Help (NO EFFECT - can't launch without Explorer)
- Prevent access to the command prompt (NO EFFECT - can't launch without Explorer)
- Prevent access to registry editing tools (NO EFFECT - can't launch without Explorer)
- Disable Windows Store (NO EFFECT - can't launch without Explorer)
- Turn off Store application (NO EFFECT - can't launch without Explorer)

**System (10+ settings) - NO EFFECT (can't launch Control Panel/cmd without Explorer):**

- Prevent access to Control Panel and PC settings
- Prohibit access to Control Panel and PC settings
- Hide specified Control Panel items
- Run only specified Windows applications
- Don't run specified Windows applications
- Disable command prompt
- Disable Task Manager
- Remove Task Manager from Ctrl+Alt+Del

**Network (5+ settings) - NO EFFECT (can't access Network settings without Explorer):**

- Prohibit use of Internet Connection Sharing
- Prohibit access to properties of a LAN connection
- Ability to change properties of an all user remote access connection
- Ability to rename all user remote access connections

**Other (10+ settings) - VARIED (some may have effect):**

- Multiple PowerShell execution policy settings (NO EFFECT - can't launch without Explorer)
- Privacy settings (telemetry, advertising ID, etc.) (POSSIBLE EFFECT - system-level)
- Windows Update settings (POSSIBLE EFFECT - system-level)
- Maintenance settings (POSSIBLE EFFECT - system-level)
- Privacy experience settings (POSSIBLE EFFECT - system-level)

**Summary:** Out of 100+ legacy GPO settings:

- **5 settings are EFFECTIVE** (Ctrl+Alt+Del restrictions)
- **~15 settings POSSIBLY have effect** (system-level settings)
- **~80 settings have NO EFFECT** (Explorer/Start/Taskbar/Desktop restrictions when Explorer isn't running)

</details>

**Modern GPO Settings Required: 5**

1. **Remove Task Manager from Ctrl+Alt+Del** ✅

   ```text
   User Configuration\Policies\Administrative Templates\System\Ctrl+Alt+Del Options
   Policy: Remove Task Manager
   Setting: Enabled
   ```

2. **Remove Lock Computer from Ctrl+Alt+Del** ✅

   ```text
   User Configuration\Policies\Administrative Templates\System\Ctrl+Alt+Del Options
   Policy: Remove Lock Computer
   Setting: Enabled
   ```

3. **Remove Change Password from Ctrl+Alt+Del** ✅

   ```text
   User Configuration\Policies\Administrative Templates\System\Ctrl+Alt+Del Options
   Policy: Remove Change Password
   Setting: Enabled
   ```

4. **Disable switching users** ✅

   ```text
   User Configuration\Policies\Administrative Templates\System\Ctrl+Alt+Del Options
   Policy: Remove switching accounts
   Setting: Enabled
   ```

5. **Remove Sign Out from Ctrl+Alt+Del** ✅

   ```text
   User Configuration\Policies\Administrative Templates\System\Ctrl+Alt+Del Options
   Policy: Remove Logoff
   Setting: Enabled
   ```

**Why so few settings?**

- **BOTH approaches replace Explorer entirely** (legacy via kiosk.bat, modern via Shell Launcher)
- **BOTH eliminate Start Menu, Taskbar, Desktop** (no Explorer running in either case)
- The 100+ legacy GPO settings were **never needed** (legacy bloat/dead weight)
- Only the 5 Ctrl+Alt+Del restrictions are actually necessary (Ctrl+Alt+Del not controlled by shell replacement)
- Modern approach adds AppLocker (application execution control - not available in legacy)
- Modern approach uses Edge URL filtering (same as legacy)

---

## Security Architecture

### Defense in Depth Approach

The modern kiosk architecture implements a layered security model where each component provides independent protection. **Key improvement over legacy:** Assigned Access autologon uses auto-generated complex passwords stored in encrypted LSA secrets instead of registry-stored passwords.

```text
┌────────────────────────────────────────────────────────────────┐
│              Security Layer 1: Shell Isolation                 │
│  Shell Launcher replaces Explorer with Edge                    │
│  - No access to Windows UI (Start, Taskbar, Desktop)           │
│  - Shell breakout disabled (V2:AllowBreakout="false")          │
│  - AutoRestartShell on crash or exit                           │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│             Security Layer 2: Application Control              │
│  AppLocker enforces application allowlist                      │
│  - Windows App: Allowed                                        │
│  - Edge: Allowed                                               │
│  - All others: Blocked (including Explorer, Settings, etc.)    │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│            Security Layer 3: Network Access Control            │
│  Edge URL Filtering restricts browsing                         │
│  - URLBlocklist: * (block all by default)                      │
│  - URLAllowlist: Specific URLs only                            │
│  - Protocol handlers: ms-avd://, ms-cloudpc://, workspaces://  │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│            Security Layer 4: Input Control                     │
│  Keyboard Filter blocks dangerous key combinations             │
│  - Windows key (all combinations)                              │
│  - Alt+Tab, Alt+F4, Ctrl+Esc                                   │
│  - Ctrl+Alt+Del handled separately by GPO                      │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│            Security Layer 5: Session Management                │
│  Automatic logoff and credential cleanup                       │
│  - Windows App auto-logoff on close or idle                    │
│  - Certificate cleanup on logoff (certutil)                    │
│  - No persistent user data                                     │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│            Security Layer 6: System Lockdown (GPO)             │
│  Group Policy restrictions                                     │
│  - Ctrl+Alt+Del option removal (5 settings)                    │
│  - Optional: Hide drives, disable password for unlock          │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│    Security Layer 7: Assigned Access Autologon (IMPROVED)      │
│  Auto-generated complex password stored in encrypted LSA       │
│  - Password automatically created by Windows (highly complex)  │
│  - Stored in encrypted LSA secrets (vs. legacy: registry)      │
│  - Requires SYSTEM-level access to extract                     │
│  - No manual password management required                      │
└────────────────────────────────────────────────────────────────┘
```

### Autologon Security (Legacy vs. Modern)

**This is a critical security improvement in the modern architecture and a key discussion point for security evaluations.**

#### Legacy Approach: Registry-Based Autologon with Password

**Configuration:**

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
    AutoAdminLogon = "1"
    DefaultUserName = "wes10_user"
    DefaultPassword = "<password>"
```

**Security Vulnerabilities:**

1. **Password Stored on Disk** ⚠️ CRITICAL RISK
   - Password must be stored in registry (either plain text or LSA secret)
   - Anyone with physical access can extract the password:
     - Boot from USB drive and access registry hive
     - Use registry export tools as local administrator
     - Use LSA secret extraction tools (Mimikatz, etc.)
   - Password persists across reboots (permanent storage)

2. **Password Management Burden** ⚠️ OPERATIONAL RISK
   - Password must meet complexity requirements (if enforced)
   - Password rotation requires updating registry on all devices
   - Forgotten passwords require manual intervention
   - Password changes break autologon until registry updated

3. **Credential Theft Risk** ⚠️ SECURITY RISK
   - Stolen password can be used to log in as wes10_user from any system (if account is domain-joined or has network access)
   - Attacker with extracted password can:
     - Log in to the kiosk account remotely (if RDP/network logon allowed)
     - Use password on other systems if user reuses passwords
     - Perform offline password attacks if password hash obtained

4. **Audit and Compliance Concerns** ⚠️ COMPLIANCE RISK
   - Storing passwords in registry violates many security best practices
   - May not meet compliance requirements (PCI-DSS, HIPAA, NIST, etc.)
   - Security audits will flag this as a finding
   - Password storage location is well-known (easy target for attackers)

#### Modern Approach: Assigned Access Autologon

**Configuration:**

```xml
<ShellLauncherConfiguration>
  <Configs>
    <Config>
      <AutoLogonAccount/>  <!-- Password auto-generated and managed by Windows -->
      <Profile Id="{GUID}"/>
    </Config>
  </Configs>
</ShellLauncherConfiguration>
```

**Security Advantages:**

1. **Protected Password Storage** ✅ MAJOR IMPROVEMENT
   - Windows automatically generates a random, highly complex password
   - Password stored in **LSA (Local Security Authority) secrets** - encrypted storage
   - **Significantly more secure** than registry storage (DefaultPassword value)
   - LSA secrets are encrypted and require SYSTEM-level access to extract
   - Microsoft documentation: [Protecting the Automatic Logon Password](https://learn.microsoft.com/en-us/windows/win32/secauthn/protecting-the-automatic-logon-password)

2. **Automatic Password Management** ✅ OPERATIONAL IMPROVEMENT
   - Windows automatically generates and manages the password
   - No manual password configuration required
   - No password rotation needed (managed by Windows)
   - No forgotten password scenarios
   - Configuration is XML-based (no secrets in configuration files)

3. **Reduced Credential Theft Risk** ✅ SECURITY IMPROVEMENT
   - Password stored in encrypted LSA secrets (not plaintext registry)
   - Requires SYSTEM-level privileges to extract (vs. Administrator for registry)
   - Account is local-only (cannot be used for remote logon by default)
   - Cannot easily be used on other systems
   - Significantly reduces attack surface compared to legacy methods

4. **Compliance and Audit** ✅ COMPLIANCE IMPROVEMENT
   - Uses Windows-recommended LSA secrets for credential protection
   - Aligns with security best practices (encrypted credential storage)
   - Meets compliance requirements for credential protection
   - Modern, Microsoft-recommended method for kiosk autologon

#### Technical Deep Dive: How Assigned Access Autologon Works

**Assigned Access Autologon Mechanism:**

When you configure Shell Launcher with `<AutoLogonAccount/>`, Windows automatically creates the KioskUser0 account with a randomly generated, highly complex password stored in LSA secrets. This provides automatic logon functionality with better security than registry-based methods.

**Process Flow:**

1. System boots → Shell Launcher service starts
2. Windows creates KioskUser0 account (if it doesn't exist)
3. Windows generates a random, highly complex password
4. Password is stored in encrypted LSA secrets (not accessible to users/admins)
5. Shell Launcher uses the stored credentials to automatically log in KioskUser0
6. User is logged in automatically without password prompt

**Why This Is Secure:**

- Password is **automatically generated** (highly complex, not guessable)
- Password stored in **encrypted LSA secrets** (requires SYSTEM-level access to extract)
- LSA secrets are more secure than registry storage
- Only SYSTEM-level processes can access LSA secrets
- Password is automatically managed by Windows (no manual rotation needed)
- Account is local-only by default (cannot be used for remote authentication)

#### Security Comparison Summary

| Aspect | Legacy (Registry Autologon) | Modern (Assigned Access Autologon) | Winner |
|--------|---------------------------|----------------------|--------|
| **Password Storage** | Registry (HKLM\\Winlogon) | Encrypted LSA secrets | ✅ Modern |
| **Password Complexity** | User-defined (may be weak) | Auto-generated (highly complex) | ✅ Modern |
| **Credential Extractability** | Yes (admin tools can read registry) | Yes but harder (requires SYSTEM-level LSA access) | ✅ Modern |
| **Password Rotation** | Required (manual update) | Automatic (managed by Windows) | ✅ Modern |
| **remote Login Risk** | Yes (if password extracted) | Limited (local account, LSA-protected) | ✅ Modern |
| **Compliance** | ⚠️ May violate policies (registry storage) | ✅ Meets best practices (LSA secrets) | ✅ Modern |
| **Attack Surface** | Password in registry (admin-accessible) | Password in encrypted LSA secrets (SYSTEM-only) | ✅ Modern |
| **Audit Findings** | ⚠️ Will be flagged (weak storage) | ✅ Will pass (proper credential protection) | ✅ Modern |
| **User Account** | wes10_user (manual password) | KioskUser0 (auto-generated password) | ✅ Modern |

**Conclusion:** The modern Assigned Access autologon approach is **significantly more secure** than legacy registry-based autologon. Windows automatically generates a highly complex password and stores it in encrypted LSA secrets rather than the registry. This alone is a compelling reason to migrate, even if the UWP protocol handler issue didn't exist.

**For Security Evaluators:** The use of encrypted LSA secrets for credential storage (vs. registry storage) addresses critical security concerns about credential protection (CWE-522: Insufficiently Protected Credentials). The modern approach aligns with NIST SP 800-63B guidelines and industry best practices for credential management.

#### ⚠️ CRITICAL: Group Policy Settings That Break Assigned Access Autologon

**VERIFIED:** Based on real-world testing, only the following settings **actually break** Assigned Access autologon. Password policies do NOT affect Assigned Access autologon functionality.

**🚫 Settings That Break Autologon (VERIFIED):**

1. **Interactive logon: Message text for users attempting to log on** (LegalNoticeText)
   - **STIG Findings:** Multiple STIGs require legal notices (e.g., V-253283)
   - Policy Path: `Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options`
   - Registry: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeText`
   - **Impact:** ⚠️ **CRITICAL** - Forces interactive user acknowledgment, **completely breaks autologon**
   - **Microsoft Documentation:** "This registry change does not work if the Logon Banner value is defined" ([Source](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon))
   - **Required Setting:** **Not Configured** or **Empty** (no legal notice)
   - **Mitigation:** Display legal notice within kiosk app instead of at OS logon screen

2. **Interactive logon: Message title for users attempting to log on** (LegalNoticeCaption)
   - **STIG Findings:** Multiple STIGs require legal notices (e.g., V-253283)
   - Policy Path: `Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options`
   - Registry: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeCaption`
   - **Impact:** ⚠️ **CRITICAL** - Forces interactive user acknowledgment, **completely breaks autologon**
   - **Required Setting:** **Not Configured** or **Empty** (no legal notice caption)
   - **Mitigation:** Display legal notice within kiosk app instead of at OS logon screen

3. **Machine inactivity limit** (MachineInactivityTimeout)
   - Policy Path: `Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options → Interactive logon: Machine inactivity limit`
   - Registry: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs`
   - **Impact:** ⚠️ **CRITICAL** - Can interrupt kiosk sessions and require re-authentication
   - **Required Setting:** **Not Configured** or **0** (disabled)
   - **Mitigation:** Disable for kiosk systems or set to a very high value

**✅ Settings That Do NOT Break Autologon (VERIFIED):**

The following settings were previously thought to break autologon but have been **verified to NOT affect** Assigned Access autologon:

- ✅ **Password complexity requirements** - No impact on Assigned Access autologon
- ✅ **Minimum password length** - No impact on Assigned Access autologon (including STIG requirement of ≥14 characters)
- ✅ **Maximum password age** - No impact on Assigned Access autologon (including STIG requirement of ≤60 days)
- ✅ **Account lockout threshold** - No impact on Assigned Access autologon
- ✅ **Exchange ActiveSync (EAS) policies** - Documented as breaking autologon, but not verified in testing

**Why Password Policies Don't Break Assigned Access Autologon:**

Assigned Access autologon stores the password in LSA secrets, and Windows automatically manages it. The password is automatically generated as a highly complex password (random, long, complex). Therefore:

- Password complexity requirements can be enforced without affecting autologon
- Minimum password length requirements (including STIG V-253303: ≥14 chars) don't break autologon
- Maximum password age requirements (including STIG V-253301: ≤60 days) don't break autologon
- The KioskUser0 account has a real password stored in LSA secrets, it's just managed automatically by Windows

**🔍 Validation Commands:**

```powershell
# Check for policies that actually break autologon
$autologonBlockers = @()

# Check for legal notice (breaks autologon)
$legalNoticeText = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LegalNoticeText" -ErrorAction SilentlyContinue
$legalNoticeCaption = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LegalNoticeCaption" -ErrorAction SilentlyContinue

if ($legalNoticeText.LegalNoticeText -and $legalNoticeText.LegalNoticeText.Length -gt 0) {
    $autologonBlockers += "❌ LegalNoticeText is set (WILL BREAK AUTOLOGON)"
} else {
    $autologonBlockers += "✅ LegalNoticeText is not set"
}

if ($legalNoticeCaption.LegalNoticeCaption -and $legalNoticeCaption.LegalNoticeCaption.Length -gt 0) {
    $autologonBlockers += "❌ LegalNoticeCaption is set (WILL BREAK AUTOLOGON)"
} else {
    $autologonBlockers += "✅ LegalNoticeCaption is not set"
}

# Check for machine inactivity timeout (breaks autologon)
$inactivityTimeout = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "InactivityTimeoutSecs" -ErrorAction SilentlyContinue
if ($inactivityTimeout.InactivityTimeoutSecs -and $inactivityTimeout.InactivityTimeoutSecs -gt 0) {
    $autologonBlockers += "⚠️ InactivityTimeoutSecs is set to $($inactivityTimeout.InactivityTimeoutSecs) (CAN INTERRUPT KIOSK)"
} else {
    $autologonBlockers += "✅ InactivityTimeoutSecs is not set or disabled"
}

$autologonBlockers
```

**📋 Troubleshooting:**

If Assigned Access autologon fails after configuration:

1. **Check for legal notice or inactivity timeout (these break autologon):**

   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" | Select-Object LegalNoticeText, LegalNoticeCaption, InactivityTimeoutSecs
   ```

2. **Verify KioskUser0 account exists:**

   ```powershell
   Get-LocalUser -Name KioskUser0
   ```

3. **Check Event Logs:**

   ```powershell
   Get-WinEvent -LogName System | Where-Object {$_.Id -eq 7000 -or $_.Id -eq 7001} | Select-Object -First 10
   Get-WinEvent -LogName Microsoft-Windows-AssignedAccess/Admin | Select-Object -First 10
   ```

4. **Check for Group Policy conflicts:**

   - Domain GPOs may override local policies
   - Use `gpresult /h C:\temp\gpreport.html` to identify conflicting policies
   - Look specifically for: LegalNoticeText, LegalNoticeCaption, InactivityTimeoutSecs
   - Contact domain administrator to create GPO exception for kiosk OUs

**🏢 Enterprise Deployments:**

For enterprise environments with STIG compliance requirements:

- **Option 1 (Recommended):** Create a separate Organizational Unit (OU) for kiosk devices and link a GPO that exempts them from:
  - Legal notice requirements (LegalNoticeText/LegalNoticeCaption)
  - Machine inactivity timeout (InactivityTimeoutSecs)
- **Option 2:** Use WMI filtering on domain GPOs to exclude kiosk machines based on naming convention or other criteria
- **Option 3:** Apply compensating controls (display legal notice in kiosk app) and document in System Security Plan (SSP)

**📋 STIG Compliance Considerations:**

When applying Windows 11 STIG (Security Technical Implementation Guide) to kiosk systems:

**✅ Compatible STIG Settings (Verified - No Impact on Autologon):**
- ✅ **V-253304** (Password complexity = Enabled): No impact on Assigned Access autologon
- ✅ **V-253303** (Minimum password length = 14 chars): No impact on Assigned Access autologon
- ✅ **V-253301** (Maximum password age ≤ 60 days): No impact on Assigned Access autologon
- ✅ **Account lockout policies**: No impact on Assigned Access autologon
- ✅ **All other password policies**: No impact on Assigned Access autologon

**❌ Incompatible STIG Settings (Verified - BREAKS Autologon):**
- ❌ **V-253283** (Legal notice text/caption): **BREAKS autologon** - must be disabled or compensated
- ❌ **Interactive logon message requirements**: **BREAKS autologon** - display within kiosk app instead
- ❌ **Machine inactivity limit**: **CAN INTERRUPT** kiosk sessions - must be disabled or set very high

**Recommended Approach for STIG-Compliant Kiosks:**
1. Apply domain-level STIG GPOs including ALL password policies (these work fine with Assigned Access autologon)
2. Create kiosk-specific OU with GPO exceptions for:
   - Legal notice text/caption (set to empty)
   - Machine inactivity timeout (set to 0 or disabled)
3. Display legal notices within the kiosk application itself (e.g., splash screen on app startup)
4. Document compensating controls in your System Security Plan (SSP):
   - Legal notice displayed in application instead of OS logon
   - Physical security controls prevent unauthorized access
   - Kiosk-specific hardening provides equivalent protection

**Reference Script:**

A previous version of this solution included `Apply-STIGAutoLogonExceptions.ps1` ([GitHub](https://github.com/Azure/WindowsAppKiosk/blob/df11e17d2bd3c4fc4837a8f73005ed03f161a432/source/Scripts/Configuration/Apply-STIGAutoLogonExceptions.ps1)) which correctly addressed:
- ✅ **LegalNoticeCaption** (verified - breaks autologon)
- ✅ **LegalNoticeText** (verified - breaks autologon)
- ✅ **InactivityTimeoutSecs** (verified - interrupts kiosk sessions)
- ⚠️ **Lsa\Pku2u\AllowOnlineID** (not verified as necessary)

The script's focus on legal notices and inactivity timeout was correct based on real-world testing.

### Application Control (AppLocker)

AppLocker provides **execution control** by defining which applications can run for the kiosk user. This is a critical security layer that prevents users from launching unauthorized applications even if they somehow gain access to the Windows UI.

**Legacy Comparison:** The previous configuration used a **DisallowRun list** configured via Group Policy, which contained a long list of blocked executables. Many of these blocked executables were "dead weight" (unnecessary) because Explorer never ran, eliminating the primary launch mechanism. AppLocker represents a **modern approach** with targeted allowlist-based control that is more maintainable and auditable than a large blocklist.

#### AppLocker Configuration

**Policy File:** `source/AppLocker/ShellLauncher.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="{GUID}" Name="All files" Description="Allow all" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*"/>
      </Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Exe" EnforcementMode="AuditOnly" Enforcement Name="KioskUser0">
    <!-- Block Edge explicitly for kiosk user -->
    <FilePathRule Id="{GUID}" Name="Block Edge" UserOrGroupSid="S-1-5-21-*-1003" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES(X86)%\Microsoft\Edge\Application\msedge.exe"/>
      </Conditions>
    </FilePathRule>
    
    <!-- Block Notepad -->
    <FilePathRule Id="{GUID}" Name="Block Notepad" UserOrGroupSid="S-1-5-21-*-1003" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%SYSTEM32%\notepad.exe"/>
      </Conditions>
    </FilePathRule>
    
    <!-- Block Search UI -->
    <FilePathRule Id="{GUID}" Name="Block SearchUI" UserOrGroupSid="S-1-5-21-*-1003" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%SYSTEMROOT%\SystemApps\Microsoft.Windows.Search_*\SearchApp.exe"/>
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
```

**Key Design Principles:**

1. **Default Allow for Administrators/Users** (S-1-1-0 = Everyone)
   - Allows normal operation for non-kiosk users
   - Critical for system administrators to troubleshoot

2. **Explicit Deny for KioskUser0** (S-1-5-21-*-1003 = RID 1003)
   - Blocks Edge (prevents manual launch; only Shell Launcher can start it)
   - Blocks Notepad (common file editor, could be exploited)
   - Blocks Search UI (could be used to browse file system)

3. **Enforcement Mode: AuditOnly for Testing**
   - Initially set to AuditOnly for testing
   - Switch to Enabled for production deployment
   - Allows validation without blocking legitimate use during testing

**Why Block Edge for KioskUser0?** 🤔

Edge is launched automatically by Shell Launcher with specific kiosk parameters. Blocking direct execution prevents users from launching Edge manually (e.g., via file type associations or other mechanisms) **without** those kiosk restrictions, which would bypass the kiosk mode.

#### AppLocker Deployment

```powershell
# Apply AppLocker policy
Set-AppLockerPolicy -XmlPolicy "C:\Path\To\ShellLauncher.xml" -Merge

# Enable AppLocker service
Set-Service -Name AppIDSvc -StartupType Automatic
Start-Service -Name AppIDSvc
```

### Network Access Control (Edge URL Filtering)

Edge URL filtering provides **network access control** by defining which URLs the user can navigate to. This is implemented using Edge's policy-based URL filtering capabilities.

#### Edge Policy Configuration

**Registry Location:** `HKLM:\SOFTWARE\Policies\Microsoft\Edge`

**Key Policies:**

1. **URLBlocklist** (Block all by default)

   ```text
   HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist
   1 = "*"
   ```

   - Blocks ALL URLs by default (deny-by-default security model)

2. **URLAllowlist** (Allow specific URLs only)

   ```text
   HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLAllowlist
   1 = "file://*"                       (local files)
   2 = "ms-avd://*"                     (Azure Virtual Desktop)
   3 = "ms-cloudpc://*"                 (Windows 365)
   4 = "evo://*"                        (Evo RDP client - legacy)
   5 = "workspaces://*"                 (Amazon Workspaces)
   6 = "portal.azure.com"               (Azure Portal)
   7 = "*.windows.net"                  (Azure Windows App web)
   8 = "*.microsoft.com"                (Microsoft services)
   ```

   - Allows only specified URLs (allowlist-based security model)
   - Protocol handlers (ms-avd://, etc.) always allowed for Windows App
   - Custom URLs added via `-AllowedUrls` parameter

3. **AutoLaunchProtocolsFromOrigins** (Auto-launch protocol handlers)

   ```text
   HKLM:\SOFTWARE\Policies\Microsoft\Edge\AutoLaunchProtocolsFromOrigins
   [
     {
       "allowed_origins": ["*"],
       "protocol": "ms-avd"
     },
     {
       "allowed_origins": ["*"],
       "protocol": "ms-cloudpc"
     },
     {
       "allowed_origins": ["*"],
       "protocol": "workspaces"
     }
   ]
   ```

   - Allows protocol links to launch apps without user confirmation
   - Critical for seamless Windows App launch experience

#### URL Filtering Security Model

```text
User clicks link or enters URL
         ↓
┌─────────────────┐
│ URLBlocklist    │ ← Blocks ALL URLs (*)
│ Check           │
└────────┬────────┘
         ↓
    Blocked by
    Blocklist?
         ↓
        YES → ┌───────────────┐
              │ URLAllowlist  │ ← Check if specifically allowed
              │ Check         │
              └───────┬───────┘
                      ↓
                  Is URL in
                  Allowlist?
                      ↓
                     YES → Allow navigation
                     NO  → Block navigation (error page)
```

**Subdomain Matching:**

Per [Microsoft Edge URL filtering](https://learn.microsoft.com/en-us/deployedge/edge-learnmmore-url-list-filter), hostname entries automatically match all subdomains:

- `microsoft.com` matches `www.microsoft.com`, `login.microsoft.com`, etc.
- No wildcard needed for subdomain matching

### Session Management and Certificate Cleanup

#### Windows App Auto-Logoff

The Windows App includes built-in auto-logoff functionality configured via registry:

**Registry Location:** `HKLM:\SOFTWARE\Microsoft\MSRDC\Policies`

**Configuration Options:**

| Setting Value | Behavior | Use Case |
|--------------|----------|----------|
| `Disabled` | No automatic logoff | Persistent sessions, controlled environments |
| `ResetAppOnCloseOnly` | Logoff when Windows App closes | Shared workstations |
| `ResetAppAfterConnection` | Logoff after each connection closes | High-security environments |
| `ResetAppOnCloseOrIdle` | Logoff on close OR idle timeout | **Public kiosks (recommended)** |

**Registry Keys:**

```text
HKLM:\SOFTWARE\Microsoft\MSRDC\Policies
    AutomaticReconnection = 0 (DWORD)
    RDCleanSession        = [ResetAppOnCloseOrIdle] (String)
    RDCleanSessionTimeIntervalMinutes = 15 (DWORD)
```

#### Certificate Cleanup on Logoff

When users authenticate to Azure Virtual Desktop or Windows 365, temporary certificates may be stored in the user's certificate store. These must be cleaned up on logoff to prevent credential leakage between sessions.

**Implementation: Group Policy Logoff Script**

**File:** `C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Scripts\Logoff\ClearCertificates.bat`

```batch
@echo off
REM Clear user certificates on logoff
REM Runs in user context (not SYSTEM)
certutil -user -delstore MY *.*
```

**Group Policy Configuration:**

**File:** `C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Scripts\scripts.ini`

```ini
[Logoff]
0CmdLine=ClearCertificates.bat
0Parameters=
```

**Why certutil?**

- `certutil -user -delstore MY *.*` deletes all certificates from the user's Personal store
- Runs in user context (via Group Policy logoff script)
- Ensures no credentials persist between sessions
- Removes temporary certificates from Azure AD/Windows App authentication

#### Logon Script: User Session Monitoring

The logon script launches a VBScript that monitors the Windows App process and triggers logoff when it closes.

**Implementation: Group Policy Logon Script**

**File:** `C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Scripts\Logon\LaunchUserMonitor.bat`

```batch
@echo off
REM Launch user session monitor silently
cscript //B //Nologo LocalUserlogoff.vbs
```

**Group Policy Configuration:**

**File:** `C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\User\Scripts\scripts.ini`

```ini
[Logon]
0CmdLine=LaunchUserMonitor.bat
0Parameters=
```

### System Lockdown

#### Group Policy Restrictions

While the modern architecture requires far fewer GPO settings than legacy, some critical restrictions remain necessary:

**Ctrl+Alt+Del Options (5 settings):** ✅

These settings are still required because Ctrl+Alt+Del is handled by the Windows Secure Desktop (Winlogon), which is separate from Shell Launcher. Users can still press Ctrl+Alt+Del to access system functions.

1. Remove Task Manager
2. Remove Lock Computer
3. Remove Change Password
4. Remove Sign Out
5. Disable switching users

**Optional Settings:**

- **Hide and Restrict Drives:** Prevent access to local drives if File Explorer is somehow launched
- **Disable Password for Unlock:** Simplify resume from sleep (no password required)
- **Privacy Settings:** Disable advertising ID, disable Spotlight, etc.

#### Keyboard Filter

**Purpose:** Block dangerous key combinations that could bypass kiosk restrictions.

**Blocked Keys:**

- Windows key (all combinations)
- Alt+Tab (task switching)
- Alt+F4 (close window)
- Ctrl+Esc (Start Menu)
- Ctrl+Alt+Del (handled separately by GPO)

**Implementation:**

```powershell
# Enable Keyboard Filter feature
Enable-WindowsOptionalFeature -Online -FeatureName "Client-KeyboardFilter" -All -NoRestart

# Configure blocked keys (done via scheduled task after reboot)
# See Set-KeyboardFilterConfiguration.ps1 for details
```

**Keyboard Filter is configured via a scheduled task** that runs after the feature is enabled and the system is rebooted. The task uses WMI to configure the filter.

---

## Protocol Handler Architecture

### Understanding Protocol Handlers

Protocol handlers are registered URI schemes that allow web links to launch native applications. Windows App relies on protocol handlers to launch connections directly from web portals.

#### Registered Protocol Handlers

| Protocol | Application | Purpose |
|----------|-------------|---------|
| `ms-avd://` | Windows App (UWP) | Azure Virtual Desktop connections |
| `ms-cloudpc://` | Windows App (UWP) | Windows 365 Cloud PC connections |
| `workspaces://` | Amazon Workspaces (Win32) | Amazon Workspaces client launchconnections |
| `evo://` | Evolution RDP Client (Win32) | Legacy RDP client (if installed) |

#### Protocol Handler Flow

```text
User clicks link:
  <a href="ms-avd:connect?workspaceId=123&resourceId=456">Launch Desktop</a>

         ↓

Edge receives protocol URL
         ↓

Edge checks AutoLaunchProtocolsFromOrigins policy
         ↓

Protocol auto-launch allowed?
         ↓
        YES → ┌───────────────────────────┐
              │ Windows accesses registry │
              │ HKLM:\SOFTWARE\Classes\   │
              │ ms-avd                    │
              └────────┬──────────────────┘
                       ↓
              Launches protocol handler:
              "C:\Program Files\WindowsApps\
               Microsoft.RemoteDesktop_*\
               ms-avd.exe" "%1"
                       ↓
              Windows App (UWP) launches
                       ↓
              Windows App processes URL
                       ↓
              Connects to specified resource
```

### Why Legacy Approach Failed with Protocol Handlers

**GPO Registry-Based Shell Replacement Issues:**

1. **Protocol Handler Activation Failure** (ROOT CAUSE)
   - Problem: GPO registry method (`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Shell`)
   - This specific registry location breaks UWP protocol handler activation pipeline
   - When users click ms-avd:// links: **SILENT FAIL** (nothing happens, no error)
   - Windows does not route the protocol handler request to the UWP application
   - Result: Windows App never launches, users see no feedback

2. **Shell Context Issue**
   - GPO registry-based shell replacement does not provide full UWP shell context
   - Protocol handlers require proper shell services to activate UWP applications
   - kiosk.bat itself is fine (it's just a launcher), but the GPO METHOD breaks things
   - The two-step process (GPO registry → kiosk.bat → Edge) loses UWP context

3. **Legacy Registry Location**
   - The `Policies\System\Shell` registry location is a legacy method from Windows XP era
   - Modern UWP activation system does not properly support this method
   - UWP protocol handler activation expects Explorer or modern shell replacement (Shell Launcher)

**Shell Launcher Solution:**

Shell Launcher v2 provides a **proper shell environment** for UWP protocol handlers while still replacing Explorer with Edge:

- Shell Launcher uses modern CSP (WMI Bridge) instead of legacy GPO registry
- Provides full shell context for UWP protocol handler activation
- Proper integration with Windows UWP activation pipeline
- Protocol handlers route correctly to UWP applications

**Result:** Protocol handlers work correctly with Shell Launcher. Clicking ms-avd:// links launches Windows App as expected.

### Protocol Handler Registration

Windows App registers its protocol handlers during installation. The modern architecture ensures these registrations remain functional.

**Registry Example:** `HKLM:\SOFTWARE\Classes\ms-avd`

```text
HKLM:\SOFTWARE\Classes\ms-avd
    (Default) = "URL:ms-avd Protocol"
    URL Protocol = ""
```

---

## Group Policy Implementation

### Non-Administrators Group Policy Structure

Both legacy and modern architectures use the **Non-Administrators Group Policy** (applied to SID `S-1-5-32-545`, the built-in Users group). This GPO is stored locally and applies to all standard users.

**Location:** `C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545\`

#### Directory Structure

```text
C:\Windows\System32\GroupPolicyUsers\
└── S-1-5-32-545\         (Non-Administrators SID)
    ├── GPT.INI            (GPO metadata: version, display name)
    ├── Registry.pol       (Compiled GPO registry settings)
    │
    └── User\
        └── Scripts\
            ├── scripts.ini       (Logon/Logoff script configuration)
            │
            ├── Logon\
            │   ├── LaunchUserMonitor.bat
            │   └── LocalUserlogoff.vbs
            │
            └── Logoff\
                └── ClearCertificates.bat
```

#### scripts.ini Format

The `scripts.ini` file defines logon and logoff scripts. It must be **Unicode-encoded** (UTF-16 LE) for Windows to recognize it.

**Example:**

```ini
[Logon]
0CmdLine=LaunchUserMonitor.bat
0Parameters=

[Logoff]
0CmdLine=ClearCertificates.bat
0Parameters=
```

**Format Rules:**

- Unicode (UTF-16 LE) encoding required
- `[Logon]` and `[Logoff]` sections
- `0CmdLine`, `1CmdLine`, etc. for multiple scripts (increment index)
- `0Parameters`, `1Parameters`, etc. for command-line parameters
- Script paths relative to `User\Scripts\Logon\` or `User\Scripts\Logoff\`

#### GPT.INI Format

**Example:**

```ini
[General]
Version=65537
displayName=Non-Administrators
```

- `Version`: High word = Computer settings version, Low word = User settings version
- `displayName`: Friendly name for the GPO

### Logon Script: LaunchUserMonitor.bat

**Purpose:** Start user session monitoring to detect Windows App closure and trigger logoff.

**File:** `LaunchUserMonitor.bat`

```batch
@echo off
REM Launch user session monitor silently
REM Uses cscript with //B (batch mode - no logo/prompts) and //Nologo flags
cscript //B //Nologo LocalUserlogoff.vbs
```

**Key Points:**

- `//B` flag: Suppress user prompts and script errors (batch mode)
- `//Nologo` flag: Suppress copyright banner
- Result: VBScript runs completely silently in background

### Logoff Script: ClearCertificates.bat

**Purpose:** Clean up user certificates on logoff to prevent credential leakage between sessions.

**File:** `ClearCertificates.bat`

```batch
@echo off
REM Clear user certificates on logoff
certutil -user -delstore MY *.*
```

**Key Points:**

- Runs in **user context** (via Group Policy logoff script)
- `-user` flag: Access user certificate store (not machine store)
- `-delstore MY *.*`: Delete all certificates from Personal (MY) store
- Critical for shared kiosk security

### Script Deployment

Scripts are deployed by the `Set-WindowsAppFromEdgeKioskSettings.ps1` installation script during kiosk configuration.

**EventIds:**

- EventId 120: Create GroupPolicyUsers folder structure
- EventId 121: Create LaunchUserMonitor.bat logon script
- EventId 122: Copy LocalUserlogoff.vbs script
- EventId 123: Create ClearCertificates.bat logoff script
- EventId 124: Create scripts.ini configuration file
- EventId 125: Update GPT.INI version for GPO refresh
- EventId 126: Force Group Policy update

---

## Migration Considerations

### Pre-Migration Assessment

Before migrating from legacy GPO-driven kiosk to Shell Launcher, assess your environment:

#### Checklist

| Item | Consideration |
|------|---------------|
| **Operating System** | Windows 10 1903+ or Windows 11 required for Shell Launcher v2 |
| **Windows Edition** | Enterprise, Education, or IoT Enterprise required |
| **Current Kiosk Type** | Identify if using GPO shell replacement, Assigned Access v1, or other |
| **Application Compatibility** | Verify all required apps work with UWP environment |
| **Protocol Handlers** | Document all protocol handlers your kiosk uses (ms-avd, etc.) |
| **Customizations** | Identify custom GPO settings, scripts, branding |
| **Browser Requirements** | Verify Edge compatibility with your web portals |
| **Network Restrictions** | Document required URLs for allowlist |
| **User Expectations** | Plan for UI/UX change (Explorer → Edge fullscreen) |

### Migration Options

#### Option 1: Clean Reinstall (Recommended)

**Process:**

1. Run `Remove-LegacyKioskSettings.ps1` from the repository
2. Verify legacy settings removed (no kiosk.bat, GPO deleted)
3. Restart system
4. Run `Set-WindowsAppFromEdgeKioskSettings.ps1 -InstallWindowsApp -WindowsAppAutoLogoffConfig ResetAppOnCloseOrIdle -WindowsAppAutoLogoffTimeInterval 15`
5. Restart system
6. Verify kiosk functionality

**Advantages:**

- Clean slate, no residual configurations
- Reduced risk of conflicts
- Easier troubleshooting

**Disadvantages:**

- Requires two reboots
- More disruptive

### Migration Testing Plan

**Phase 1: Lab Testing**

1. Set up test device with legacy kiosk configuration
2. Perform migration using Option 1 (clean reinstall)
3. Verify all functionality:
   - Auto-logon works
   - Edge launches in kiosk mode
   - Windows App launches via protocol handler
   - AVD/W365 connections succeed
   - Auto-logoff functions correctly
   - Certificate cleanup works
4. Test edge cases:
   - Forced Edge crash (verify auto-restart)
   - Network disconnection during connection
   - Idle timeout behavior

**Phase 2: Pilot Deployment**

1. Select 5-10 representative devices
2. Schedule migration during maintenance window
3. Migrate using tested procedure
4. Monitor for 1-2 weeks
5. Collect user feedback

**Phase 3: Production Rollout**

1. Document final migration procedure
2. Schedule rollout in waves (e.g., 10% per week)
3. Provide user communication about UI changes
4. Monitor helpdesk tickets for issues
5. Adjust procedure as needed

### Post-Migration Validation

#### Functional Validation

| Test | Expected Outcome |
|------|------------------|
| **Auto-Logon** | KioskUser0 logs in automatically after boot |
| **Shell Replacement** | Edge launches in fullscreen kiosk mode (no Explorer) |
| **URL Display** | Configured kiosk URL displays correctly |
| **Windows App Launch** | Clicking ms-avd:// link launches Windows App |
| **AVD Connection** | User can authenticate and connect to AVD/W365 resources |
| **Auto-Logoff** | Windows App triggers logoff on close or idle |
| **Certificate Cleanup** | Certificates removed from user store on logoff |
| **Keyboard Filter** | Windows key, Alt+Tab blocked |
| **Ctrl+Alt+Del** | Shows limited options (no Task Manager, Lock, Sign Out, etc.) |
| **Protocol Handlers** | ms-avd://, ms-cloudpc://, workspaces:// all launch correctly |

#### Security Validation

| Test | Expected Outcome |
|------|------------------|
| **Application Execution** | Only Windows App can run (test launching Explorer, Settings) |
| **URL Navigation** | Only allowed URLs accessible in Edge |
| **File System Access** | No access to file system (Edge restrictions active) |
| **System Settings** | No access to Windows Settings |
| **Command Prompt** | Cannot launch cmd.exe or PowerShell |
| **Registry Editing** | Cannot launch regedit.exe |

#### Logging Validation

Check Event Viewer for successful configuration:

**Event Log:** `Applications and Services Logs > Windows-App-Kiosk`

**Expected Events:**

- EventId 0-9: Initialization events
- EventId 50-59: Shell Launcher configuration events
- EventId 110-119: AppLocker configuration events
- EventId 199: Completion event

### Rollback Plan

If migration fails and you need to revert to legacy configuration:

**Emergency Rollback:**

1. Boot to Safe Mode (hold LEFT SHIFT + press ENTER during Windows boot for advanced options)
2. Log in as local Administrator
3. Delete Shell Launcher configuration:

   ```powershell
   Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData" -Recurse | Remove-Item -Force
   ```

4. Re-apply legacy GPO settings (restore from backup)
5. Restart system

**Prepared Rollback:**

- Before migration, export legacy GPO settings:

  ```powershell
  Backup-GPO -Name "Non-Administrators" -Path "C:\Backup\GPO"
  ```

- Keep copy of kiosk.bat and legacy scripts
- Document legacy configuration for restoration if needed

---

## Security Validation

### Security Testing Methodology

Use this methodology to validate the security posture of the deployed kiosk:

#### Test 1: Shell Breakout Attempts

**Objective:** Verify users cannot access Windows Explorer, Start Menu, Taskbar, or Desktop.

**Tests:**

1. Press Windows key → Expected: No response (Keyboard Filter blocks)
2. Press Ctrl+Esc → Expected: No response (Keyboard Filter blocks)
3. Press Alt+Tab → Expected: No response (Keyboard Filter blocks)
4. Press F11 (attempt to exit fullscreen) → Expected: No effect (Edge ignores in kiosk mode)
5. Right-click Edge window → Expected: No context menu

**Pass Criteria:** All attempts fail silently; no access to Windows UI.

#### Test 2: Application Execution Control

**Objective:** Verify only Windows App can run; all other applications blocked.

**Tests:**

1. Attempt to launch Explorer (via file:/// URL and C:\Windows\explorer.exe path) → Expected: Blocked by AppLocker
2. Attempt to launch Command Prompt (via cmd.exe, cmd, command.com) → Expected: Blocked by AppLocker
3. Attempt to launch PowerShell (via powershell.exe) → Expected: Blocked by AppLocker
4. Attempt to launch Settings (via ms-settings:// protocol) → Expected: Blocked by AppLocker
5. Attempt to launch Registry Editor (via regedit.exe) → Expected: Blocked by AppLocker
6. Launch Windows App (via ms-avd:// protocol) → Expected: Launches successfully

**Pass Criteria:** Only Windows App can execute; all other applications blocked.

#### Test 3: Network Access Control

**Objective:** Verify Edge only allows navigation to approved URLs.

**Tests:**

1. Navigate to `https://www.google.com` → Expected: Blocked (not in allowlist)
2. Navigate to `https://www.bbc.com` → Expected: Blocked (not in allowlist)
3. Navigate to `https://portal.azure.com` → Expected: Allowed (if in allowlist)
4. Navigate to configured kiosk URL → Expected: Allowed
5. Test protocol handler: `ms-avd://` → Expected: Launches Windows App

**Pass Criteria:** Only allowlisted URLs accessible; all others blocked.

#### Test 4: Ctrl+Alt+Del Restrictions

**Objective:** Verify limited options on Secure Desktop.

**Tests:**

1. Press Ctrl+Alt+Del → Expected: Limited options shown
2. Check for Task Manager option → Expected: Not present (hidden by GPO)
3. Check for Lock option → Expected: Not present (hidden by GPO)
4. Check for Sign Out option → Expected: Not present (hidden by GPO)
5. Check for Change Password option → Expected: Not present (hidden by GPO)
6. Check for Switch User option → Expected: Not present (hidden by GPO)

**Pass Criteria:** Only Cancel and power options available; all others hidden.

#### Test 5: Session Reset and Credential Cleanup

**Objective:** Verify automatic logoff and certificate cleanup.

**Tests:**

1. Launch Windows App via protocol handler → Expected: Windows App launches
2. Authenticate to AVD/W365 (may store certificates) → Expected: Authentication succeeds
3. Close Windows App → Expected: Auto-logoff after configured interval
4. Reboot and log in as different user
5. Check certificate store: `certutil -user -store MY` → Expected: No certificates present

**Pass Criteria:** Certificates cleared after logoff; no credential leakage between sessions.

### Penetration Testing Scenarios

For organizations requiring formal security validation:

#### Scenario 1: Privilege Escalation

**Attempts:**

- Exploit Edge vulnerabilities to spawn processes
- Use file type associations to launch unauthorized apps
- Manipulate protocol handlers to execute code
- Use accessibility features to bypass restrictions

**Mitigations:**

- AppLocker blocks unauthorized executables
- Edge URL filtering prevents malicious URLs
- Keyboard Filter blocks accessibility shortcuts
- GPO disables accessibility features for kiosk user

#### Scenario 2: Data Exfiltration

**Attempts:**

- Use Edge to navigate to attacker-controlled website and exfiltrate data
- Use Windows App to copy files to AVD session, then exfiltrate
- Screenshot capture and transmission

**Mitigations:**

- Edge URL allowlist prevents navigation to unauthorized sites
- Windows App runs in isolated AppContainer (UWP)
- No direct file system access from Edge or Windows App
- Keyboard Filter blocks screenshot shortcuts (PrintScreen)

#### Scenario 3: Persistence

**Attempts:**

- Modify registry to establish persistence
- Create scheduled tasks
- Modify startup files

**Mitigations:**

- Kiosk user has standard (non-administrator) privileges
- Cannot modify HKLM registry
- Cannot create scheduled tasks (requires admin rights)
- No access to startup folders (no Explorer access)

---

## Threat Model and Mitigations

### Threat Actors

| Actor | Motivation | Capability |
|-------|------------|------------|
| **Curious User** | Explore system, access unauthorized content | Low (uses UI only) |
| **Malicious Insider** | Data theft, sabotage | Medium (may have technical knowledge) |
| **External Attacker** | Remote exploitation, data breach | High (may exploit software vulnerabilities) |

### Attack Surface Analysis

| Attack Vector | Risk Level | Mitigation |
|---------------|------------|------------|
| **Shell Breakout** | High | Shell Launcher isolation, Keyboard Filter, GPO restrictions |
| **Application Execution** | High | AppLocker allowlist, deny-by-default |
| **Network Access** | Medium | Edge URL filtering, protocol handler restrictions |
| **Credential Theft** | High | Certificate cleanup on logoff, auto-logoff on idle |
| **Physical Access** | Medium | Keyboard Filter, Ctrl+Alt+Del restrictions, automatic logon |
| **Software Vulnerabilities** | Medium | Edge auto-updates, Windows Update maintenance window |
| **Social Engineering** | Low | No user input required (auto-logon), limited UI |

### Mitigation Summary

| Threat | Mitigation | Residual Risk |
|--------|------------|---------------|
| **User launches unauthorized app** | AppLocker denies execution | **Low** - Small risk of AppLocker bypass |
| **User navigates to malicious website** | Edge URL allowlist blocks | **Low** - Well-tested Edge policy |
| **User attempts shell breakout** | Shell Launcher + Keyboard Filter | **Very Low** - Multiple layers |
| **Credentials persist between sessions** | Certificate cleanup + auto-logoff | **Very Low** - Validated script-based cleanup |
| **User disables kiosk mode** | Requires admin rights (not available) | **Very Low** - Privilege separation |
| **Software vulnerability exploited** | Defense in depth (multiple layers) | **Medium** - Zero-day vulnerabilities always possible |

---

## Conclusion

The evolution from legacy GPO-driven shell replacement to modern Shell Launcher represents a **significant architectural improvement** driven by technical requirements for UWP application support and modern protocol handlers. The modern approach provides:

✅ **Equivalent or superior security** through defense-in-depth  
✅ **Native UWP and protocol handler support** (Windows App functionality)  
✅ **Reduced maintenance complexity** (5 GPO settings vs. 100+)  
✅ **Improved reliability** (system-level enforcement, auto-restart)  
✅ **Better user experience** (purpose-built interface)  
✅ **Future compatibility** (aligned with Microsoft's modern Windows direction)  

**Key Takeaway:** The modern architecture is not just a different way to achieve the same goal—it enables capabilities that were **impossible** with the legacy approach (UWP support, reliable protocol handlers) while simplifying security and maintenance.

---

**Version:** 2026.02.24  
**Document Version:** 1.0  
**Maintained by:** Shawn Meyer, Microsoft

---

**Navigation:** [🏠 Overview](README.md) | [🏗️ Solution Overview](SOLUTION_OVERVIEW.md) | [⚙️ Implementation Guide](IMPLEMENTATION.md) | 🔒 Architecture Guide
