<#
.SYNOPSIS
    Stop a process from running.
.DESCRIPTION
    Powershell script that will stop/kill a process. 
.EXAMPLE
    .\src\Service-StopProcess.ps1 -processname 
    
#>

Param(
    
    [Parameter(Mandatory)]
    [string]
    $processname
)

Write-Host "Finding" $Processname

$process = Get-Process -Name $processname -ErrorAction SilentlyContinue

if ($null -ne $process) {
   
    try {
        Stop-process -Name $processname -Force 
    }
    catch {
        Write-Error "There as an issue stopping the $processname."
        Write-Error $Error
    }
    
}
else {
    Write-Output "The $processname process could not be found"
}


