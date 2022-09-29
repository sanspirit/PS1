<#
.SYNOPSIS
    Writes properties of app pools out as JSON.
.DESCRIPTION
    Powershell script that writes the properties of a defined app pool in JSON. 
.EXAMPLE
    .\src\Get-AppPool.ps1 -sitename <site>
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)
try {
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration")
    $iis = (New-Object Microsoft.Web.Administration.ServerManager)
    $pool = $iis.ApplicationPools | Where-Object {$_.Name -eq "$sitename"} | Select-Object
    write-output ($pool | ConvertTo-Json)
}
catch {
    Write-Error "There as an issue getting the app pools properties."
    Write-Error $Error
}
