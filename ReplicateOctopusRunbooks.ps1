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
function Get-OctopusData
{
    param(
        $octopusUrl,
        $octopusApiKey,
        $spaceName
    )

    $octopusData = @{
        OctopusUrl = $octopusUrl;
        OctopusApiKey = $octopusApiKey
    }

    $octopusData.ApiInformation = Get-OctopusBaseApiInformation -octopusData $octopusData
    $octopusData.Version = $octopusData.ApiInformation.Version

    $splitVersion = $octopusData.ApiInformation.Version -split "\."
    $octopusData.MajorVersion = [int]$splitVersion[0]
    $octopusData.MinorVersion = [int]$splitVersion[1]
    $octopusData.HasSpaces = $octopusData.MajorVersion -ge 2019

    $octopusData.HasRunbooks = ($octopusData.MajorVersion -ge 2019 -and $octopusData.MinorVersion -ge 11) -or $octopusData.MajorVersion -ge 2020

    $octopusData.SpaceId = $defaultSpaceId
    $octopusData.StepTemplates = Get-OctopusStepTemplateList -octopusData $octopusData
    $octopusData.ProjectList = Get-OctopusProjectList -octopusData $octopusData
    $octopusData.FeedList = Get-OctopusFeedList -octopusData $octopusData
    $octopusData.PackageList = Get-OctopusPackageList -octopusData $octopusData

    return $octopusData

}

function Copy-OctopusDeploymentProcess
{
    param(
        $sourceChannelList,
        $destinationChannelList,
        $sourceData,
        $destinationData,
        $sourceDeploymentProcessSteps,
        $destinationDeploymentProcessSteps
    )

    Write-OctopusVerbose "Looping through the source steps to get them added"
    $newDeploymentProcessSteps = @()
    foreach($step in $sourceDeploymentProcessSteps)
    {
        $matchingStep = Get-OctopusItemByName -ItemList $destinationDeploymentProcessSteps -ItemName $step.Name
        
        $newStep = $false
        if ($null -eq $matchingStep)
        {
            Write-OctopusVerbose "The step $($step.Name) was not found, cloning from source and removing id"            
            $stepToAdd = Copy-OctopusObject -ItemToCopy $step -ClearIdValue $true -SpaceId $null            
            $newStep = $true
        }
        else
        {
            Write-OctopusVerbose "Matching step $($step.Name) found, using that existing step"
            $stepToAdd = Copy-OctopusObject -ItemToCopy $matchingStep -ClearIdValue $false -SpaceId $null
        }

        Write-OctopusVerbose "Looping through the source actions to add them to the step"
        $newStepActions = @()
        foreach ($action in $step.Actions)
        {
            $matchingAction = Get-OctopusItemByName -ItemList $stepToAdd.Actions -ItemName $action.Name

            if ($null -eq $matchingAction -or $newStep -eq $true)
            {
                Write-OctopusVerbose "The action $($action.Name) doesn't exist for the step, adding that to the list"
                $clonedStep = Copy-OctopusProcessStepAction -sourceAction $action -sourceChannelList $sourceChannelList -destinationChannelList $destinationChannelList -sourceData $sourceData -destinationData $destinationData         

                if ($null -ne $clonedStep)
                {
                    $newStepActions += $clonedStep
                }
            }            
            else
            {
                Write-OctopusVerbose "The action $($action.Name) already exists for the step, adding existing item to list"
                $newStepActions += Copy-OctopusObject -ItemToCopy $matchingAction -ClearIdValue $false -SpaceId $null
            }
        }

        Write-OctopusVerbose "Looping through the destination step to make sure we didn't miss any actions"
        foreach ($action in $stepToAdd.Actions)
        {
            $matchingAction = Get-OctopusItemByName -ItemList $step.Actions -ItemName $action.Name

            if ($null -eq $matchingAction)
            {
                Write-OctopusVerbose "The action $($action.Name) didn't exist at the source, adding that back to the destination list"
                $newStepActions += Copy-OctopusObject -ItemToCopy $action -ClearIdValue $false -SpaceId $null
            }
        }
        
        $stepToAdd.Actions = @($newStepActions)

        if ($stepToAdd.Actions.Length -gt 0)
        {
            $newDeploymentProcessSteps += $stepToAdd
        }
    }

    Write-OctopusVerbose "Looping through the destination deployment process steps to make sure we didn't miss anything"
    foreach ($step in $destinationDeploymentProcessSteps)
    {
        $matchingStep = Get-OctopusItemByName -ItemList $sourceDeploymentProcessSteps -ItemName $step.Name

        if ($null -eq $matchingStep)
        {
            Write-OctopusVerbose "The step $($step.Name) didn't exist in the source, adding that back to the destiantion list"
            $newDeploymentProcessSteps += Copy-OctopusObject -ItemToCopy $step -ClearIdValue $false -SpaceId $null
        }
    }

    return @($newDeploymentProcessSteps)
}

function Copy-OctopusObject
{
    param(
        $ItemToCopy,        
        $ClearIdValue,
        $SpaceId
    )

    $copyOfItem = $ItemToCopy | ConvertTo-Json -Depth 10
    $copyOfItem = $copyOfItem | ConvertFrom-Json

    if ($ClearIdValue)
    {
        $copyOfItem.Id = $null
    }

    if($null -ne $SpaceId -and (Test-OctopusObjectHasProperty -objectToTest $copyOfItem -propertyName "SpaceId"))
    {
        $copyOfItem.SpaceId = $SpaceId
    }

    return $copyOfItem
}

function Get-OctopusItemByName
{
    param (
        $ItemList,
        $ItemName
        )    

    return ($ItemList | Where-Object {$_.Name -eq $ItemName})
}

function Copy-OctopusProcessStepAction
{
    param(
        $sourceAction,
        $sourceChannelList,
        $destinationChannelList,
        $sourceData,
        $destinationData
    )            

    $action = Copy-OctopusObject -ItemToCopy $sourceAction -ClearIdValue $true -SpaceId $null   
        
    return $action    
}

function Test-OctopusObjectHasProperty
{
    param(
        $objectToTest,
        $propertyName
    )

    $hasProperty = Get-Member -InputObject $objectToTest -Name $propertyName -MemberType Properties

    if ($hasProperty)
    {
        Write-OctopusVerbose "$propertyName property found."
        return $true
    }
    else
    {
        Write-OctopusVerbose "$propertyName property missing."
        return $false
    }    
}
function Get-OctopusBaseApiInformation
{
    param(
        $octopusData
    )

    return Get-OctopusApi -EndPoint "/api" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -SpaceId $null 
}
Function Get-OctopusApi
{
    param (
        $EndPoint,
        $ApiKey,
        $SpaceId,
        $OctopusUrl
    )

    $url = Get-OctopusUrl -EndPoint $EndPoint -SpaceId $SpaceId -OctopusUrl $OctopusUrl

    $results = Invoke-OctopusApi -Method "Get" -Url $url -apiKey $ApiKey

    return $results
}
function Get-OctopusUrl
{
    param (
        $EndPoint,
        $SpaceId,
        $OctopusUrl
    )

    if ($EndPoint -match "/api")
    {
        if (!$EndPoint.StartsWith("/api"))
        {
            $EndPoint = $EndPoint.Substring($EndPoint.IndexOf("/api"))
        }

        return "$OctopusUrl/$EndPoint"
    }

    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        return "$OctopusUrl/api/$EndPoint"
    }

    return "$OctopusUrl/api/$spaceId/$EndPoint"
}
function Invoke-OctopusApi
{
    param
    (
        $url,
        $apiKey,
        $method,
        $item,
        $filePath
    )

    try
    {
        if ($null -ne $filePath)
        {
            Write-OctopusVerbose "Filepath $filePath parameter provided, saving output to the filepath from $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -OutFile $filePath
        }

        if ($null -eq $item)
        {
            Write-OctopusVerbose "No data to post or put, calling bog standard invoke-restmethod for $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8'
        }

        $body = $item | ConvertTo-Json -Depth 10
        Write-OctopusVerbose $body

        Write-OctopusVerbose "Invoking $method $url"
        return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8'
    }
    catch
    {
        if ($null -ne $_.Exception.Response)
        {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-OctopusVerbose -Message "Error calling $url $($_.Exception.Message) StatusCode: $($_.Exception.Response.StatusCode.value__ ) StatusDescription: $($_.Exception.Response.StatusDescription) $responseBody"
        }
        else
        {
            Write-OctopusVerbose $_.Exception
        }
    }

    Throw "There was an error calling the Octopus API please check the log for more details"
}
function Write-OctopusVerbose
{
    param($message)
    
    Add-Content -Value $message -path "C:\temp\test.txt"
}
function Write-OctopusSuccess
{
    param($message)

    Write-Host $message -ForegroundColor Green
    Write-OctopusVerbose $message    
}
function Get-OctopusSpaceId
{
    param(
        $octopusData        
    )

    if ($octopusData.hasSpaces -eq $true)
    {                
        Write-OctopusVerbose "Getting Space Information from $octopusUrl"
        $SpaceList = Get-OctopusSpaceList -octopusData $octopusData
        $Space = Get-OctopusItemByName -ItemList $SpaceList -ItemName $spaceName

        if ($null -eq $Space)
        {
            Throw "Unable to find space $spaceName on $octopusUrl please confirm it exists and try again."
        }

        return $Space.Id        
    }
    else
    {
        return $null
    }
}
Function Get-OctopusApiItemList
{
    param (
        $EndPoint,
        $ApiKey,
        $SpaceId,
        $OctopusUrl
    )

    $url = Get-OctopusUrl -EndPoint $EndPoint -SpaceId $SpaceId -OctopusUrl $OctopusUrl

    $results = Invoke-OctopusApi -Method "Get" -Url $url -apiKey $ApiKey

    Write-OctopusVerbose "$url returned a list with $($results.Items.Length) item(s)"

    return $results.Items
}
function Get-OctopusSpaceList
{
    param (
        $octopusData
    )

    return Get-OctopusApiItemList -EndPoint "spaces?skip=0&take=1000" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -SpaceId $null
}
Function Get-OctopusStepTemplateList
{
    param(
        $octopusData
    )

    return Get-OctopusApiItemList -EndPoint "actiontemplates?skip=0&take=1000" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -SpaceId $octopusData.SpaceId
}
Function Get-OctopusProjectList
{
    param (        
        $octopusData
    )

    return Get-OctopusApiItemList -EndPoint "Projects?skip=0&take=1000" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -SpaceId $octopusData.SpaceId
}
function Get-OctopusPackageList
{
    param(
        $octopusData
    )

    return Get-OctopusApiItemList -EndPoint "packages?filter=&latest=true&take=1000" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -spaceId $octopusData.SpaceId
}
Function Get-OctopusFeedList
{
    param(
        $octopusData
    )

    return Get-OctopusApiItemList -EndPoint "feeds?skip=0&take=1000" -ApiKey $octopusData.OctopusApiKey -OctopusUrl $octopusData.OctopusUrl -SpaceId $octopusData.SpaceId
}

$ErrorActionPreference = "Stop"

$defaultSpaceId = Invoke-WebRequest -Uri "$octopusURI/api/spaces/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12 | Where-Object {$_.Name -eq $defaultSpaceName}
$defaultSpaceId = $defaultSpaceId.Id

$sourceData = Get-OctopusData -octopusUrl $octopusURI -octopusApiKey $apikey -spaceName $SourceSpaceName
$destinationData = $sourceData

$runbook = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/$runbookId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12
$runbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$runbookId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

#Set the runbook name
$runbookName = $runbook.Name

$matchingtargets = $RunbookProcess.Steps[0].Properties.'Octopus.Action.TargetRoles'.Split(',')

$Projects = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/projects/all" -Headers $header | ConvertFrom-Json -Depth 12
if ([string]::IsNullOrEmpty($DestinationProjectId)) {
    $Projects = $Projects | where-Object {$_.Name -notlike "*Example*" -and $_.Name -notlike "*test*"} 
}
else {
    $Projects = $Projects | where-Object {$_.id -eq $DestinationProjectId} 
}

if ($null -ne $runbookProcess) {
    foreach ($project in $Projects) {
        $projectid = $project.Id
        $projectname = $project.Name
        Write-host "`nFinding Deployment process for $projectname"
        $deploymentprocesses = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/deploymentprocesses/deploymentprocess-$projectid" -Headers $header | ConvertFrom-Json -Depth 12
        if ($null -ne $deploymentprocesses.Steps[0]) {
            $deploymentprocess = $deploymentprocesses | ?{$_.ProjectId -eq $projectid}
            foreach($step in $deploymentprocess.Steps) {
                $targetrole = $step.Properties.'octopus.Action.TargetRoles'
                if ($null -ne $targetrole) {
                    Break
                }
                else {
                    continue
                }
            }
            foreach ($matchingtarget in $matchingtargets) {
                if ($targetrole -eq $matchingtarget) {
                    Write-host "$projectname is matching the runbook on $matchingtarget"
                    $allrunbooks = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12
                    $runbookexist = $allrunbooks | where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $projectid}
                    if ($runbookName -ne $runbookexist.name) {
                        Write-Host "Creating runbook for $projectname" -ForegroundColor Green
                        #Edit runbook config with new values.
                        $runbook.ProjectId = $projectid
                        $runbook.Links.Project = "/api/$defaultSpaceId/projects/$projectid"
                        $runbook.Id = $null
                        $runbook.RunbookProcessId = $null

                        #Create runbook.
                        Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/" -Method POST -Headers $header -Body ($runbook | ConvertTo-Json -Depth 12)

                        #Find new runbook
                        $NewRunbooks = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12
                        $newRunbook = $NewRunbooks | where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $projectid}

                        #Set the new runbookId and new process ID.
                        $NewRunbookId = $newRunbook.Id
                        $NewRunbookProcessId = $newRunbook.RunbookProcessId

                        #Find runbook process.
                        $runbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$runbookId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

                        #Edit runbooks process with new values.
                        $runbookProcess.Steps[0].Properties.'Octopus.Action.TargetRoles' = $targetrole
                        $destinationRunbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/$NewRunbookProcessId " -Method GET -Headers $header | ConvertFrom-Json -Depth 12

                        $destinationRunbookProcess.Steps = @(Copy-OctopusDeploymentProcess -sourceData $sourceData -destinationData $destinationData -sourceDeploymentProcessSteps $runbookProcess.Steps -destinationDeploymentProcessSteps $destinationRunbookProcess.Steps)
                        Invoke-RestMethod -Method Put -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$NewRunbookId" -Headers $header -Body ($destinationRunbookProcess | ConvertTo-Json -Depth 12) -ContentType 'application/json; charset=utf-8'
                    }
                    else {
                        Write-Warning "$runbookName already exists! Trying to update the process..."

                        #Find runbook
                        $NewRunbooks = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbooks/all" -Method GET -Headers $header | ConvertFrom-Json -Depth 12
                        $newRunbook = $NewRunbooks |  where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $projectid}

                        #Set the new runbookId and new process ID.
                        $NewRunbookId = $newRunbook.Id
                        $NewRunbookProcessId = $newRunbook.RunbookProcessId

                        #new runbook process
                        $newrunbookprocess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/$NewRunbookProcessId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

                        #Find runbook process.
                        $runbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$runbookId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

                        $runbookProcess.Steps[0].Properties.'Octopus.Action.TargetRoles' = $targetrole
                        if ($null -eq $newrunbookprocess.steps[0]) {
                            $destinationRunbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/$NewRunbookProcessId " -Method GET -Headers $header | ConvertFrom-Json -Depth 12
                            $destinationRunbookProcess.Steps = @(Copy-OctopusDeploymentProcess -sourceData $sourceData -destinationData $destinationData -sourceDeploymentProcessSteps $runbookProcess.Steps -destinationDeploymentProcessSteps $destinationRunbookProcess.Steps)
                            Invoke-RestMethod -Method Put -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$NewRunbookId" -Headers $header -Body ($destinationRunbookProcess | ConvertTo-Json -Depth 12) -ContentType 'application/json; charset=utf-8'
                        }
                        if ($newrunbookprocess.Steps[0].Properties.'Octopus.Action.TargetRoles' -eq $targetrole) {
                            Write-Warning "The runbook process already contains a the matching target role from the runbook."
                            break
                        }
                        if ($newrunbookprocess.Steps[0] -ne $runbookProcess.Steps[0]) {
                            Write-Warning "The steps are different. Copying the steps from the example to the already existing runbook process."
                            $destinationRunbookProcessRemove = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/$NewRunbookProcessId" -Method GET -Headers $header | ConvertFrom-Json -Depth 12

                            #Removes current steps in runbook
                            $destinationRunbookProcessRemove.Steps = $null

                            Invoke-RestMethod -Method Put -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$NewRunbookId" -Headers $header -Body ($destinationRunbookProcessRemove | ConvertTo-Json -Depth 12) -ContentType 'application/json; charset=utf-8'

                            #Adds steps
                            $destinationRunbookProcess = Invoke-WebRequest -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/$NewRunbookProcessId " -Method GET -Headers $header | ConvertFrom-Json -Depth 12
                            $destinationRunbookProcess.Steps = @(Copy-OctopusDeploymentProcess -sourceData $sourceData -destinationData $destinationData -sourceDeploymentProcessSteps $runbookProcess.Steps -destinationDeploymentProcessSteps $destinationRunbookProcess.Steps)
                            Invoke-RestMethod -Method Put -Uri "$octopusURI/api/$defaultSpaceId/runbookProcesses/RunbookProcess-$NewRunbookId" -Headers $header -Body ($destinationRunbookProcess | ConvertTo-Json -Depth 12) -ContentType 'application/json; charset=utf-8'
                        }
                    }
                }
            }
        }
        else {
            Write-Warning "Can't find any deployment process for $projectname"
            continue
        }
    }
}
else {
    Write-Warning "Runbook Process not found for $runbookId"
}
