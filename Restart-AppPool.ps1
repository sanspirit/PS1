<#
.SYNOPSIS
    Starts a defined app pool if stopped, else it will restart the app pool.
.DESCRIPTION
    Powershell script that will starts the app pool if the state of the app pool is set to stopped. Else it will try and restart the app pool. 
.EXAMPLE
    .\src\Restart-AppPool.ps1 -sitename <site>
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename
)
if ($null -ne (Get-IISAppPool -Name $sitename)) {
    try {
        if ((Get-WebAppPoolState -Name $sitename).Value -eq 'Stopped') {
            Start-WebAppPool -Name $sitename
            write-host "$sitename was down. Starting the site..."
        }
        else {
            Restart-WebAppPool $sitename
            write-host "$sitename has been restarted."
        }
    }
    catch {
        Write-Error "There was an issue starting / restarting the App Pool"
        Write-Error $Error
    }
}
else {
    Write-Warning "Can't find $sitename"
}
