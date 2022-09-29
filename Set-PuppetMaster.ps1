Param (
    [Parameter()]
    [string]
    $puppetloc = "C:\ProgramData\PuppetLabs\puppet\etc",
    [Parameter()]
    [string]
    $current_puppetmasterfqdn = "ctpuppet-apps.4lj5i20vb2buhibasr5qzpjs3g.fx.internal.cloudapp.net",
    [Parameter()]
    [string]
    $new_puppetmasterfqdn = "cor-puppetapps-01.creative.local"
)

#Replace the server field in the puppet conf file.
Write-Host "Working on $($env:COMPUTERNAME)"
try {
    Get-Service -Name puppet | Stop-Service -ErrorAction Stop
}
catch {
    Write-Error "Unable to stop puppet service on $($env:COMPUTERNAME)"
    exit -1
}

if ((get-childitem $puppetloc).name -contains "puppet.conf") {

    write-host "Found puppet.conf file!"
    $puppetconfdoc = $puppetloc + "\puppet.conf"

    try {
        ((Get-Content $puppetconfdoc -Raw -ErrorAction Stop) -replace "server=$current_puppetmasterfqdn", "server=$new_puppetmasterfqdn") | Set-Content $puppetconfdoc -ErrorAction Stop

        if (Select-String -Path $puppetconfdoc -Pattern $new_puppetmasterfqdn -ErrorAction Stop) {
            write-host "Changed puppet.conf server setting to: $new_puppetmasterfqdn on $($env:COMPUTERNAME)"
        }
        else {
            Write-Warning "Unable to change the puppet.conf file"
            exit -1
        }
    }
    catch {
        Write-Error "Unable to complete the puppet.conf update on $($env:COMPUTERNAME)"
        Write-Error $_.Exception
        exit -1
    }
}

else {
    Write-Warning "Can't find the puppetconf file."
}

$sslloc = $puppetloc + "\ssl"

#Delete SSL certs used by puppet

if (get-childitem $sslloc) {
    write-host "`nFound SSL docs on $($env:COMPUTERNAME)!"
    try {
        Get-ChildItem -Path $sslloc -Recurse -ErrorAction Stop | Remove-Item -force -recurse -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to delete SSL directory on $($env:COMPUTERNAME)"
        Write-Error $_.Exception
        exit -1
    }
    
    if ((Get-ChildItem -Path $sslloc).count -eq 0) {
        write-host "SSL Directory is now empty."
    }
    else {
        write-warning "SSL directory isn't empty..."
        exit -1
    }
}

else {
    Write-Warning "Can't find the ssl docs or directory is empty."
    exit -1
}

$poshTransLoc = "C:\Transcripts\Powershell"
if (get-childitem $poshTransLoc) {
    write-host "`nFound PowerShell transcript directory"
    try {
        Get-ChildItem -Path $poshTransLoc -Recurse -ErrorAction Stop | Where-Object {($_.DirectoryName -ne "$poshTransLoc\$(get-date -f "yyyyMMdd")") -and ($_.Name -ne "$(get-date -f "yyyyMMdd")")} | Remove-Item -force -recurse -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to delete PowerShell transcript directory on $($env:COMPUTERNAME)"
        Write-Error $_.Exception
        exit -1
    }
}


try {
    Get-Service -Name puppet | Start-Service -ErrorAction Stop
    puppet agent --test
}
catch {
    Write-Warning "Unable to start puppet service on $($env:COMPUTERNAME)"
}
