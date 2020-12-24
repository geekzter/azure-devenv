#!/usr/bin/env pwsh
#requires -Version 7

. (Join-Path $PSScriptRoot functions.ps1)

# Get configuration
$terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
Push-Location $terraformDirectory
$certPassword  = (Get-TerraformOutput cert_password)
$clientCert    = (Get-TerraformOutput client_cert_public_pem | Out-String)
$clientKey     = (Get-TerraformOutput client_cert_private_pem | Out-String)
$dnsServer     = (Get-TerraformOutput dns_server_address)
$gatewayId     = (Get-TerraformOutput gateway_id)
$resourceGroup = (Get-TerraformOutput resource_group_name)
Pop-Location

# Install certificates
Install-Certificates -CertPassword $certPassword

# Download VPN package
AzLogin
if ($gatewayId) {
    $tempPackagePath = (DownloadAndExtract-VPNProfile -GatewayID $gatewayId)
    Write-Host "Profiles are stored in $tempPackagePath"
    # if ($IsMacOS) {
    #     security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $tempPackagePath/VpnServerRoot.cer
    # }

    Update-AzureVPNProfile   -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer -ProfileName $resourceGroup -Install
    Update-GenericVPNProfile -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer
    Update-OpenVPNProfile    -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer

    if ($InformationPreference -ieq "Continue") {
        Write-Information "DNS Configuration:"
        if ($IsMacOS) {
            scutil --dns
        }
        if ($IsWindows) {
            Get-DnsClientNrptPolicy
        }
    }

} else {
    Write-Warning "Gateway not found, have you run 'terraform apply' yet?"    
}
