#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Use this to connect to a Linux host
    
    This file is generated by Terraform
    https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
    https://www.terraform.io/language/functions/templatefile
#> 
param ( 
    [parameter(Mandatory=$false)]
    [validateset("Bastion", "PrivateHostname", "PrivateIP", "PublicHostname", "PublicIP")]
    [string]
    $Endpoint

    # TODO: location
) 

function Connect-Rdp(
    [parameter(Mandatory=$true)][string]$UserName,
    [parameter(Mandatory=$true)][string]$HostName
) {
    if ($IsWindows) {
        mstsc.exe /v:$HostName /f
    }
    if ($IsMacOS) {
        "rdp://{0}{1}@{0}{2}" -f "`$", $UserName, $HostName | Set-Variable rdpUrl
        Write-Verbose "Opening $rdpUrl"
        open $rdpUrl
    }
}

if (!$Endpoint) {
    $defaultChoice = 0
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Bastion")
        [System.Management.Automation.Host.ChoiceDescription]::new("PrivateHost&name")
        [System.Management.Automation.Host.ChoiceDescription]::new("&PrivateIP")
        [System.Management.Automation.Host.ChoiceDescription]::new("Public&Hostname")
        [System.Management.Automation.Host.ChoiceDescription]::new("Public&IP")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Exit", "Abort operation")
    )
    $decision = $Host.UI.PromptForChoice("Connect", "How do you want to connect to the Windows VM?", $choices, $defaultChoice)
    Write-Host $choices[$decision].HelpMessage
    $choices[$decision].Label -replace "&", "" | Set-Variable Endpoint
}

# $vmProperties = @{
# { for location, vm_id in virtual_machine_ids }
#     {location} = "{vm_id}"
# { endfor ~}
# }

switch ($Endpoint)
{
    "Bastion" {
        # Log into Azure CLI
        $account = $null
        az account show 2>$null | ConvertFrom-Json | Set-Variable account
        if (-not $account) {
            if ($env:CODESPACES -ieq "true") {
                $azLoginSwitches = "--use-device-code"
            }
            if ($env:ARM_TENANT_ID) {
                az login -t $env:ARM_TENANT_ID -o none $($azLoginSwitches)
            } else {
                az login -o none $($azLoginSwitches)
            }
        }
        az network bastion rdp --ids "${bastion_id}" `
                               --resource-group "${resource_group_name}" `
                               --target-resource-id "${vm_id}"
    }
    "PrivateIP" {
        Connect-Rdp -UserName "${user_name}" -HostName "${private_ip_address}"
    }
    "PrivateHostname" {
        Connect-Rdp -UserName "${user_name}" -HostName "${private_fqdn}"
    }
    "PublicIP" {
        Connect-Rdp -UserName "${user_name}" -HostName "${public_ip_address}"
    }
    "PublicHostname" {
        Connect-Rdp -UserName "${user_name}" -HostName "${public_fqdn}"
    }
}
