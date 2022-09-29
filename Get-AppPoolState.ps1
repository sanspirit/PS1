<#
.SYNOPSIS
    Writes name and status of app pools.
.DESCRIPTION
    Powershell script that writes name and status of app pools. This also filters the sites using sitename. 
.EXAMPLE
    .\src\Get-AppPoolState.ps1 -sitename <site>
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename

)

$ErrorActionPreference = "SilentlyContinue"

Import-Module WebAdministration
$sites = Get-IISSite | Where-Object { $_.Name -like "*$sitename*" }

if ($null -ne $sites) {
    foreach ($site in $sites)
    {
        if (Test-Path IIS:\Sites\$site) {
            $arr = New-Object psobject -Property @{
                Name=$site
                AppPoolStatus=(Get-WebAppPoolState -Name $site).Value
            }
            $arr
        }
    }
}
else {
    Write-Warning "Can't find any sites that include $sitename"
}
