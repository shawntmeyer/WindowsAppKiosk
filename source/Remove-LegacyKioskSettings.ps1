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
)

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

# Removing All User/Group-Specific Local GPOs
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 7 -EntryType Information -Message "Checking for user/group-specific Local GPOs."
$DirGroupPolicyUsers = "$env:SystemRoot\System32\GroupPolicyUsers"
$GPOsRemoved = $false

If (Test-Path -Path $DirGroupPolicyUsers) {
    $UserGroupGPOs = Get-ChildItem -Path $DirGroupPolicyUsers -Directory -ErrorAction SilentlyContinue
    
    If ($UserGroupGPOs) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 7 -EntryType Information -Message "Found $($UserGroupGPOs.Count) user/group-specific local group policy object(s). Removing them."
        
        ForEach ($GPO in $UserGroupGPOs) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 11 -EntryType Information -Message "Removing Local GPO: $($GPO.Name)"
            Remove-Item -Path $GPO.FullName -Recurse -Force -ErrorAction SilentlyContinue
            
            If (!(Test-Path -Path $GPO.FullName)) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 8 -EntryType Information -Message "Local GPO '$($GPO.Name)' removed successfully."
                $GPOsRemoved = $true
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 9 -EntryType Error -Message "Local GPO '$($GPO.Name)' folder was not removed successfully."
            }
        }
        
        If ($GPOsRemoved) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 12 -EntryType Information -Message "Forcing Group Policy update."
            Start-Process -FilePath "gpupdate.exe" -ArgumentList "/Force" -Wait -ErrorAction SilentlyContinue
        }
    }
    Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 10 -EntryType Information -Message "No user/group-specific Local GPOs found."
    }
}
Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 10 -EntryType Information -Message "GroupPolicyUsers folder does not exist."
}

# Check for Autologon Configuration and capture username
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 37 -EntryType Information -Message "Checking for autologon configuration."
$AutologonRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$AutologonUserName = $null

If (Test-Path -Path $AutologonRegPath) {
    # Capture the autologon username before removing it
    $AutologonUserName = (Get-ItemProperty -Path $AutologonRegPath -Name 'DefaultUserName' -ErrorAction SilentlyContinue).DefaultUserName
    If ($AutologonUserName) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 41 -EntryType Information -Message "Found autologon configured for user: $AutologonUserName"
    }
}

# Remove Logoff Scripts
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 30 -EntryType Information -Message "Checking for logoff scripts."
$LogoffScriptRemoved = $false

# Check for per-user logoff scripts if autologon user was found
If ($AutologonUserName) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 42 -EntryType Information -Message "Checking for per-user logoff scripts for: $AutologonUserName"
    
    # Check if the user profile exists
    $UserProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq $AutologonUserName }
    
    If ($UserProfile) {
        $UserProfilePath = $UserProfile.LocalPath
        $UserNTUserDat = Join-Path -Path $UserProfilePath -ChildPath 'NTUSER.DAT'
        
        # Check for logoff.vbs in user profile directories
        $UserScriptPaths = @(
            "$UserProfilePath\AppData\Local\GroupPolicy\User\Scripts\Logoff",
            "$UserProfilePath\Scripts"
        )
        
        ForEach ($ScriptPath in $UserScriptPaths) {
            $LogoffVbsPath = Join-Path -Path $ScriptPath -ChildPath 'logoff.vbs'
            If (Test-Path -Path $LogoffVbsPath) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 43 -EntryType Information -Message "Found user logoff.vbs at '$LogoffVbsPath'. Removing it."
                Remove-Item -Path $LogoffVbsPath -Force -ErrorAction SilentlyContinue
                $LogoffScriptRemoved = $true
            }
        }
        
        # Check user's registry hive for logoff scripts (only if user is not currently logged in)
        $UserLoggedIn = quser 2>$null | Where-Object { $_ -match $AutologonUserName }
        
        If (-not $UserLoggedIn -and (Test-Path -Path $UserNTUserDat)) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 44 -EntryType Information -Message "Loading registry hive for user: $AutologonUserName"
            
            $HiveLoadResult = Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\TempUserHive", $UserNTUserDat -Wait -PassThru -NoNewWindow
            
            If ($HiveLoadResult.ExitCode -eq 0) {
                $UserLogoffScriptsRegPath = 'HKLM:\TempUserHive\Software\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logoff'
                
                If (Test-Path -Path $UserLogoffScriptsRegPath) {
                    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 45 -EntryType Information -Message "Found per-user logoff scripts registry configuration. Removing it."
                    Remove-Item -Path $UserLogoffScriptsRegPath -Recurse -Force -ErrorAction SilentlyContinue
                    $LogoffScriptRemoved = $true
                }
                
                # Unload the hive
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 46 -EntryType Information -Message "Unloading user registry hive."
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                Start-Sleep -Seconds 3
                $HiveUnloadResult = Start-Process -FilePath "REG.exe" -ArgumentList "UNLOAD", "HKLM\TempUserHive" -Wait -PassThru -NoNewWindow
                
                If ($HiveUnloadResult.ExitCode -ne 0) {
                    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 47 -EntryType Warning -Message "User hive unloaded with exit code '$($HiveUnloadResult.ExitCode)'."
                }
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 48 -EntryType Warning -Message "Failed to load user registry hive. Exit code: $($HiveLoadResult.ExitCode)"
            }
        }
    }
}

# Check for scheduled tasks that run logoff.vbs
$LogoffTasks = Get-ScheduledTask | Where-Object { 
    $_.Actions.Execute -like '*logoff.vbs*' -or 
    $_.Actions.Arguments -like '*logoff.vbs*' 
}
If ($LogoffTasks) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 31 -EntryType Information -Message "Found $($LogoffTasks.Count) scheduled task(s) referencing logoff.vbs. Removing them."
    $LogoffTasks | ForEach-Object {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 32 -EntryType Information -Message "Removing scheduled task: $($_.TaskName)"
        Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
    }
    $LogoffScriptRemoved = $true
}

# Check for logoff scripts in machine-level Group Policy Scripts registry
$LogoffScriptsRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logoff'
If (Test-Path -Path $LogoffScriptsRegPath) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 33 -EntryType Information -Message "Found machine-level logoff scripts registry configuration. Removing it."
    Remove-Item -Path $LogoffScriptsRegPath -Recurse -Force -ErrorAction SilentlyContinue
    $LogoffScriptRemoved = $true
}

# Check for logoff.vbs file in common machine-level script locations
$CommonScriptPaths = @(
    "$env:SystemRoot\System32\GroupPolicy\User\Scripts\Logoff",
    "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\Logoff",
    "$DirKiosk\Scripts"
)
ForEach ($ScriptPath in $CommonScriptPaths) {
    $LogoffVbsPath = Join-Path -Path $ScriptPath -ChildPath 'logoff.vbs'
    If (Test-Path -Path $LogoffVbsPath) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 34 -EntryType Information -Message "Found logoff.vbs at '$LogoffVbsPath'. Removing it."
        Remove-Item -Path $LogoffVbsPath -Force -ErrorAction SilentlyContinue
        $LogoffScriptRemoved = $true
    }
}

If ($LogoffScriptRemoved) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 35 -EntryType Information -Message "Logoff script cleanup completed."
} Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 36 -EntryType Information -Message "No logoff scripts found."
}

# Remove Logon Scripts
Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 50 -EntryType Information -Message "Checking for logon scripts."
$LogonScriptRemoved = $false

# Check for per-user logon scripts if autologon user was found
If ($AutologonUserName) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 51 -EntryType Information -Message "Checking for per-user logon scripts for: $AutologonUserName"
    
    # Check if the user profile exists
    $UserProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq $AutologonUserName }
    
    If ($UserProfile) {
        $UserProfilePath = $UserProfile.LocalPath
        $UserNTUserDat = Join-Path -Path $UserProfilePath -ChildPath 'NTUSER.DAT'
        
        # Check for logon scripts in user profile directories
        $UserLogonScriptPaths = @(
            "$UserProfilePath\AppData\Local\GroupPolicy\User\Scripts\Logon",
            "$UserProfilePath\Scripts"
        )
        
        ForEach ($ScriptPath in $UserLogonScriptPaths) {
            If (Test-Path -Path $ScriptPath) {
                $LogonScripts = Get-ChildItem -Path $ScriptPath -Filter '*.vbs' -ErrorAction SilentlyContinue
                If ($LogonScripts) {
                    ForEach ($Script in $LogonScripts) {
                        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 52 -EntryType Information -Message "Found user logon script at '$($Script.FullName)'. Removing it."
                        Remove-Item -Path $Script.FullName -Force -ErrorAction SilentlyContinue
                        $LogonScriptRemoved = $true
                    }
                }
            }
        }
        
        # Check user's registry hive for logon scripts (only if user is not currently logged in)
        $UserLoggedIn = quser 2>$null | Where-Object { $_ -match $AutologonUserName }
        
        If (-not $UserLoggedIn -and (Test-Path -Path $UserNTUserDat)) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 53 -EntryType Information -Message "Loading registry hive for user: $AutologonUserName"
            
            $HiveLoadResult = Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\TempUserHive2", $UserNTUserDat -Wait -PassThru -NoNewWindow
            
            If ($HiveLoadResult.ExitCode -eq 0) {
                $UserLogonScriptsRegPath = 'HKLM:\TempUserHive2\Software\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logon'
                
                If (Test-Path -Path $UserLogonScriptsRegPath) {
                    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 54 -EntryType Information -Message "Found per-user logon scripts registry configuration. Removing it."
                    Remove-Item -Path $UserLogonScriptsRegPath -Recurse -Force -ErrorAction SilentlyContinue
                    $LogonScriptRemoved = $true
                }
                
                # Unload the hive
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 55 -EntryType Information -Message "Unloading user registry hive."
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                Start-Sleep -Seconds 3
                $HiveUnloadResult = Start-Process -FilePath "REG.exe" -ArgumentList "UNLOAD", "HKLM\TempUserHive2" -Wait -PassThru -NoNewWindow
                
                If ($HiveUnloadResult.ExitCode -ne 0) {
                    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 56 -EntryType Warning -Message "User hive unloaded with exit code '$($HiveUnloadResult.ExitCode)'."
                }
            }
            Else {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 57 -EntryType Warning -Message "Failed to load user registry hive. Exit code: $($HiveLoadResult.ExitCode)"
            }
        }
    }
}

# Check for scheduled tasks that run logon scripts
$LogonTasks = Get-ScheduledTask | Where-Object { 
    ($_.Actions.Execute -like '*.vbs' -or $_.Actions.Arguments -like '*.vbs') -and
    ($_.Triggers.TriggerType -contains 'Logon' -or $_.TaskName -like '*logon*')
}
If ($LogonTasks) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 58 -EntryType Information -Message "Found $($LogonTasks.Count) scheduled task(s) for logon scripts. Removing them."
    $LogonTasks | ForEach-Object {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 59 -EntryType Information -Message "Removing scheduled task: $($_.TaskName)"
        Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
    }
    $LogonScriptRemoved = $true
}

# Check for logon scripts in machine-level Group Policy Scripts registry
$LogonScriptsRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logon'
If (Test-Path -Path $LogonScriptsRegPath) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 60 -EntryType Information -Message "Found machine-level logon scripts registry configuration. Removing it."
    Remove-Item -Path $LogonScriptsRegPath -Recurse -Force -ErrorAction SilentlyContinue
    $LogonScriptRemoved = $true
}

# Also check for Startup scripts (machine startup)
$StartupScriptsRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup'
If (Test-Path -Path $StartupScriptsRegPath) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 61 -EntryType Information -Message "Found machine-level startup scripts registry configuration. Removing it."
    Remove-Item -Path $StartupScriptsRegPath -Recurse -Force -ErrorAction SilentlyContinue
    $LogonScriptRemoved = $true
}

# Check for logon script files in common machine-level script locations
$CommonLogonScriptPaths = @(
    "$env:SystemRoot\System32\GroupPolicy\User\Scripts\Logon",
    "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\Logon",
    "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\Startup",
    "$DirKiosk\Scripts"
)
ForEach ($ScriptPath in $CommonLogonScriptPaths) {
    If (Test-Path -Path $ScriptPath) {
        $LogonScripts = Get-ChildItem -Path $ScriptPath -Filter '*.vbs' -ErrorAction SilentlyContinue
        If ($LogonScripts) {
            ForEach ($Script in $LogonScripts) {
                Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 62 -EntryType Information -Message "Found logon script at '$($Script.FullName)'. Removing it."
                Remove-Item -Path $Script.FullName -Force -ErrorAction SilentlyContinue
                $LogonScriptRemoved = $true
            }
        }
    }
}

If ($LogonScriptRemoved) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 63 -EntryType Information -Message "Logon script cleanup completed."
} Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 64 -EntryType Information -Message "No logon scripts found."
}

# Remove Autologon Configuration
If (Test-Path -Path $AutologonRegPath) {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 37 -EntryType Information -Message "Removing autologon configuration."
    $AutologonRemoved = $false
    
    $AutologonProperties = @(
        'AutoAdminLogon',
        'DefaultUserName',
        'DefaultPassword',
        'DefaultDomainName',
        'ForceAutoLogon'
    )
    
    ForEach ($Property in $AutologonProperties) {
        If (Get-ItemProperty -Path $AutologonRegPath -Name $Property -ErrorAction SilentlyContinue) {
            Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 38 -EntryType Information -Message "Removing autologon property: $Property"
            Remove-ItemProperty -Path $AutologonRegPath -Name $Property -Force -ErrorAction SilentlyContinue
            $AutologonRemoved = $true
        }
    }
    
    If ($AutologonRemoved) {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 39 -EntryType Information -Message "Autologon configuration removed successfully."
    } Else {
        Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 40 -EntryType Information -Message "No autologon configuration found."
    }
} Else {
    Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 40 -EntryType Information -Message "No autologon configuration found."
}

Write-Log -EventLog $EventLog -EventSource $EventSource -EventId 99 -EntryType Information -Message "Legacy kiosk settings removal completed."

#endregion Main Script
