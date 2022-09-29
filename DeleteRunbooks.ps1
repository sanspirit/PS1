Param (

    [Parameter()]
    [string]
    $octopusURI = "https://octopus.ctazure.co.uk",

    [Parameter()]
    [string]
    $defaultSpaceName = "Apps",

    [Parameter()]
    [string]
    $runbookId,

    [Parameter()]
    [string]
    $DestinationProjectId,

    [Parameter()]
    [string]
    $apikey,

    $header =  @{ "X-Octopus-ApiKey" = $apiKey }

)

$ErrorActionPreference = "Stop"

$defaultSpaceId = Invoke-WebRequest -Uri "$octopusURI/api/spaces/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12 | Where-Object {$_.Name -eq $defaultSpaceName}
$defaultSpaceId = $defaultSpaceId.Id

$runbook = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/$runbookId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

$runbookName = $runbook.Name

$Projects = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/projects/all" -Headers $header | ConvertFrom-Json -Depth 12
if ([string]::IsNullOrEmpty($DestinationProjectId)) {
    $Projects = $Projects | where-Object {$_.Name -notlike "*Example*" -and $_.Name -notlike "*test*"} 
}
else {
    $Projects = $Projects | where-Object {$_.id -eq $DestinationProjectId} 
}
$allrunbooks = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

if ($null -ne $runbookName) {
    foreach ($project in $Projects) {
        Write-Host "`nSeeing if runbook exists in"($project.Name)""
        $projectid = $project.Id
        $runbookexist = $allrunbooks | where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $projectid}
        if ($runbookName -eq $runbookexist.name) {
            $runbooktodelete = $runbookexist.Id
            try {
                Write-Host "Runbook found in"($project.Name)"Will try to delete it."
                Invoke-RestMethod -Method Delete -Uri "$octopusURI/api/$defaultSpaceId/Runbooks/$runbooktodelete" -Headers $header
                Write-Host "Runbook Deleted Sucessfully" -ForegroundColor Green
            }
            catch {
                Write-Warning $Error
            }
        }
        else {
            Write-Host "Runbook not found in"($project.Name)""
            continue
            }
        }
    }
else {
    Write-Warning "Runbook name not found for all runbooks."
}
