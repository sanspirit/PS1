<#
.SYNOPSIS
    Schedule Runbook run
.DESCRIPTION
    Powershell script that will schedule a Runbook to run in a specified time
.EXAMPLE
    .\src\Schedule-Runbook.ps1 -octopusAPIKey xxx -defaultSpaceName "Apps" -projectName "Environment Runbooks" -runbookName "Enable VM-Start-Stop Schedule" -environmentName "ft1" -tenantName "per" -scheduleDelay 3
#>

[CmdletBinding()]
Param(

    [Parameter()]
    [string]
    $octopusURI = "https://octopus.ctazure.co.uk",

    [Parameter()]
    [string]
    $octopusAPIKey,

    [Parameter(Mandatory = $True)]
    [string]
    $defaultSpaceName,

    [Parameter(Mandatory = $True)]
    [string]
    $projectName,

    [Parameter(Mandatory = $True)]
    [string]
    $runbookName,
    
    [Parameter()]
    [string]
    $environmentName,

    [Parameter()]
    [string]
    $tenantName,

    [Parameter(Mandatory = $True)]
    [ValidateRange(0,3)]
    [Int]
    $scheduleDelay,

    [Parameter()]
    [bool]
    $waitforRunbookFinish,

    [Parameter()]
    [int]
    $waittime
)

$ErrorActionPreference = "Stop";

# Header

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURI/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $defaultSpaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURI/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get runbook
$runbook = (Invoke-RestMethod -Method Get -Uri "$octopusURI/api/$($space.Id)/runbooks/all" -Headers $header) | Where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $project.Id}

# Get environment
$environment = (Invoke-RestMethod -Uri "$octopusURI/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$_.name -eq $environmentName}

# Get tenant
$tenant = (Invoke-RestMethod -Uri "$octopusURI/api/$($space.Id)/tenants/all" -Headers $header) | Where-Object {$_.Name -eq $tenantname}


#Get date
$Today = get-date
$DelayTime = $Today.AddDays($scheduleDelay)

# Run runbook per selected environment
foreach ($environmentId in $environment)
{
    # Create json payload
    if ($scheduleDelay -ne 0) {
        $jsonPayload = @{
            RunbookId = $runbook.Id
            RunbookSnapshotId = $runbook.PublishedRunbookSnapshotId
            EnvironmentId = $environment.Id
            QueueTime = $DelayTime
            QueueTimeExpiry = $DelayTime.AddMinutes(30)
            TenantID = $tenant.Id
        }
    }
    else {
        $jsonPayload = @{
            RunbookId = $runbook.Id
            RunbookSnapshotId = $runbook.PublishedRunbookSnapshotId
            EnvironmentId = $environment.Id
            TenantID = $tenant.Id
        }
    }

    # Run runbook
    try { 
        $runbookrun = Invoke-RestMethod -Method Post -Uri "$octopusURI/api/$($space.Id)/runbookRuns" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
        Write-Host "Running $($runbookrun.Name) - [$($runbookrun.TaskId)]($($octopusURI + $runbookrun.Links.Web))"
    }
    catch {
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        Write-Warning "Runbook deploy failed, ErrorMessage: $($($_.ErrorDetails.Message | ConvertFrom-Json).ErrorMessage)"
    }

    if ($true -eq $waitforRunbookFinish) {
        $interval = $waittime / 10
        $i = 0
        do {
            Write-Host "Waiting for runbook $($runbookrun.Name) to complete.."
            $i = $i + $interval
            Write-Verbose "time taken: $i`s"
            Start-Sleep $interval
        } until ((Invoke-WebRequest "$OctopusURI/api/$defaultSpaceId/tasks/$($runbookrun.TaskId)" -Headers $header | ConvertFrom-Json).state -ne "Executing" -or $i -ge $waittime)
        
        $result = (Invoke-WebRequest "$OctopusURI/api/$defaultSpaceId/tasks/$($runbookrun.TaskId)" -Headers $header | ConvertFrom-Json).state
        if ($result -ne "Success") {
            Write-Warning "Runbook run was not successful, state: $result"
        }
        else {
            Write-Host "Runbook Run Successful"
        }
    }
}
