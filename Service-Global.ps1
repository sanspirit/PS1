<#
.SYNOPSIS
    Get the statuses, names and assembly versions or services that include a defined name.
.DESCRIPTION
    Powershell script that will get the statuses, names and assembly versions. You can define the service envioment using -serviceenv. 
.EXAMPLE
    .\src\Service-Global.ps1 -serviceenv qa
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $serviceenv

)

$ErrorActionPreference = "SilentlyContinue"

$svclist = Get-Service $serviceenv*
foreach ($svc in $svclist) {
    $svcname = $svc.name
    $path = (Get-CimInstance win32_service -Filter "name = '$svcname'").PathName.split('"')[1]
    if ($null -ne $path) {
        $assemblyversion = [Reflection.AssemblyName]::GetAssemblyName($path).Version 
    }
    else {
            Write-Host "Skipping $svc"
            $assemblyversion = $null
    }
        $arr = New-Object psobject -Property @{
            Name=$svcname
            Status=($svc.Status)
            AssemblyVersion=$assemblyversion
    }
    $arr
}

