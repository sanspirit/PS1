<#
.SYNOPSIS
    Grabs the log file for a defined site using sitename and sets them up as Octopus Artifact.
.DESCRIPTION
    A Powershell script that needs an input of a sitename to get the site. Using the site, the script will find the log file for the site
    and generate it as a Octopus Artifact. 
.EXAMPLE
    \src\Website-IISLogs.ps1 -sitename <site>
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)

Import-Module WebAdministration
Write-Output $sitename

if (Test-Path IIS:\Sites\$sitename) {
    try {
        $Website = Get-Item IIS:\Sites\$sitename
        $id = $Website.id
        $logFile="C:\inetpub\logs\LogFiles\w3svc$($website.id)"
        Write-Host $logFile
        Get-ChildItem $logFile | Sort-Object -Descending LastWriteTime | Select-Object | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-iislogs.txt"
    }
    catch {
        Write-Error "There was an issue with the logfile. Logfile is set to $logFile. Website ID is set to $id"
        Write-Error $Error
    }	
}
else {
    Write-Warning "Site not found"
}
