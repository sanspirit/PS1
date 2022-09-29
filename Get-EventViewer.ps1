<#
.SYNOPSIS
    Lists the last 50 events in event viewer that are marked as errors, warnings and information.
.DESCRIPTION
    Powershell script that lists the last 50 events in event viewer that are marked as errors, warnings and information.
.EXAMPLE
    \src\Get-EventViewer.ps1
#>

try {
    write-host 'Errors'
    Get-EventLog -LogName Application -Newest 50 -EntryType Error | Format-List

    write-host 'Warning'
    Get-EventLog -LogName Application -Newest 50 -EntryType Information | Format-List

    write-host 'Information'
    Get-EventLog -LogName Application -Newest 50 -EntryType Warning | Format-List
}
catch {
    Write-Error "There was an issue getting the event viewer logs."
    Write-Error $Error
}
