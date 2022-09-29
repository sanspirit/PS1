<#
.SYNOPSIS
    Enables stdout if false, null or anything else. Enables and sets the log path to .\logs\stdout.
.DESCRIPTION
    A powershell script that enables stdout and sets the log file path. If the stdout status is set to False, it will switch it to true, if it's set to something random or a type, E.G 'stdoutLogEnabled = "fsddfs"', it will change
    it to True. if it's not present in the config file, it will add it. The same principals apply to the log file path.
.EXAMPLE
    Website-EnableStdout.ps1 -sitename EnableAccessApiFeature1
#>

Param(

    [Parameter(Mandatory)]
    [string]
    $sitename

)

function Find-Logging {
    Write-Host "Checking $configName if the log path is correct."
    if ($content | Select-String 'stdoutLogFile=".*"') {
        if ($content | Select-String 'stdoutLogFile="..logs.stdout"') {
            Write-Host "Logging is already stored in .\logs\stdout"
            exit
        }
        else {
            Write-Host "Updating the logfile path to .\logs\stdout"
            (Get-Content $configName) -Replace 'stdoutLogFile=".*"','stdoutLogFile=".\logs\stdout"' | Set-Content -Path $configName -Encoding UTF8
            exit
        }
    }
}

write-host "Looking at $sitename"
$siteInQuestion = Get-WebFilePath "IIS:\Sites\$sitename";
if ($siteInQuestion) {
    $pathname = $siteInQuestion
    $configs = (Get-ChildItem $pathname -Filter *.config)
    foreach ($config in $configs)
    {
        $configName = $configs.FullName;
        $content = Get-Content ($configName)
        Write-Host "Checking $configName if stdout is enabled."
        if ($content | Select-String 'stdoutLogEnabled=".*"') {
            if ($content | Select-String 'stdoutLogEnabled="False"') {
                Write-Host "Replacing StdoutLogEnabled from False to True."
                (Get-Content $configName) -Replace 'stdoutLogEnabled="False"','stdoutLogEnabled="True"' | Set-Content -Path $configName -Encoding UTF8
                Find-Logging
            }
            if ($content | Select-String 'stdoutLogEnabled="True"') {
                Write-Host "stdout is already enabled."
                Find-Logging
            }
            else {
                Write-Host "Updating the stdoutLogEnabled to enabled"
                (Get-Content $configName) -Replace 'stdoutLogEnabled=".*"','stdoutLogEnabled="True"' | Set-Content -Path $configName -Encoding UTF8
                Find-Logging
            }
        }
        else {
            Write-Warning "Something is wrong with finding stdoutLogEnabled in $config"
            Write-Error $Error
        }
    }
}

