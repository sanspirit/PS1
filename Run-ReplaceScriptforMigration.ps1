
<#
.SYNOPSIS
    Triggers the replacement script
.DESCRIPTION
    Triggers the replacement script with a json list input with values OldValue, NewValue and Type

.EXAMPLE
    .\src\Run-ReplaceScriptforMigration.ps1 -environment "WP" -variablelist "D:\Migration\VarList.json" -dryrun $false
#>
[CmdletBinding()]
Param (

    [Parameter(Mandatory = $True)]
    [string]
    $environment,

    [Parameter(Mandatory = $True)]
    [string]
    $variablelist,

    [Parameter(Mandatory = $True)]
    [bool]
    $dryrun
)

$jsonvarlist = $variablelist | ConvertFrom-Json

$replacescript = $PSScriptRoot+"\Replace-ConfigString.ps1"

foreach ($repvar in $jsonvarlist) {
        Write-Host "Running variable replace script on $($repvar.OldValue)"
        & $replacescript -environment $environment -filetypes "*.config","*.json" -oldstring $repvar.OldValue -newstring $repvar.NewValue -serviceorsite $repvar.Type -dryrun $dryrun
}

