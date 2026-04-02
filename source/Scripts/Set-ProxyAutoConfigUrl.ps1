[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $PacUrl
)

$WinInetPath = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'

$DefaultUserProfilePath = "$env:SystemDrive\Users\Default"
$DefaultUserNTUserDat = Join-Path -Path $DefaultUserProfilePath -ChildPath 'NTUSER.DAT'
$DefaultUserSettingsRemoved = $false

If (Test-Path -Path $DefaultUserNTUserDat) {
    Write-Output "Loading default user registry hive from: $DefaultUserNTUserDat"
    
    # Ensure no processes have the file open
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 2
    
    $HiveLoadResult = Start-Process -FilePath "REG.exe" -ArgumentList "LOAD", "HKLM\DefaultUserHive", $DefaultUserNTUserDat -Wait -PassThru -NoNewWindow
    
    If ($HiveLoadResult.ExitCode -eq 0) {
        $LegacyRegValues = @(
            "ProxyEnable",
            "ProxyServer",
            "ProxyOverride",
            "AutoConfigURL",
            "AutoDetect"
        )
        $WinInetPath = 'HKLM:\DefaultUserHive\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        Remove-ItemProperty -Path $WinInetPath -Name $LegacyRegValues -ErrorAction SilentlyContinue

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 5
        $HiveUnloadResult = Start-Process -FilePath "REG.exe" -ArgumentList "UNLOAD", "HKLM\DefaultUserHive" -Wait -PassThru -NoNewWindow

        If ($HiveUnloadResult.ExitCode -ne 0) {
            Write-Warning "Failed to unload default user registry hive. You may need to manually unload it using: reg unload HKLM\DefaultUserHive"
        }
        else {
            Write-Output "Default user registry hive unloaded successfully."
        }
    }
}

$proxyConfig = [PSCustomObject]@{
    Proxy         = ""
    ProxyBypass   = ""
    AutoconfigUrl = $PacUrl
    AutoDetect    = $false
}

$JsonFile = Join-Path -Path $env:Temp -ChildPath "proxyConfig.json"
$jsonConfig = $proxyConfig | ConvertTo-Json -Compress
$JsonConfig | Out-File -FilePath $jsonFile -Encoding ascii -NoNewLine

$result = netsh winhttp set advproxy setting-scope=machine settings-file="$jsonFile" 2>&1

If ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set proxy auto config URL. Error: $result"
}
else {
    Write-Output "Proxy auto config URL set successfully."
}

Remove-Item -Path $JsonFile -ErrorAction SilentlyContinue