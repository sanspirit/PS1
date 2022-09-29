<#
.SYNOPSIS
    Get the package ID, name, site status and app pool status of a site
.DESCRIPTION
    Using the sitename, the script will grab the site and print out the name of the site, app pool status, site status and the package ID.

    It takes the path from $websitepath and splits it. For example, if the path is C:\Octopus\Applications\FT1\Orion\Enable.AccessApi.Api\1.4.0.34, it takes the package ID '1.4.0.34'
    and sets that as the version.
.EXAMPLE
    Website-GetVersion.ps1 -sitename EnableAccessApiFeature1 

    SiteStatus  Name                        PackageID   AppPoolStatus 
    ----------  ----                        ---------   ------------- 
    Started     EnableAccessApiFeature1     1.4.0.34    Started       
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename

)

$ErrorActionPreference = "SilentlyContinue"

function Get-AppPoolFromSite {
    param (
        $sitename
    )

    $manager = Get-IISServerManager
    $website = $manager.Sites[$sitename]
    $apppool = $website.Applications["/"].ApplicationPoolName
    Write-Output $apppool
}

Import-Module WebAdministration
$sites = Get-IISSite | Where-Object { $_.Name -like "*$sitename*" }

if ($null -ne $sites) {
    foreach ($site in $sites)
    {
        if (Test-Path IIS:\Sites\$site) {
            $websitepath = Get-WebFilePath IIS:\Sites\$site
            $apppool = Get-AppPoolFromSite -sitename $site
            $arr = New-Object psobject -Property @{
                Name=$site
                AppPoolStatus=(Get-WebAppPoolState -Name $apppool).Value
                SiteStatus=(Get-IISSite $site).State
                PackageID=Split-Path $websitepath -Leaf
            }
            $arr
        }
    }
}
else {
    Write-Warning "Can't find any sites that include $sitename"
}
