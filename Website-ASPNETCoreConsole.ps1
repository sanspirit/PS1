<#
.SYNOPSIS
    Runs EXE file for a desired sitename path.
.DESCRIPTION
    Powershell script that will runs a EXE file by using the IIS site name to define the path. 
.EXAMPLE
    .\src\Website-ASPNETCoreConsole.ps1 -sitename <sitename>
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)

Import-Module WebAdministration
Write-Output $sitename

$path = IIS:\Sites\$sitename

if (Test-Path $path) {
    try {
        $websitepath = Get-WebFilePath $path
        $finalPath = "$websitepath\*.exe"
        write-host $finalPath
        if (Test-Path $finalPath) {
            cd $websitepath
            .\*.exe
        }
        else {
            write-host "Path not found"
        }
    }
}
    catch {
        Write-Error $Error
}
else {
	write-host "Site not found"
}
