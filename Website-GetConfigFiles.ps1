<#
.SYNOPSIS
    Get website config files.
.DESCRIPTION
    Powershell script that will get website config files.  
.EXAMPLE
    .\src\Website-GetConfigFiles.ps1
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)

Import-Module WebAdministration
Import-Module IISAdministration
Write-Output $sitename

if (Test-Path IIS:\Sites\$sitename) {
    $websitepath = Get-WebFilePath IIS:\Sites\$sitename
}
elseif ($sitename -in (Get-ChildItem -Path 'IIS:\Sites\Default Web Site' | Where-Object {$_.NodeType -eq 'application'}).Name){
    write-host "found in default sites"
    $websitepath = (Get-WebApplication $sitename).physicalpath
}

if ($websitepath) {
    $itemsWebConfig = Get-ChildItem -Path $websitepath -Filter "web.config"
    foreach ($itemWebConfig in $itemsWebConfig) {
        $itemWebConfig | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-web.config.txt"
    }
    
    $itemsAppConfig = Get-ChildItem -Path $websitepath -Filter "app.config"
    foreach ($itemAppConfig in $itemsAppConfig) {
		$itemAppConfig | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-app.config.txt"
    }
    
    $itemsAppSettings = Get-ChildItem -Path $websitepath -Filter "appsettings.json"
    foreach ($itemAppSettings in $itemsAppSettings) {
		$itemAppSettings | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-appsettings.json.txt"
    }
}
else {
	write-host "Site not found"
}
