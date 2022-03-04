#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Provides access to VM's over public IP address, restricted to selected CIDR ranges
 
.DESCRIPTION 
    This script provides "poor man's" just in time access to VM's, directly via their public IP addresses.
    Access to these IP addreses is restricted to selected IP ranges, by default the publix IP address of the location the infrastructure was provisioned from, 
    more can be specified using the Terraform 'admin_ip_ranges' variable.
    You can close ports again by using the -Close switch.

.EXAMPLE
    ./let_me_in.ps1
#> 
param ( 
    [parameter(Mandatory=$false,HelpMessage="Close previously opened ports")][switch]$Close=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

# Get configuration
$terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
Push-Location $terraformDirectory
$resourceGroup = (Get-TerraformOutput resource_group_name)
$keyVault = (Get-TerraformOutput "key_vault_name")

if (-not $resourceGroup) {
    Write-Warning "No resources deployed in workspace $(terraform workspace show), exiting"
    exit
}
Pop-Location

AzLogin -DisplayMessages

# Get public IP address
Write-Verbose "`nRetrieving public IP address..."
$ipAddress = (Invoke-RestMethod -Uri https://ipinfo.io/ip -MaximumRetryCount 9) -replace "\n","" # Ipv4
Write-Host "Public IP address is $ipAddress"

# Retrieve all NSG's
Write-Host "Retrieving network security groups in resource group ${resourceGroup}..."
$nsgs = $(az network nsg list -g $resourceGroup --query "[?!contains(name,'bastion')].name" -o tsv)
$filterAccessBy = $Close ? "Allow" : "Deny"
foreach ($nsg in $nsgs) {
    # Get remote access rules
    $rasRuleQuery = "[?starts_with(name,'AdminRAS') && access=='${filterAccessBy}'].name"
    Write-Verbose "Retrieving remote access rules in network security group ${nsg} ($rasRuleQuery)..."
    Write-Debug "az network nsg rule list --nsg-name $nsg -g $resourceGroup --query `"$rasRuleQuery`" -o tsv"
    $rules = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query "$rasRuleQuery" -o tsv)

    # Toggle access
    $setAccessTo = $Close ? "Deny" : "Allow"
    Write-Host "Updating remote access rules in network security group ${nsg} to set access to '${setAccessTo}'..."
    foreach ($rule in $rules) {
        Write-Verbose "Updating rule ${rule} in ${nsg} to set access to '${setAccessTo}'..."
        az network nsg rule update --nsg-name $nsg -g $resourceGroup --name $rule --access $setAccessTo --query "name" -o tsv
    }

    # Rule may have been removed (e.g. policy), add it back
    if (!$Close) {
        $clientRuleQuery = "[?starts_with(name,'AdminRAS') && sourceAddressPrefixes[0]=='${ipAddress}' && access=='${setAccessTo}'].name"
        if (-not $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query "${clientRuleQuery}" -o tsv)) {
            # Add rule
            $ruleName = "AdminRAS"
            # Determine unique priority
            $maxPriority = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query "max_by([?starts_with(name,'AdminRAS')],&priority).priority" -o tsv)
            Write-Debug "Highest priority # for admin rule is $maxPriority"
            $priority = [math]::max(([int]$maxPriority+1),250) # Use a priority unlikely to be taken by Terraform
            Write-Host "Adding remote access rule ${ruleName} to network security group ${nsg} with access set to '${setAccessTo}'..."
            az network nsg rule create -n $ruleName --nsg-name $nsg -g $resourceGroup --priority $priority --access $setAccessTo --direction Inbound --protocol TCP --source-address-prefixes $ipAddress --destination-address-prefixes 'VirtualNetwork' --destination-port-ranges 22 3389 --query "name" -o tsv
        }
    }
}

# Update Key Vault firewall
if ($keyVault) {    
    $existingRule = $(az keyvault network-rule list -g $resourceGroup -n $keyVault --query "ipRules[?starts_with(value,'${ipAddress}')]" -o tsv)

    if ((!$Close) -and (!$existingRule)) {
        Write-Host "Adding rule for Key Vault $keyVault to allow $ipAddress..."
        az keyvault network-rule add -g $resourceGroup -n $keyVault --ip-address $ipAddress -o none
    }
    if ($Close -and $existingRule) {
        Write-Host "Removing rule for Key Vault $keyVault to allow $ipAddress..."
        az keyvault network-rule remove -g $resourceGroup -n $keyVault --ip-address "${ipAddress}/32" -o none
    }    
} else {
    Write-Host "Key Vault not found"
}