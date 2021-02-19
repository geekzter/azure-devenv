#!/usr/bin/env pwsh

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
    Write-Information "Retrieving remote access rules in network security group ${nsg}..."
    $rules = $(az network nsg rule list --nsg-name $nsg -g $resourceGroup --query "[?(starts_with(name,'InboundRDP') || starts_with(name,'InboundSSH')) && access=='Deny'].name" -o tsv)

    # Enable access
    Write-Host "Updating remote access rules in network security group ${nsg}..."
    foreach ($rule in $rules) {
        Write-Information "Updating rule ${rule} in ${nsg}..."
        az network nsg rule update --nsg-name $nsg -g $resourceGroup --name $rule --access Allow --query "name" -o tsv
    }
}