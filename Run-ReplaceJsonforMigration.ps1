
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
    [bool]
    $dryrun
)

function Get-ConfigFiles {
    param (
        $configdir,
        $site
    )
    $configchanged = $null
    $filetypes = "*.json"

    if ($null -eq $configdir) {
        
        write-host "No path for $($site.name)"
        continue
    }
    
    if (-not (Test-Path $configdir)) {
        
        write-host "Path doesn't exist for $($site.name)"
        continue
    }

    $configs = $filetypes | ForEach-Object { Get-ChildItem $configdir -Filter $PSItem }
    if (-not $configs) {
        
        write-host "No configs for $($site.name)"
        continue
    }
    
    foreach ($config in $configs) {
        Write-Verbose "Searching in $($config.Fullname)"
        $configchanged = (Replace-JsonConfigs -file $config -site $site).ConfigFound
    }
    if ($configchanged -eq $true) {
        RestartAppPool -site $site
    }
}

function RestartAppPool {
    param (
        $site
    )
    $appPool = Get-IISAppPool -Name $site.Applications[0].ApplicationPoolName

    if ($appPool.State -eq "Starting") {
        do {
            Start-Sleep 1
            Write-Host "Waiting for AppPool to be Started"
        }
        until ((Get-IISAppPool $appPool.Name).State -eq "Started")
        Write-Verbose "Restarting AppPool"
        if ($false -eq $dryrun) {
            $appPool | Restart-WebAppPool
        }
    }
    elseif ($appPool.State -eq "Stopping") {
        do {
            Start-Sleep 1
            Write-Host "Waiting for AppPool to be Stopped"
        }
        until ((Get-IISAppPool $appPool.Name).State -eq "Stopped")
        Write-Verbose "Starting stopped AppPool"
        if ($false -eq $dryrun) {
            $appPool | Start-WebAppPool
        }
    }
    elseif ($appPool.State -eq "Stopped") {
        Write-Verbose "Starting stopped AppPool"
        if ($false -eq $dryrun) {
            $appPool | Start-WebAppPool
        }
    }
    else {
        Write-Verbose "Restarting AppPool"
        if ($false -eq $dryrun) {
            $appPool | Restart-WebAppPool
        }
    }
}

function Replace-JsonConfigs {
    param (
        $file,
        $site
    )
    $configfound = $null

    $filestoragejson = $filestoragejson | ConvertFrom-Json
    $docrendererjson = $docrendererjson | ConvertFrom-Json
    $fsidentjson = $fsidentjson | ConvertFrom-Json
    $fswebjson = $fswebjson | ConvertFrom-Json

    $filejson = Get-content $file.FullName | ConvertFrom-Json

    if ($filejson.FileStorageSettings.BaseUrl -eq $filestoragejson.OldValue) {
        Write-Host "    FileStorageSettings.BaseUrl found to replace in $($file.Name), old value: $($filejson.FileStorageSettings.BaseUrl), new value: $($filestoragejson.NewValue)"
        $filejson.FileStorageSettings.BaseUrl = $filestoragejson.NewValue
        $configfound = $true
    }
    if ($filejson.FileStorageSettings.BaseUri -eq $filestoragejson.OldValue) {
        Write-Host "    FileStorageSettings.BaseUri found to replace in $($file.Name), old value: $($filejson.FileStorageSettings.BaseUri), new value: $($filestoragejson.NewValue)"
        $filejson.FileStorageSettings.BaseUri = $filestoragejson.NewValue
        $configfound = $true
    }
    if ($filejson.DocumentRendererSettings.BaseUri -eq $docrendererjson.OldValue) {
        Write-Host "    DocumentRendererSettings.BaseUri found to replace in $($file.Name), old value: $($filejson.DocumentRendererSettings.BaseUri), new value: $($docrendererjson.NewValue)"
        $filejson.DocumentRendererSettings.BaseUri = $docrendererjson.NewValue
        $configfound = $true
    }
    if ($filejson.Fusion.Identity.Api.Base.Uri -eq $fsidentjson.OldValue) {
        Write-Host "    Fusion.Identity.Api.Base.Uri found to replace in $($file.Name), old value: $($filejson.Fusion.Identity.Api.Base.Uri), new value: $($fsidentjson.NewValue)"
        $filejson.Fusion.Identity.Api.Base.Uri = $fsidentjson.NewValue
        $configfound = $true
    }
    if ($filejson.Fusion.AntiCorruption.Api.BaseUri -eq $fswebjson.OldValue) {
        Write-Host "    Fusion.AntiCorruption.Api.BaseUri found to replace in $($file.Name), old value: $($filejson.Fusion.AntiCorruption.Api.BaseUri), new value: $($fswebjson.NewValue), new port: $($fswebjson.NewPort)"
        $filejson.Fusion.AntiCorruption.Api.BaseUri = $fswebjson.NewValue
        $filejson.Fusion.AntiCorruption.Api.Port = $fswebjson.NewPort
        $configfound = $true
    }
    
    if ($true -eq $configfound) {
        $changedfile = $filejson | ConvertTo-Json -Depth 12
        Write-Host "    Setting new values to $($file.fullname)"
        if ($false -eq $dryrun) {
            Set-Content -Path $file.FullName -Value $changedfile
        }
    }
    $return = [PSCustomObject]@{
        ConfigFound = $configfound
    }
    return $return
}

Import-Module IISAdministration
Import-Module WebAdministration

if ($true -eq $dryrun) {
    Write-Warning "Running in dryrun mode - no changes will be made"
}

$sitelist = Get-IISSite | Where-Object {$PSItem.Name -like "*$environment*"}
    foreach ($site in $sitelist)
    {
        $sitename = $site.Name
        Write-Host "Searching $sitename"
        
        $sitepath = Get-WebFilePath "IIS:\Sites\$sitename"
        Get-ConfigFiles -configdir $sitepath -site $site
        Write-Host "---------------------------------------"
    }
