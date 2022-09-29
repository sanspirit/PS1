<#
.SYNOPSIS
    Get the status, start, restart, stop or delete a service.
.DESCRIPTION
    Powershell script that will get the status, start, restart, stop  or delete a service with error handling. 
.EXAMPLE
    .\src\Service-Functions.ps1 -servicename Themes -state get|start|restart|stop|delete
#>

Param(
    
    [Parameter(Mandatory)]
    [string]
    $servicename,

    [Parameter(Mandatory)]
    [string]
    $state
)

Write-Host "Finding" $servicename

$service = Get-Service -Name $servicename -ErrorAction SilentlyContinue

if ($null -ne $service) {
    if ($state -eq "get") {
        try {
            Write-Host "$servicename is"$service.Status
        }
        catch {
            Write-Output "Exception trying to get the status of $servicename"
            Write-Error $Error[0]
        }
        exit
    }
    if (($service.Status -eq 'Stopped' -and $state -eq "stop") -or ($service.Status -eq 'Stopped' -and $state -eq "restart") -or ($service.Status -eq 'Running' -and $state -eq "start")) {
        Write-Warning "You can't start a running service, stop a stopped service or restart a stopped service."
    }
    else {
        try {
            if ($service.Status -eq 'Running' -and $state -eq "stop") {
                $status = 'Stopped'
                Set-Service -Name $servicename -StartupType Disabled 
                Stop-Service $service -ErrorAction SilentlyContinue
            }
            if ($service.Status -eq 'Stopped' -and $state -eq "start") {
                $status = 'Running' 
                Set-Service -Name $servicename -StartupType Manual
                Start-Service $service -ErrorAction SilentlyContinue
            }
            if ($service.Status -eq 'Running' -and $state -eq "restart") {
                $status = 'Running'
                Restart-Service $service -ErrorAction SilentlyContinue
            }
            if ($service.Status -eq 'Running' -and $state -eq "delete") {
                $status = 'Stopped'
                Set-Service -Name $servicename -StartupType Disabled 
                Stop-Service $service -ErrorAction SilentlyContinue
                $service.WaitForStatus($status, '00:01:00')
            }
            if ($state -eq 'delete') {
                Write-Output "Waiting for $servicename to $state"
                Remove-Service $service -ErrorAction SilentlyContinue
            }
            else {
                Write-Output "Waiting for $servicename to $state"
                $service.WaitForStatus($status, '00:01:00')
                Write-Host "$servicename is now"$service.Status
            }
        }
        catch {
            Write-Output "Exception trying to $state $servicename"
            Write-Error $Error[0]
        }
    }
}
else {
    Write-Output "The $servicename service could not be found"
}


