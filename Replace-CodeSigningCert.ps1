<#
.SYNOPSIS
    Replace Code Signing Certs
.DESCRIPTION
    Powershell script that will replace the code signing cert for defined VMs using Octopus. 
.EXAMPLE
    .\src\Replace-CodeSigningCert.ps1 -CodeSigningCert CodeSigning
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $CodeSigningCert

)

$newcertthumbprint = $OctopusParameters["$CodeSigningCert.Thumbprint"]
$newcertCN = $OctopusParameters["$CodeSigningCert.Subject"]
$newcertcn = $newcertcn.replace(',',', ')

Write-Verbose "Subject: $newcertcn"
Write-Verbose "Thumbprint: $newcertthumbprint"

$currentcerts = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$PSItem.Subject -eq $newcertCN -and $PSItem.EnhancedKeyUsageList.FriendlyName -eq "Code Signing"}
$oldcert = $currentcerts | Where-Object {$PSItem.Thumbprint -ne $newcertthumbprint}
$newcert = $currentcerts | Where-Object {$PSItem.Thumbprint -eq $newcertthumbprint}

if ($newcert) {
    if ($oldcert) {
        if (!($oldcert.count -gt 1)) {
            Write-host "Found new cert on $ENV:COMPUTERNAME, found old cert as well. Proceeding with deleting the old certificate."
            $oldcert | Remove-Item 
        }
        else {
            Write-Warning "Found multiple old codesigning certificates matching $newcertCN on $ENV:COMPUTERNAME"
            $oldcert
        }
    }
    else {
        Write-Verbose "No old cert found on $ENV:COMPUTERNAME."
    }
}
else {
    Write-warning "Can't find new certificate on $ENV:COMPUTERNAME."
}
