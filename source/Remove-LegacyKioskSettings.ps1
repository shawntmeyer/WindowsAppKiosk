<#
.SYNOPSIS
    Removes legacy kiosk configurations from previous versions or other kiosk implementations.

.DESCRIPTION
    This script safely removes legacy Windows kiosk configurations that may conflict with the current 
    Edge-based Windows App kiosk solution. It performs the following cleanup tasks:
    
    * Removes user/group-specific Local Group Policy Objects (GPOs)
    * Forces Group Policy updates to apply the removal
    * Logs all operations to the Windows-App-Kiosk event log
    
    This script is automatically called when using the -RemoveLegacySettings parameter with the main 
    Set-WindowsAppFromEdgeKioskSettings.ps1 script.

.PARAMETER EventLog
    The name of the Windows Event Log where operations will be logged. Default is 'Windows-App-Kiosk'.

.PARAMETER EventSource
    The event source name used for logging. Default is 'LegacyRemovalScript'.

.NOTES
    Author: Shawn Meyer, Microsoft
    Last Modified: 02/19/2026
    Version: 1.0.0
    
    This script should be run with SYSTEM privileges for proper operation.

.EXAMPLE
    .\Remove-LegacyKioskSettings.ps1
    
    Removes legacy kiosk settings using default event log settings.

.EXAMPLE
    .\Remove-LegacyKioskSettings.ps1 -EventLog "MyCustomLog" -EventSource "MySource"
    
    Removes legacy kiosk settings and logs to a custom event log.
#>
[CmdletBinding()]
param (
    [string]$EventLog = 'Windows-App-Kiosk',
    [string]$EventSource = 'LegacyRemovalScript'
)`

#region Set Variables
$script:FullName = $MyInvocation.MyCommand.Path
$script:Dir = Split-Path $script:FullName
$DirFunctions = Join-Path -Path $Script:Dir -ChildPath "Scripts\Functions"
$DirKiosk = Join-Path -Path $env:SystemDrive -ChildPath "KioskSettings"

#endregion Set Variables

#region Restart Script in 64-bit powershell if necessary

If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    $scriptArguments = $null
    Try {
        foreach ($k in $PSBoundParameters.keys) {
            switch ($PSBoundParameters[$k].GetType().Name) {
                "SwitchParameter" { if ($PSBoundParameters[$k].IsPresent) { $scriptArguments += "-$k " } }
                "String" { $scriptArguments += "-$k `"$($PSBoundParameters[$k])`" " }
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

#endregion Restart Script in 64-bit powershell if necessary

#region Initialization and Logging

$Functions = Get-ChildItem -Path $DirFunctions -Filter '*.ps1' -ErrorAction SilentlyContinue
ForEach ($Function in $Functions) {
    . "$($Function.FullName)"
}

If (-not [System.Diagnostics.EventLog]::SourceExists($EventSource) -or -not [System.Diagnostics.EventLog]::Exists($EventLog)) {
    Write-Verbose "Creating $EventLog | $EventSource log..."
    New-EventLog -LogName $EventLog -Source $EventSource -ErrorAction SilentlyContinue
    Do {
        Start-Sleep -Seconds 1
    } Until ([System.Diagnostics.EventLog]::SourceExists($EventSource) -and [System.Diagnostics.EventLog]::Exists($EventLog))
}
Write-Log -EventLog $EventLog -EventSource $EventSource -EntryType Information -EventId 1 -Message "Executing '$Script:FullName' to remove legacy kiosk settings."

#endregion Initialization and Logging

#region Main Script

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 2 -EntryType Information -Message "===== Starting Legacy Kiosk Settings Removal ====="

# Step 1: Capture autologon username for later use
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 3 -EntryType Information -Message "Step 1: Identifying autologon user configuration."
$AutologonRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$AutologonUserName = $null

If (Test-Path -Path $AutologonRegPath) {
    $AutologonUserName = (Get-ItemProperty -Path $AutologonRegPath -Name 'DefaultUserName' -ErrorAction SilentlyContinue).DefaultUserName
    If ($AutologonUserName) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 4 -EntryType Information -Message "Found autologon configured for user: $AutologonUserName"
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 5 -EntryType Information -Message "No autologon user configured."
    }
}

#region Phase 1 - Machine-Level Settings Cleanup
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 10 -EntryType Information -Message "===== Phase 1: Cleaning machine-level settings ====="

# Remove User/Group-Specific Local GPOs
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 11 -EntryType Information -Message "Checking for user/group-specific Local GPOs."
$DirGroupPolicyUsers = "$env:SystemRoot\System32\GroupPolicyUsers"
$GPOsRemoved = $false

If (Test-Path -Path $DirGroupPolicyUsers) {
    $UserGroupGPOs = Get-ChildItem -Path $DirGroupPolicyUsers -Directory -ErrorAction SilentlyContinue
    
    If ($UserGroupGPOs) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 12 -EntryType Information -Message "Found $($UserGroupGPOs.Count) user/group-specific local group policy object(s). Removing them."
        
        ForEach ($GPO in $UserGroupGPOs) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 13 -EntryType Information -Message "Removing Local GPO: $($GPO.Name)"
            Remove-Item -Path $GPO.FullName -Recurse -Force -ErrorAction SilentlyContinue
            
            If (!(Test-Path -Path $GPO.FullName)) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 14 -EntryType Information -Message "Local GPO '$($GPO.Name)' removed successfully."
                $GPOsRemoved = $true
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 15 -EntryType Error -Message "Local GPO '$($GPO.Name)' folder was not removed successfully."
            }
        }
        
        If ($GPOsRemoved) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 16 -EntryType Information -Message "Forcing Group Policy update."
            Start-Process -FilePath "gpupdate.exe" -ArgumentList "/Force" -Wait -ErrorAction SilentlyContinue
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 17 -EntryType Information -Message "No user/group-specific Local GPOs found."
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 17 -EntryType Information -Message "GroupPolicyUsers folder does not exist."
}

# Note: Logon/Logoff scripts are managed within the Non-Administrators GPO
# The GPO removal above handles all script cleanup automatically

# Remove Autologon Configuration from registry
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 20 -EntryType Information -Message "Removing autologon configuration from registry."
$AutologonRemoved = $false

If (Test-Path -Path $AutologonRegPath) {
    $AutologonProperties = @(
        'AutoAdminLogon',
        'DefaultUserName',
        'DefaultPassword',
        'DefaultDomainName',
        'ForceAutoLogon'
    )
    
    ForEach ($Property in $AutologonProperties) {
        If (Get-ItemProperty -Path $AutologonRegPath -Name $Property -ErrorAction SilentlyContinue) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 21 -EntryType Information -Message "Removing autologon property: $Property"
            Remove-ItemProperty -Path $AutologonRegPath -Name $Property -Force -ErrorAction SilentlyContinue
            $AutologonRemoved = $true
        }
    }
    
    If ($AutologonRemoved) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 22 -EntryType Information -Message "Autologon configuration removed successfully."
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 23 -EntryType Information -Message "No autologon configuration found."
    }
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 25 -EntryType Information -Message "Phase 1 completed: Machine-level settings cleaned."

#endregion Phase 1 - Machine-Level Settings Cleanup

#region Phase 2 - Logoff Autologon User
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 50 -EntryType Information -Message "===== Phase 2: Logging off autologon user if logged in ====="

If ($AutologonUserName) {
    # Check if the user is currently logged in
    $UserSession = quser 2>$null | Select-Object -Skip 1 | ForEach-Object {
        $_.Trim() -split '\s{2,}'
    } | Where-Object { $_ -match $AutologonUserName }
    
    If ($UserSession) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 51 -EntryType Information -Message "User '$AutologonUserName' is currently logged in. Logging off user."
        
        # Get session ID
        $SessionInfo = quser $AutologonUserName 2>$null | Select-Object -Skip 1
        If ($SessionInfo) {
            $SessionId = ($SessionInfo -split '\s+')[2]
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 52 -EntryType Information -Message "Logging off session ID: $SessionId"
            
            $LogoffResult = Start-Process -FilePath "logoff.exe" -ArgumentList $SessionId -Wait -PassThru -NoNewWindow
            
            If ($LogoffResult.ExitCode -eq 0) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 53 -EntryType Information -Message "User '$AutologonUserName' logged off successfully."
                # Wait for logoff to complete
                Start-Sleep -Seconds 5
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 54 -EntryType Warning -Message "Logoff command returned exit code: $($LogoffResult.ExitCode)"
            }
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 55 -EntryType Information -Message "User '$AutologonUserName' is not currently logged in."
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 56 -EntryType Information -Message "No autologon user to log off."
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 57 -EntryType Information -Message "Phase 2 completed: User logoff check completed."

#endregion Phase 2 - Logoff Autologon User

#region Phase 3 - Delete Autologon User Profile
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 60 -EntryType Information -Message "===== Phase 3: Deleting autologon user profile ====="

If ($AutologonUserName) {
    # Find the user profile
    $UserProfile = Get-CimInstance -Class Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { 
        $_.LocalPath.split('\')[-1] -eq $AutologonUserName 
    }
    
    If ($UserProfile) {
        $UserProfilePath = $UserProfile.LocalPath
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 61 -EntryType Information -Message "Found user profile at: $UserProfilePath"
        
        Try {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 62 -EntryType Information -Message "Deleting user profile for: $AutologonUserName"
            $UserProfile | Remove-CimInstance -ErrorAction Stop
            
            # Verify deletion
            Start-Sleep -Seconds 3
            If (!(Test-Path -Path $UserProfilePath)) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 63 -EntryType Information -Message "User profile deleted successfully."
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 64 -EntryType Warning -Message "User profile folder still exists at: $UserProfilePath"
                # Try to force remove the folder
                Remove-Item -Path $UserProfilePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Catch {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 65 -EntryType Error -Message "Failed to delete user profile: $_"
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 66 -EntryType Information -Message "No user profile found for: $AutologonUserName"
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 67 -EntryType Information -Message "No autologon user profile to delete."
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 68 -EntryType Information -Message "Phase 3 completed: User profile deletion attempted."

#endregion Phase 3 - Delete Autologon User Profile

#region Phase 4 - Clean Default User Profile
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 70 -EntryType Information -Message "===== Phase 4: Cleaning default user profile template ====="

$DefaultUserProfilePath = "$env:SystemDrive\Users\Default"
$DefaultUserNTUserDat = Join-Path -Path $DefaultUserProfilePath -ChildPath 'NTUSER.DAT'
$DefaultUserSettingsRemoved = $false

If (Test-Path -Path $DefaultUserNTUserDat) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 71 -EntryType Information -Message "Loading default user registry hive from: $DefaultUserNTUserDat"
    
    # Ensure no processes have the file open
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 2
    
    $HiveLoadResult = Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\DefaultUserHive", $DefaultUserNTUserDat -Wait -PassThru -NoNewWindow
    
    If ($HiveLoadResult.ExitCode -eq 0) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 72 -EntryType Information -Message "Default user hive loaded successfully."
        
        # Check for Shell replacement (e.g., kiosk.bat instead of explorer.exe)
        $DefaultUserShellRegPath = 'HKLM:\DefaultUserHive\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
        If (Test-Path -Path $DefaultUserShellRegPath) {
            $ShellValue = (Get-ItemProperty -Path $DefaultUserShellRegPath -Name 'Shell' -ErrorAction SilentlyContinue).Shell
            If ($ShellValue -and $ShellValue -notlike '*explorer.exe*') {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 73 -EntryType Information -Message "Found custom shell in default user registry: $ShellValue. Removing it."
                Remove-ItemProperty -Path $DefaultUserShellRegPath -Name 'Shell' -Force -ErrorAction SilentlyContinue
                $DefaultUserSettingsRemoved = $true
            }
            ElseIf ($ShellValue) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 74 -EntryType Information -Message "Default user shell is explorer.exe (normal). No change needed."
            }
        }
        
        # Note: Logon/Logoff scripts are managed within the Non-Administrators GPO
        # The GPO removal in Phase 1 handles all script cleanup automatically
       
     
        # Unload the default user hive
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 76 -EntryType Information -Message "Unloading default user registry hive."
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 5
        $HiveUnloadResult = Start-Process -FilePath "REG.exe" -ArgumentList "UNLOAD", "HKLM\DefaultUserHive" -Wait -PassThru -NoNewWindow
        
        If ($HiveUnloadResult.ExitCode -ne 0) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 77 -EntryType Warning -Message "Default user hive unload returned exit code: $($HiveUnloadResult.ExitCode)"
        }
        Else {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 78 -EntryType Information -Message "Default user hive unloaded successfully."
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 79 -EntryType Warning -Message "Failed to load default user registry hive. Exit code: $($HiveLoadResult.ExitCode)"
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 80 -EntryType Warning -Message "Default user NTUSER.DAT not found at: $DefaultUserNTUserDat"
}

If ($DefaultUserSettingsRemoved) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 81 -EntryType Information -Message "Default user profile cleanup completed. Legacy settings removed."
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 82 -EntryType Information -Message "No legacy kiosk settings found in default user profile."
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 83 -EntryType Information -Message "Phase 4 completed: Default user profile cleaned."

#endregion Phase 4 - Clean Default User Profile

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 99 -EntryType Information -Message "===== Legacy kiosk settings removal completed successfully ====="

#endregion Main Script
