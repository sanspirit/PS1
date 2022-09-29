<#
.SYNOPSIS
    Replacing IIS certs
.DESCRIPTION
    Powershell script that will replace the cert in a web binding if a new cert has been replaced in Octopus
.EXAMPLE
    .\src\Replace-Cert.ps1 -SSLcert SDocV
#>

 Param(

     [Parameter(Mandatory)]
    [string]
    $SSLcert
)
Import-Module WebAdministration

$newcerthash = $OctopusParameters["$SSLcert.Thumbprint"]
$newcertCN = $OctopusParameters["$SSLcert.SubjectCommonName"]
Write-Host "new cert hash: $newcerthash"

## Replace certs in bindings where new cert is not found

$sites = (Get-IISSite).name
foreach ($site in $sites) {
    $bindings = Get-WebBinding -name $site
    foreach ($binding in $bindings) {
        if ($binding.protocol -eq 'https') {

            $currentcert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $PSItem.Thumbprint -match $binding.CertificateHash }
                
            if ($currentcert.Subject -like "*$newcertCN*") {
                    
                Write-Host "Subject matches new cert for $site"
                
                if ($currentcert.Thumbprint -ne $newcerthash) {
                    Write-Host "Found site: $site, old cert: $($currentcert.Thumbprint), new cert: $newcerthash"
                    $binding.AddSslCertificate($newcerthash, "my")
                }
                else {
                    Write-Host "New Cert is already in binding"
                }
            }
            else {
                Write-Host "excluding site $site"
            }
        }
        else { Write-Host "excluding http site $site" }
    } 
}
