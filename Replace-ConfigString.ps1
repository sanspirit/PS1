
<#
.SYNOPSIS
    Replaces a string found in a config file for a Website
.DESCRIPTION
    Replaces a string found in a config file

.EXAMPLE
    .\src\Replace-ConfigString.ps1 -filetypes "*.config","*.json" -oldstring "replaceme" -newstring "replaced" -dryrun $false
#>
[CmdletBinding()]
Param (

    [Parameter(Mandatory = $True)]
    [string]
    $environment,

    [Parameter(Mandatory = $True)]
    [array]
    $filetypes,

    [Parameter(Mandatory = $True)]
    [string]
    $oldstring,

    [Parameter(Mandatory = $True)]
    [string]
    $newstring,

    [Parameter(Mandatory = $True)]
    [bool]
    $dryrun,

    [Parameter(Mandatory = $True)]
    [ValidateSet("site", "service")]
    [string]
    $serviceorsite
)

function Set-ConfigString {
    param (
        $configdir,
        $objname,
        $oldstring,
        $newstring,
        $filetypes
    )
    
    $configfound = $null
    $nonwebconfigfound = $null

    if ($null -eq $configdir) {
        
        write-host "No path for $objname"
        continue
    }
    
    if (-not (Test-Path $configdir)) {
        
        write-host "Path doesn't exist for $objname"
        continue
    }

    $configs = $filetypes | ForEach-Object { Get-ChildItem $configdir -Filter $PSItem }
    if (-not $configs) {
        
        write-host "No configs for $objname"
        continue
    }
    
    foreach ($config in $configs) {
        
        $configName = $config.FullName
        $configFile = $config.Name
        $content = Get-Content ($configName)
        $match = $content | Select-String $oldstring
        if ($match) {
            Write-Host "    String: $oldstring found in $($configFile), LN:$($match.LineNumber)" -ForegroundColor Cyan
            $configfound = $true
            if ($configFile -ne "web.config") {$nonwebconfigfound = $true} else {$nonwebconfigfound = $false}
            Write-Host "    Replacing string with $newstring"
            $content = $content -ireplace [regex]::Escape($oldstring),$newstring
            if ($false -eq $dryrun) {
                Set-Content -Path $configName -Value $content -Encoding UTF8
            }
        }
    }
    $return = [PSCustomObject]@{
        ConfigFound = $configfound
        NonWebConfig = $nonwebconfigfound
    }
    return $return
}

function ReplaceOnSite {
    param (
        [ValidateSet("IISSite", "IISApp")]
        $iisobj,
        $sitepath,
        $sitename,
        $oldstring,
        $newstring,
        $filetypes
    )
    if ($sitepath)
        {
            $replacedconfig = Set-ConfigString -configdir $sitepath -objname $sitename -oldstring $oldstring -newstring $newstring -filetypes $filetypes

            Write-Verbose "App=$sitename, NonWebConfig=$($replacedconfig.NonWebConfig), ConfigFound=$($replacedconfig.ConfigFound)"

            if ($True -eq $replacedconfig.ConfigFound -and $True -eq $replacedconfig.NonWebConfig) {
                Write-Host "File replaced includes non web.config, restarting app pool" -ForegroundColor Green
                if ($iisobj -eq "IISSite") {
                    $appPool = Get-IISAppPool -Name $site.Applications[0].ApplicationPoolName
                }
                elseif ($iisobj -eq "IISApp") {
                    $appPool = Get-IISAppPool -Name (Get-WebApplication $sitename).applicationpool
                }
                if ($false -eq $dryrun) {
                    RestartAppPool -appPool $appPool
                }
            }
        }
        Write-Host "--------------------------------------"
}

function RestartAppPool {
    param (
        $appPool
    )
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

if ($true -eq $dryrun) {
    Write-Warning "Running in dryrun mode - no changes will be made"
}

if ($serviceorsite -eq "service") {
    
    $servicelist = Get-Service "$environment*"
    foreach ($svc in $servicelist)
    {
        $svcname = $svc.Name
        Write-Host "Searching $svcname" -ForegroundColor DarkCyan

        $svcpath = ((Get-WmiObject win32_service | Where-Object {$_.Name -like $svcname} | Select-Object Name, DisplayName, @{Name="Path"; Expression={$_.PathName.split('"')[1]}})).Path
        if ($svcpath)
        {
            $svcdir = (Get-Item $svcpath).Directory
            $replacedconfig = Set-ConfigString -configdir $svcdir -objname $svcname -oldstring $oldstring -newstring $newstring -filetypes $filetypes
            if ($True -eq $replacedconfig.ConfigFound) {
                Write-Host "Restarting Service" -ForegroundColor Green
                if ($false -eq $dryrun) {
                    Restart-Service $svcname
                }
            }
        }
    }
    Write-Host "--------------------------------------"
}
elseif ($serviceorsite -eq "site") {

    Import-Module IISAdministration
    Import-Module WebAdministration
    
    $sitelist = Get-IISSite | Where-Object {$PSItem.Name -like "*$environment*"}
    foreach ($site in $sitelist)
    {
        $sitename = $site.Name
        Write-Host "Searching $sitename"
        
        $sitepath = Get-WebFilePath "IIS:\Sites\$sitename"
        ReplaceOnSite -iisobj IISSite -sitepath $sitepath -sitename $sitename -oldstring $oldstring -newstring $newstring -filetypes $filetypes
    }

    $iisaaplist = Get-WebApplication | Where-Object {($PSItem.path.TrimStart("/")) -like "*$environment*"}
    foreach ($iisapp in $iisaaplist)
    {
        $iisappname = $iisapp.path.TrimStart("/")
        Write-Host "Searching $iisappname"
        
        $iisapppath = $iisapp.PhysicalPath
        ReplaceOnSite -iisobj IISApp -sitepath $iisapppath -sitename $iisappname -oldstring $oldstring -newstring $newstring -filetypes $filetypes
    }
}
