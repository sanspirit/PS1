<#
.SYNOPSIS
    finds the exe for a site, runs the exe and outputs the logs.
.DESCRIPTION
    Powershell script that finds the exe for a site, runs the exe and outputs the logs as a octopus artifact.
.EXAMPLE
    src\Website-RunASPNETCoreConsoleWithLogs.ps1 -sitename 'EnableAccessApiperft1'
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename

)

Import-Module WebAdministration
Write-Output $sitename

$path = Get-WebFilePath "IIS:\Sites\$sitename"
if (Test-Path $path) {
    try {
        $finalPath = "$path\*.exe"
        write-host $finalPath
        if (Test-Path $finalPath) {
            Write-Host "Starting exe for $sitename"
            Start-Process $finalPath -NoNewWindow -RedirectStandardOutput "$env:TEMP\$sitename-logs.txt"
            New-OctopusArtifact -Path "$env:TEMP\$sitename-logs.txt" -Name "$([System.Environment]::MachineName)-$sitename-logs.txt"
        }
        else {
            write-host "Path not found"
        }
    }
    catch {
        Write-Error $Error
    }
}
else {
	write-host "Site not found"
}
