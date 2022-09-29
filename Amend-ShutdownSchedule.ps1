<#
.SYNOPSIS
    Enable/Disable the VM-Start-Stop shutdown schedule
.DESCRIPTION
    Powershell script that will Enable or Disable the Azure runbook VM-Start-Stop Shutown schedule
.EXAMPLE
    .\src\Amend-ShutdownSchedule.ps1 -IsEnabled $True
#>

Param (

    [Parameter()]
    [bool]
    $IsEnabled

)
function Login-toAzure {
    param (
        $clientpassword,
        $clientid,
        $azureenvironment,
        $tenantid,
        $subscriptionid
    )
    
    $securePassword = ConvertTo-SecureString $clientpassword -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($clientid, $securePassword)
    $azEnv = if ($azureenvironment) { $azureenvironment } else { "AzureCloud" }

    $azEnv = Get-AzEnvironment -Name $azEnv
    if (!$azEnv) {
        Write-Error "No Azure environment could be matched given the name $($azureenvironment)"
        exit -2
    }

    Write-Verbose "Authenticating with Service Principal"

    Login-AzAccount -Credential $creds -TenantId $tenantid -SubscriptionId $subscriptionid -Environment $azEnv -ServicePrincipal
}

Write-Host "Running on: $env:COMPUTERNAME"

Login-toAzure `
-clientpassword $OctopusParameters["AzAccount.Password"] `
-clientid $OctopusParameters["AzAccount.Client"] `
-azureenvironment $OctopusParameters["AzAccount.AzureEnvironment"] `
-tenantid $OctopusParameters["AzAccount.TenantId"] `
-subscriptionid $OctopusParameters["AzAccount.SubscriptionNumber"]

$AutomationAccountName = (Get-AzAutomationAccount | Where-Object { $PSItem.AutomationAccountName -like '*-Auto' }).AutomationAccountName

if (($AutomationAccountName | Measure-Object).count -gt 1) {
    Write-Warning 'More than one Automation Account found:'
    $AutomationAccountName    
    Write-Warning 'Terminating script.'
    Exit -2    
}
else {
    Write-Host 'One Automation Account found:'
    $Schedule = Get-AzAutomationSchedule -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationAccountName | Where-Object { $PSItem.Name -like '*Stop*' }
    $Schedule.AutomationAccountName
    $Schedule.Name
    Write-Host 'Checking Status:'
    if ($Schedule.IsEnabled -eq $True -and $IsEnabled -eq $False) {
        Write-Host "Schedule is Enabled, Disabling $($Schedule.Name) On Automation Account $AutomationAccountName."
        Set-AzAutomationSchedule -Name $Schedule.Name -IsEnabled $IsEnabled -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationAccountName
    }
    elseif ($Schedule.IsEnabled -eq $False -and $IsEnabled -eq $false) {
        Write-Warning 'Schedule is already disabled.'
        exit -2
    }
    elseif ($Schedule.IsEnabled -eq $True -and $IsEnabled -eq $True) {
        Write-Warning 'Schedule is already enabled.'
        exit -2
    }
    elseif ($Schedule.IsEnabled -eq $False -and $IsEnabled -eq $True) {
        Write-Host "Schedule is Disabled, Enabling $($Schedule.Name) On Automation Account $AutomationAccountName."
        Set-AzAutomationSchedule -Name $Schedule.Name -IsEnabled $IsEnabled -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationAccountName
    }
    else {
        Write-Error 'Parameter value not in expected range'
        exit -2
    }
}
