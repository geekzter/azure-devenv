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

    # TODO: Windows
) 

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
    $decision = $Host.UI.PromptForChoice("Connect", "How do you want to connect to the Linux VM?", $choices, $defaultChoice)
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
        az network bastion ssh --ids "${bastion_id}" `
                               --resource-group "${resource_group_name}" `
                               --target-resource-id "${vm_id}" `
                               --auth-type "ssh-key" `
                               --username "${user_name}" `
                               --ssh-key ${ssh_private_key}
    }
    "PrivateIP" {
        ssh -i ${ssh_private_key} ${user_name}@${private_ip_address}
    }
    "PrivateHostname" {
        ssh -i ${ssh_private_key} ${user_name}@${private_fqdn}
    }
    "PublicIP" {
        ssh -i ${ssh_private_key} ${user_name}@${public_ip_address}
    }
    "PublicHostname" {
        ssh -i ${ssh_private_key} ${user_name}@${public_fqdn}
    }
}
