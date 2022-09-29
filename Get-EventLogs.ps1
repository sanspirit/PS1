<#
.SYNOPSIS
    Gets the event viewer logs of a defined date for a defined log type.
.DESCRIPTION
    Powershell script that uses the input of the logtype to find logs for system, application, security or all of them. It then writes this out and creates a octopus artifact.
.EXAMPLE
    src\Get-EventLogs.ps1 -logtype "all" -startdate "08/20/2020" -enddate "08/26/2020" - This would get all the logs between 20th August 00:00:00 to 26th August 00:00:00
#>

Param(
    
    [Parameter(Mandatory)]
    [string]
    $logtype,

    [Parameter(Mandatory)]
    [string]
    $startdate,

    [Parameter(Mandatory)]
    [string]
    $enddate
)

$enddate = $enddate + ' 23:59:59'
$startdate = $startdate + ' 00:00:00'

if (($logtype -eq "system") -or ($logtype -eq "all") -or ($logtype -eq "application") -or ($logtype -eq "security")) {
    if ($logtype -eq 'all') {
        $logs = @('Application','System','Security')
            foreach ($log in $logs)
            {
                Write-host "Outputting logs for $log"
                $EventCritea = @{logname=$log; StartTime=$startdate; EndTime=$enddate}
                $events = Get-WinEvent -FilterHashTable $EventCritea  -ErrorAction SilentlyContinue
                if ($null -ne $events) {
                    Write-Output $events | Out-File -FilePath "$env:TEMP\$log.txt"
                    New-OctopusArtifact -Path "$env:TEMP\$log.txt" -Name "$([System.Environment]::MachineName)-EventLogs-$log.txt"
                }
                else {
                    Write-Warning "Can't find any events for $log between $startdate and $enddate"
                }
            }
    }
    else {
        Write-host "Outputting logs for $logtype"
        $EventCritea = @{logname=$logtype; StartTime=$startdate; EndTime=$enddate}
        $events = Get-WinEvent -FilterHashTable $EventCritea  -ErrorAction SilentlyContinue 
        if ($null -ne $events) {
            Write-Output $events | Out-File -FilePath "$env:TEMP\$logtype.txt"
            New-OctopusArtifact -Path "$env:TEMP\$logtype.txt" -Name "$([System.Environment]::MachineName)-EventLogs-$logtype.txt"
        }
        else {
            Write-Warning "Can't find any events for $logType between $startdate and $enddate"
        }
    }
}
else {
    Write-Warning "$logtype is not support. Please choose from all, system, application or security"
}
