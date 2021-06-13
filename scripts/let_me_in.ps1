#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Provides access to VM's over public IP address, restricted to selected CIDR ranges
 
.DESCRIPTION 
    This script provides "poor man's" just in time access to VM's, directly via their public IP addresses.
    Access to these IP addreses is restricted to selected IP ranges, by default the publix prefix of the location the infrastructure was provisioned from, 
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

if (-not $resourceGroup) {
    Write-Warning "No resources deployed in workspace $(terraform workspace show), exiting"
    exit
}
Pop-Location

# Get public IP address
Write-Information "`nRetrieving public IP address..."
$ipAddress = (Invoke-RestMethod -Uri https://ipinfo.io/ip -MaximumRetryCount 9) -replace "\n","" # Ipv4
Write-Host "Public IP address is $ipAddress"

# Get block(s) the public IP address belongs to
$ipPrefix = (Invoke-RestMethod -Uri https://stat.ripe.net/data/network-info/data.json?resource=${ipAddress} -MaximumRetryCount 9 | Select-Object -ExpandProperty data | Select-Object -ExpandProperty prefix)
Write-Host "Public IP prefix is $ipPrefix"

# Retrieve all NSG's
Write-Host "Retrieving network security groups in resource group ${resourceGroup}..."
$nsgs = $(az network nsg list -g $resourceGroup --query "[*].name" -o tsv)
foreach ($nsg in $nsgs) {
    $applicationProtocol = $nsg -match "windows" ? "RDP" : "SSH"
    $applicationPort     = $nsg -match "windows" ? 3389 : 22

    # Get remote access rules
    $filterAccessBy = $Close ? "Allow" : "Deny"
    $rasRuleQuery = "[?(starts_with(name,'AdminRDP') || starts_with(name,'AdminSSH')) && access=='${filterAccessBy}'].name"
    Write-Information "Retrieving remote access rules in network security group ${nsg} ($rasRuleQuery)..."
    $rules = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query $rasRuleQuery -o tsv)

    # Toggle access
    $setAccessTo = $Close ? "Deny" : "Allow"
    Write-Host "Updating remote access rules in network security group ${nsg} to set access to '${setAccessTo}'..."
    foreach ($rule in $rules) {
        Write-Information "Updating rule ${rule} in ${nsg} to set access to '${setAccessTo}'..."
        az network nsg rule update --nsg-name $nsg -g $resourceGroup --name $rule --access $setAccessTo --query "name" -o tsv
    }

    # Current prefix needs access, check whether rule exists
    if (!$Close) {
        $clientRuleQuery = "[?(starts_with(name,'AdminRDP') || starts_with(name,'AdminSSH')) && sourceAddressPrefix=='${ipPrefix}' && access=='${setAccessTo}'].name"
        if (-not $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query $clientRuleQuery -o tsv)) {
            # Add rule for current prefix
            $ruleName = "Admin${applicationProtocol}"
            # Determine unique priority
            $maxPriority = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query "max_by([?(starts_with(name,'AdminRDP') || starts_with(name,'AdminSSH'))],&priority).priority" -o tsv)
            Write-Debug "Highest priority # for admin rule is $maxPriority"
            $priority = [math]::max(([int]$maxPriority+1),250) # Use a priority unlikely to be taken by Terraform
            Write-Host "Adding remote access rule ${ruleName} to network security group ${nsg} with access set to '${setAccessTo}'..."
            az network nsg rule create -n $ruleName --nsg-name $nsg -g $resourceGroup --priority $priority --access $setAccessTo --direction Inbound --protocol TCP --source-address-prefixes $ipPrefix --destination-address-prefixes '*' --destination-port-ranges $applicationPort --query "name" -o tsv
        }
    }
}

# Update Key Vault firewall
$keyVault = (Get-TerraformOutput "key_vault_name")
if ($keyVault) {
    $ipAddress=$(Invoke-RestMethod -Uri https://ipinfo.io/ip -MaximumRetryCount 9).Trim()
    Write-Information "Public IP address is $ipAddress"
    # Get block(s) the public IP address belongs to
    # HACK: We need this to cater for changing public IP addresses e.g. Azure Pipelines Hosted Agents
    $ipPrefix = (Invoke-RestMethod -Uri https://stat.ripe.net/data/network-info/data.json?resource=${ipAddress} -MaximumRetryCount 9 | Select-Object -ExpandProperty data | Select-Object -ExpandProperty prefix)
    Write-Information "Public IP prefix is $ipPrefix"

    Write-Host "Adding rule for Key Vault $keyVault to allow prefix $ipPrefix..."
    az keyvault network-rule add -g $resourceGroup -n $keyVault --ip-address $ipPrefix -o none
}