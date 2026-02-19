function Get-AssignedAccessCspBridgeWmi {
    $NameSpace = "root\cimv2\mdm\dmmap"
    $Class = "MDM_AssignedAccess"
    return Get-CimInstance -Namespace $NameSpace -ClassName $Class
}

function Set-AssignedAccessShellLauncher {
    param (
        [Parameter(Mandatory = $True)]
        [String] $FilePath
    )

    $Xml = Get-Content -Path $FilePath
    $EscapedXml = [System.Security.SecurityElement]::Escape($Xml)
    $AssignedAccessCsp = Get-AssignedAccessCspBridgeWmi
    $AssignedAccessCsp.ShellLauncher = $EscapedXml
    Set-CimInstance -CimInstance $AssignedAccessCsp
}

function Clear-AssignedAccessShellLauncher {
    $AssignedAccessCsp = Get-AssignedAccessCspBridgeWmi
    $AssignedAccessCsp.ShellLauncher = $NULL
    Set-CimInstance -CimInstance $AssignedAccessCsp
}

function Get-AssignedAccessShellLauncher {
    (Get-AssignedAccessCspBridgeWmi).ShellLauncher
}

function Get-AssignedAccessConfiguration {
    (Get-AssignedAccessCspBridgeWmi).Configuration
}

function Set-AssignedAccessConfiguration {
    param (
        [Parameter(Mandatory = $True)]
        [string] $FilePath
    )

    $Xml = Get-Content -Path $FilePath
    $AssignedAccessCsp = Get-AssignedAccessCspBridgeWmi
    $EncodedXml = [System.Net.WebUtility]::HtmlEncode($Xml)
    $AssignedAccessCsp.Configuration = $EncodedXml
    Set-CimInstance -CimInstance $AssignedAccessCsp
}

function Clear-AssignedAccessConfiguration {
    $AssignedAccessCsp = Get-AssignedAccessCspBridgeWmi
    $AssignedAccessCsp.Configuration = $NULL
    Set-CimInstance -CimInstance $AssignedAccessCsp
}

Function Format-OutputXml {
    param (
        [Parameter(Mandatory = $True)]
        [string] $Configuration
    )
    try {
        $XmlDoc = [xml]$Configuration
        $StringWriter = New-Object System.IO.StringWriter
        $XmlSettings = New-Object System.Xml.XmlWriterSettings
        $XmlSettings.Indent = $true
        $XmlSettings.IndentChars = "  "
        $XmlSettings.NewLineChars = "`r`n"
        $XmlSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
        $XmlSettings.OmitXmlDeclaration = $false
        $XmlSettings.ConformanceLevel = [System.Xml.ConformanceLevel]::Document        
        $XmlWriter = [System.Xml.XmlWriter]::Create($StringWriter, $XmlSettings)
        $XmlDoc.Save($XmlWriter)
        $XmlWriter.Flush()
        $StringWriter.ToString()
    }
    catch {
        # Fallback if XML formatting fails
        $Configuration | Out-String
    }
}