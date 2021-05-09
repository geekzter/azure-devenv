#!/usr/bin/env pwsh

param ( 
    [parameter(Mandatory=$false,HelpMessage="Wait for encryption to finish")][string]$ResourceGroup,
    [parameter(Mandatory=$false,HelpMessage="Wait for encryption to finish")][switch]$Wait=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

# Get configuration
if (-not $ResourceGroup) {
    $terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
    Push-Location $terraformDirectory
    $ResourceGroup = (Get-TerraformOutput resource_group_name)
    
    if (-not $ResourceGroup) {
        Write-Warning "No resources deployed in workspace $(terraform workspace show), exiting"
        exit
    }
    Pop-Location
}

if ($Wait) {
    do {
        $unencrypted = $(az vm encryption show --ids $(az vm list -g $ResourceGroup --query "[].id" -o tsv) --query "[].disks[].statuses[?code!='EncryptionState/encrypted'] | []"  -o tsv)
        if ($unencrypted) {
            Write-Information "Waiting for disk encruption to finish..." -InformationAction Continue
            Start-Sleep -Seconds 10
        }
    } while ($unencrypted)
}

az vm encryption show --ids $(az vm list -g $ResourceGroup --query "[].id" -o tsv) --query "[].{name:disks[0].name, status:disks[0].statuses[0].displayStatus}" -o table