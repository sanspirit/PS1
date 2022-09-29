<#
.SYNOPSIS
    Creates a subscription for a topic for an Azure Service bus Namespace
.DESCRIPTION
    Creates a subscription for a topic for an Azure Service bus Namespace
    If debug is set to true will run it with -whatif enabled and verbose logging
    To run this from your local machine set the -local $True

.EXAMPLE
    .\src\New-AzServiceBusSubscription.ps1 -resourcegroup "Development-DV01" -namespacename "ct-servicebus-eltft" -topicname "MattTest" -subscriptionname "MattTest" -debugmode $true -local $true
#>
[CmdletBinding()]
Param (

    [Parameter(Mandatory = $True)]
    [string]
    $resourcegroup,

    [Parameter(Mandatory = $True)]
    [string]
    $namespacename,

    [Parameter(Mandatory = $True)]
    [string]
    $topicname,

    [Parameter(Mandatory = $True)]
    [string]
    $subscriptionname,

    [Parameter(Mandatory = $True)]
    [Boolean]
    $debugmode,

    [Parameter(Mandatory = $False)]
    [Boolean]
    $local = $False
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
    Write-Verbose "Printing out login variables"
    Write-Verbose "Clientid: $clientid"
    Write-Verbose "Azureenvironment: $azureenvironment"
    Write-Verbose "Tenantid: $tenantid"
    Write-Verbose "Subscriptionid: $subscriptionid"
    Write-Verbose "Authenticating with Service Principal"

    Login-AzAccount -Credential $creds -TenantId $tenantid -SubscriptionId $subscriptionid -Environment $azEnv -ServicePrincipal
}

function New-SBSubscription {
    param (
        $topicname,
        $namespacename,
        $resourcegroup,
        $subscriptionname,
        $debugMode
    )
    
    try {
        Write-Verbose "Adding new Subscription: $subscriptionname for existing Topic: $topicname"
        New-AzServiceBusSubscription -ResourceGroupName "$resourcegroup" -NamespaceName "$namespacename" -TopicName "$topicname" -SubscriptionName $subscriptionname
    }
    catch {
        Write-Error $error[0].Exception
    }
}

Write-Verbose "Printing out variables"
Write-Verbose "Resourcegroup: $resourcegroup"
Write-Verbose "Topicname: $topicname"
Write-Verbose "Namespacename: $namespacename"
Write-Verbose "Subscriptionname: $subscriptionname"
Write-Verbose "DebugMode: $debugMode"

Write-Verbose "Running on: $env:COMPUTERNAME"

if($local -eq $False) {
    Login-toAzure `
    -clientpassword $OctopusParameters["AzAccount.Password"] `
    -clientid $OctopusParameters["AzAccount.Client"] `
    -azureenvironment $OctopusParameters["AzAccount.AzureEnvironment"] `
    -tenantid $OctopusParameters["AzAccount.TenantId"] `
    -subscriptionid $OctopusParameters["AzAccount.SubscriptionNumber"]
}

if($debugMode -eq $True) {
    $WhatIfPreference = $True
    $VerbosePreference = "Continue"
}

$topic_exists = Get-AzServiceBusTopic -TopicName "$topicname" -Namespace "$namespacename"  -ResourceGroupName "$resourcegroup" -ErrorAction SilentlyContinue

if ($topic_exists) {
    write-host "Topic already exists: $topicname"
    write-verbose $topic_exists.Name
    $sub_exists = Get-AzServiceBusSubscription -ResourceGroupName $resourcegroup -NamespaceName $namespacename -TopicName $topicname -SubscriptionName $subscriptionname -ErrorAction SilentlyContinue
    if ($sub_exists) {
        write-host "Subscription already exists: $subscriptionname"
        write-verbose $sub_exists.Name
    }
    else{
        New-SBSubscription -resourcegroup "$resourcegroup" -namespacename "$namespacename" -topicname "$topicname" -subscriptionname $subscriptionname
    }
}
else {
    Write-Error "$topicname doesn't exist in namespace: $namespacename in resource group: $resourcegroup"
}
