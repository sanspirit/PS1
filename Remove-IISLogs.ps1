<#
.SYNOPSIS
    Removes old IIS logs
.DESCRIPTION
    Powershell script that will remove IIS Logs older than 2 weeks automatically, if they exist
.EXAMPLE
    .\src\Remove-IISLogs.ps1
#>

[CmdletBinding()]
param()

Import-Module WebAdministration

foreach ($WebSite in $(get-website))
{
    $logFile = "$($Website.logFile.directory)\w3svc$($website.id)".replace('%SystemDrive%', $env:SystemDrive)
    if (Get-ChildItem $logFile -Recurse | Where-Object Creationtime -LT (Get-Date).AddDays(-14))
    {
        $FilesToRemove = (Get-ChildItem $logfile -Recurse -File | Where-Object CreationTime -LT (Get-Date).AddDays(-14))
        $NumberOfFiles = ($FilesToRemove | Measure-Object).Count
        $FileName = ($FilesToRemove).Name
        Write-Host "Found $NumberOffiles files older than 2 weeks"
        Write-Host "Removing files for $($WebSite.name) at [$logfile]"
        foreach ($name in $filename)
        {
            Write-Verbose "Removing file $name"
        }
        $FilesToRemove | Remove-Item -Force
    }
    else
    {
        Write-Warning "No files older than 2 weeks found for $($WebSite.name) in $($logfile), no files removed"
    }
} 
