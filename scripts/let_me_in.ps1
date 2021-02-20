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
Pop-Location

# Retrieve all NSG's
Write-Host "Retrieving network security groups in resource group ${resourceGroup}..."
$nsgs = $(az network nsg list -g $resourceGroup --query "[*].name" -o tsv)
foreach ($nsg in $nsgs) {
    # Get remote access rules
    $filterAccessBy = $Close ? "Allow" : "Deny"
    $rasRuleQuery = "[?(starts_with(name,'InboundRDP') || starts_with(name,'InboundSSH')) && access=='${filterAccessBy}'].name"
    Write-Information "Retrieving remote access rules in network security group ${nsg} ($rasRuleQuery)..."
    $rules = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query $rasRuleQuery -o tsv)

    # Toggle access
    $setAccessTo = $Close ? "Deny" : "Allow"
    Write-Host "Updating remote access rules in network security group ${nsg} to set access to '${setAccessTo}'..."
    foreach ($rule in $rules) {
        Write-Information "Updating rule ${rule} in ${nsg} to set access to '${setAccessTo}'..."
        az network nsg rule update --nsg-name $nsg -g $resourceGroup --name $rule --access $setAccessTo --query "name" -o tsv
    }
}