<#
.SYNOPSIS
    finds the exe for a service, runs the exe and outputs the logs.
.DESCRIPTION
    Powershell script that finds the exe for a service, runs the exe and outputs the logs as a octopus artifact.
.EXAMPLE
    src\Service-RunExeWithLogs.ps1 -servicename 'FT1.CTCore.Support.ApiHost'
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $servicename

)

$service = Get-Service -Name $servicename -ErrorAction SilentlyContinue

if ($null -ne $service) {
    $path = ((Get-cimInstance win32_service -filter "name like '$servicename'").PathName)
    Write-Host $path
    Start-Process $path -NoNewWindow -RedirectStandardOutput "$env:TEMP\$servicename-logs.txt"
    New-OctopusArtifact -Path "$env:TEMP\$servicename-logs.txt" -Name "$([System.Environment]::MachineName)-$servicename-logs.txt"
}
else {
    Write-Warning "Can't find $servicename"
}
