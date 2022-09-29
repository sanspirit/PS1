<#
.SYNOPSIS
    Searches Octopus for Variables
.DESCRIPTION
    Searches Octopus for Variables based on Variable Name or Value, will return individual variables from the whole of Octopus

.EXAMPLE
    .\src\Find-Variables.ps1 -defaultSpaceName "Apps" -apikey XXX -variable "VarValue" -Scope "Value"
    .\src\Find-Variables.ps1 -defaultSpaceName "Apps" -apikey XXX -variable "VarName" -Scope "Name"
#>

[CmdletBinding()]
Param (

    [Parameter()]
    [string]
    $octopusURI = "https://octopus.ctazure.co.uk",

    [Parameter()]
    [string]
    $defaultSpaceName,

    [Parameter()]
    [string]
    $apikey,

    [Parameter()]
    [string]
    $variable,

    [Parameter()]
    [ValidateSet('Name','Value')]
    [string]
    $Scope

)

$header =  @{ "X-Octopus-ApiKey" = $apiKey }

$ErrorActionPreference = 'silentlycontinue'
$defaultSpaceId = (Invoke-WebRequest -Uri "$octopusURI/api/spaces/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12 | Where-Object {$_.Name -eq $defaultSpaceName}).id

#Search project vars
Write-Host "Finding $variable in project variables" -ForegroundColor Magenta
$projectsid = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/projects/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).id
foreach ($project in $projectsid) {
    $project = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/projects/$project" -Method GET -Headers $header | ConvertFrom-Json -Depth 12
    $varid = $project.variablesetid
    $projectvars = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultspaceid/variables/$varid" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).variables
    Write-Verbose "Checking $($project.name)"
    foreach ($projectvar in $projectvars) {
        if ($scope -eq 'Name') {
            if ($variable -eq $projectvar.name) {
                Write-host "Var Name found in $($project.name), name: $($projectvar.name), value: $($projectvar.Value)" -ForegroundColor Green
            }
        }
        elseif ($scope -eq 'Value') {
            if ($projectvar.Value -like "*$variable*") {
                Write-host "Var Value found in $($project.name), name: $($projectvar.name), value: $($projectvar.Value)" -ForegroundColor Green
            }
        }
    }
}


#Search library vars
Write-Host "Finding $variable in library sets" -ForegroundColor Magenta
$libs = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultspaceid/libraryvariablesets/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).variablesetid
foreach ($libset in $libs) {
    $libsetowner = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultspaceid/variables/$libset" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).ownerid
    $libsetname = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultspaceid/libraryvariablesets/$libsetowner" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).name
    $vars = (Invoke-WebRequest -Uri "$octopusURI/api/$defaultspaceid/variables/$libset" -Method GET -Headers $header | ConvertFrom-Json -Depth 12).variables
    Write-Verbose "Checking $libsetname"
    foreach ($var in $vars) {
        if ($scope -eq 'Name') {
            if ($variable -eq $var.name) {
                Write-host "Var Name found in $libsetname, name: $($var.name), value: $($var.Value)" -ForegroundColor Green
            }
        }
        elseif ($scope -eq 'Value') {
            if ($var.Value -like "*$variable*") {
                Write-host "Var Value found in in $libsetname, name: $($var.name), value: $($var.Value)" -ForegroundColor Green
            }
        }
    }
}
