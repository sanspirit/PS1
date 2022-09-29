Param (

    [Parameter()]
    [string]
    $functionappname,

    [Parameter()]
    [string]
    $nsgname = "sftp-neu-nsg",

    [Parameter()]
    [string]
    $rulename = "SFTP"

)

$ErrorActionPreference = 'stop'

#Get All outbound IPs for Function Apps

$ips = $null
$subsciptions = az account list | convertfrom-json

foreach ($sub in $subsciptions) {
    Write-host "Checking $($sub.name)"
    if ((az functionapp list --subscription $sub.Id | convertfrom-json).name) {
        foreach ($functionapp in az functionapp list --subscription $sub.id | convertfrom-json) {
            if ($functionapp.name -like "*$functionappname*") {
                Write-host "Found $($functionapp.name). Retrieving IPs"
                $functionappdata = az functionapp show --name $functionapp.name --resource-group $functionapp.ResourceGroup --subscription $sub.id | ConvertFrom-Json
                $ips += $functionappdata.outboundIpAddresses+","
                Write-host "IPs retrieved for $($functionapp.name)" -ForegroundColor Green
            }
            else {
                Write-warning "Skipping $($functionapp.name) as doesn't match with $functionappname"
            }
        }
    }
    else {
        Write-Warning "Can't find any function apps for $($sub.name)"
    }
}

$ips = $ips -replace "`n"
$ips = $ips.trimend(",")
$ips = $ips.split(",")

#Get Security group!

$infrasub = $subsciptions | Where-Object {$_.name -eq "CTInfrastructure"}

if ((az network nsg list --subscription $infrasub.id | ConvertFrom-Json).name -contains $nsgname) {
    foreach ($nsg in az network nsg list --subscription $infrasub.id | ConvertFrom-Json) {
        if ($nsg.name -like "*$nsgname*") {
            Write-host "Found $nsgname)"
            $nsgtochange = az network nsg show --name $nsg.name --resource-group $nsg.ResourceGroup --subscription $infrasub.id | convertfrom-json
            if ($nsgtochange.securityRules.name -contains $rulename) {
                $currentips = $nsgtochange.securityRules.sourceaddressprefixes
                $totalips = $currentips + $ips
                $totalips = $totalips | Select-Object -Unique
                az network nsg rule update --name $rulename --nsg-name $nsg.name --resource-group $nsg.ResourceGroup --subscription $infrasub.id --source-address-prefixes $totalips
                break
            }
            else {
                Write-Error "Found $nsgname but can't find the rule: $rulename "
            }
        }
        else {
            Write-warning "Skipping $($nsg.name)..."
        }
    }
}
else {
    Write-Error "Can't find NSG: $nsgname"
}

