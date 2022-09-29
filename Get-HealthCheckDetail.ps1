<#
.SYNOPSIS
    Calls cthealthcheckdetail 
	- returns 0 if Healthy or Degraded
	- returns 1 on other Status values
	- returns 2 if there is an Exception
.DESCRIPTION
    Powershell script that calls cthealthcheckdetail 
	- works against the CT Custom Healthchecks
	- works against the standard .NET Core Healthchecks
.EXAMPLE
    .\src\Get-Get-HealthCheckDetail.ps1 
#>

$scheme = $OctopusParameters["Runbook:HealthCheck:Scheme"]
$port = $OctopusParameters["Runbook:HealthCheck:Port"]
$baseUrl = $OctopusParameters["Runbook:HealthCheck:BaseUrl"]

# helper to turn PSCustomObject into a list of key/value pairs
function Get-ObjectMember {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"}
    }
}

function Show-Ct-HealthCheck {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )

    Write-Host ($obj | Format-Table | Out-String)

    Write-Host ($obj.RequiredChecks | Format-Table | Out-String)

    Write-Host ($obj.OptionalChecks | Format-Table | Out-String)

    $obj.OverallHealth -eq "Healthy" -OR $obj.OverallHealth -eq "Degraded"
}

function Show-Net-Core-HealthCheck {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )

    $entries = $obj | Get-ObjectMember | foreach {
        $_.Value | Get-ObjectMember | foreach {
            [PSCustomObject]@{
                Status = $_.Value.status | select -First 1
                Key = $_.key | select -First 1
                Duration = $_.value.duration | select -First 1            
                #Tags = $_.Value.tags | select -First 1
                #Data = $_.value.data | select -First 1
            }
        }
    }

    Write-Host "The service is" $obj.status
   
    Write-Host ($entries | Format-Table | Out-String)
    
    $obj.status -eq "Healthy" -OR $obj.status -eq "Degraded"
}

try
{
	$headers = @{
	 'Accept-Charset'     = 'utf-8'
	 'Accept'             = 'application/json'
	 'Content-Type'       = 'application/json; charset=utf-8'
	 'X-HealthCheckDetail'='136fb76e-f772-43e7-bff9-a76d65a7afc4'
	 }

	$builder = New-Object System.UriBuilder
	$builder.Host = $baseUrl
	$builder.Path = ('cthealthcheckdetail' -join '/')
	$builder.Port = $port
	$builder.Scheme = $scheme

    Write-Host $builder.ToString()

    $response = Invoke-WebRequest -Uri $builder.ToString() -Method Get -Headers $headers
    
    $testValidJson = $response.Content | ConvertFrom-Json
    if($testValidJson.GetType() -eq [System.Management.Automation.PSCustomObject])
    {
        # NetCore HealthChecks
        $isOk = Show-Net-Core-HealthCheck $testValidJson
    }
    else
    {
        # CT HealthChecks        
        $isOk =  [System.Text.Encoding]::UTF8.GetString($response.Content) | ConvertFrom-Json | Show-Ct-HealthCheck
    }

    if($isOk)
    {
        exit 0
    }
    else
    {
        exit 1
    }
}
catch
{
    $_
    exit 2
}
