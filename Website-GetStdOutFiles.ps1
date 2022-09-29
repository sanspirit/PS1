<#
.SYNOPSIS
    Outputs all stdout and fataerrorsfiles as a Octopus artifact.
.DESCRIPTION
    Powershell script that outputs stdout and fataerrors as a octopus artifact.   
.EXAMPLE
    .\src\Website-GetStdOutFiles.ps1
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)

Import-Module WebAdministration
Write-Output $sitename

if (Test-Path IIS:\Sites\$sitename) {
    $websitepath = Get-WebFilePath IIS:\Sites\$sitename
    write-host $websitepath
    $logFiles = Get-ChildItem -Path $websitepath -Recurse -Filter "stdout*"
    if ($null -ne $logFiles) {
        foreach ($item in $logFiles) {
            $item | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-stdout.txt"
        }
    }
    else {
        Write-Warning "There are no stdout files found"
    }
    $fatallogs = Get-ChildItem -Path $websitepath -Recurse -Filter "fatalerrors.txt"
    if ($null -ne $fatallogs) {
        foreach ($fatalitem in $fatallogs) {
            $fatalitem | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-fatalerrors.txt"
        }
    }
    else {
        Write-Warning "There are no fatalerrors file found"
    }
}
else {
	write-host "Site not found"
}
