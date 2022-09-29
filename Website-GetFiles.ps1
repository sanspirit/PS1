<#
.SYNOPSIS
    Get files.
.DESCRIPTION
    Powershell script that will get website files.  
.EXAMPLE
    .\src\Website-GetFiles.ps1 -sitename enablereviewsperft1 -files crashlog
#>

Param(

    [Parameter()]
    [string]
    $sitename,

    [Parameter()]
    [array]
    $files
)

Import-Module WebAdministration
Import-Module IISAdministration
Write-host "Checking $sitename"

if (Test-Path IIS:\Sites\$sitename) {
    $websitepath = Get-WebFilePath IIS:\Sites\$sitename
}
elseif ($sitename -in (Get-ChildItem -Path 'IIS:\Sites\Default Web Site' | Where-Object {$_.NodeType -eq 'application'}).Name){
    write-Verbose "found in default sites"
    $websitepath = (Get-WebApplication $sitename).physicalpath
}

if ($websitepath) {
    Write-Verbose "Found $sitename. Path: $websitepath"
    foreach ($file in $files) {
        $foundFiles = Get-ChildItem -Path $websitepath -Filter *$file* -Recurse
        if ($foundfiles) {
            foreach ($foundFile in $foundFiles) {
                Write-host "Found $foundfile"
                $foundFile | New-OctopusArtifact -Name "$([System.Environment]::MachineName)-($foundfile).txt"
            }
        }
        else {
            Write-Verbose "No files found matching $file"
        }
    }
}
else {
	write-host "Site not found"
}
