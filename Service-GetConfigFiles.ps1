<#
.SYNOPSIS
    Finds the service path and removes any flags for the exe. Finds the config file for the exe and outputs it into a Octopus artifact.
.DESCRIPTION
    Powershell script that will get the path of the service using ciminstance, it will then replace anything after the .exe with nothing. Using this, it will test the path and output the contents of the path.config to a
    Octopus Artifact. 
.EXAMPLE
    .\src\Service-GetConfigFiles.ps1 -servicename FT1.Fusion.Dms.ApiHost -filestocheck ("*.config","Fusion.Dms.Api.pdb")
#>

Param(

    [Parameter()]
    [string]
    $servicename,

    [Parameter()]
    [array]
    $filestocheck

)

$service = Get-Service -Name $servicename -ErrorAction SilentlyContinue

if ($service) {
    $path = ((Get-cimInstance win32_service -filter "name like '$servicename'").PathName.split(" ")[0]).Trim('"')
    $path = $path.Substring(0, $path.lastIndexOf('\')) + '\'
    $files = (Get-Childitem -Path $path)
    foreach ($file in $filestocheck) {
        write-host "Checking for $file"
        if ($file -like "***") {
            if ($files | Where-Object {$_.Name -like $file}) {
                Write-host "Found files matching $file..."
                foreach ($matchingfile in ($files | Where-Object {$_.Name -like $file}).Name) {
                    Write-host "Grabbing content for $matchingfile"
                    Write-Output "$path\$matchingfile" | New-OctopusArtifact -Name "$matchingfile.txt" 
                }
            }
        }
        if ($file -in $files.Name) {
            write-host "Found $file, outputting..."
            Write-Output "$path\$file" | New-OctopusArtifact -Name "$file.txt"
        }
    }
}
else {
    Write-Warning "Can't find $servicename"
}

