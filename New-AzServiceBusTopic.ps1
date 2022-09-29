<#
.SYNOPSIS
    Creates a topic for an Azure Service bus Namespace
.DESCRIPTION
    Creates a topic for an Azure Service bus Namespace
    If debug is set to true will run it with -whatif enabled and verbose logging
    To run this from your local machine set the -local $True

.EXAMPLE
    .\src\New-AzServiceBusTopic.ps1 -resourcegroup "Development-DV01" -namespacename "ct-servicebus-eltft3" -topicname "MattTest" -partitioning $true -debugmode $true -local $true
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
    [Boolean]
    $partitioning,

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

function New-SBTopic {
    param (
        $topicname,
        $namespacename,
        $resourcegroup,
        $partitioning
    )
    
    try {
        Write-Verbose "Adding new Topic: $topicname for existing Namespace: $namespacename"
        New-AzServiceBusTopic -ResourceGroupName "$resourcegroup" -NamespaceName "$namespacename" -TopicName "$topicname" -EnablePartitioning $partitioning
    }
    catch {
        Write-Error $error[0].Exception
    }
}

Write-Verbose "Printing out variables"
Write-Verbose "Resourcegroup: $resourcegroup"
Write-Verbose "Topicname: $topicname"
Write-Verbose "Namespacename: $namespacename"
Write-Verbose "Partitioning: $partitioning"
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

$namespace_exists = Get-AzServiceBusNamespace -ResourceGroupName "$resourcegroup" -NamespaceName $namespacename -ErrorAction SilentlyContinue
if($namespace_exists) {
    $topic_exists = Get-AzServiceBusTopic -TopicName "$topicname" -Namespace "$namespacename"  -ResourceGroupName "$resourcegroup" -ErrorAction SilentlyContinue
    if ($topic_exists) {
        write-host "Topic Already Exists: $topicname"
        write-verbose $topic_exists.Name    
    }
    else {
        New-SBTopic -resourcegroup "$resourcegroup" -namespacename "$namespacename" -topicname "$topicname" -partitioning $partitioning
    }
}
else {
    Write-Error "$namespacename doesn't exist in resource group: $resourcegroup"
}
