#!/usr/bin/env pwsh
#requires -Version 7

. (Join-Path $PSScriptRoot functions.ps1)


if (!$IsMacOS) {
    Write-Error "This only runs on MacOS, exiting"
    exit
}

# Get configuration
$terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
Push-Location $terraformDirectory
$certPassword = $(terraform output cert_password      2>$null)
Write-Debug "`$certPassword: $certPassword"
$clientCert   = $(terraform output client_cert        2>$null | Out-String)
Write-Debug "`$clientCert: $clientCert"
$clientKey    = $(terraform output client_key         2>$null | Out-String)
Write-Debug "`$clientKey: $clientKey"
$dnsServer    = $(terraform output dns_server_address 2>$null)
Write-Debug "`$dnsServer: $dnsServer"
$gatewayId    = $(terraform output gateway_id         2>$null)
Write-Debug "`$gatewayId: $gatewayId"
Pop-Location

# Install certificates
Install-Certificates -CertPassword $certPassword

# Download VPN package
AzLogin
if ($gatewayId) {
    $tempPackagePath = (DownloadAndExtract-VPNProfile -GatewayID $gatewayId)

    Update-AzureVPNProfile   -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer
    Update-GenericVPNProfile -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer
    Update-OpenVPNProfile    -PackagePath $tempPackagePath -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer
    # if ($IsMacOS) {
    #     security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $tempPackagePath/VpnServerRoot.cer
    # }

} else {
    Write-Warning "Gateway not found, have you run 'terraform apply' yet?"    
}
Write-Host "Profiles are stored in $tempPackagePath"

# Configure VPN
# AppleScript???
# https://apple.stackexchange.com/questions/128297/how-to-create-a-vpn-connection-via-terminal/228582
# https://docs.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-configuration-azure-cert#installmac
# https://raw.githubusercontent.com/MacMiniVault/Mac-Scripts/master/vpnscript/vpnscript.sh
# strongswan?
# macosvpn?
# https://gist.github.com/iloveitaly/462760
#osascript (Join-Path (Split-Path -parent -Path $MyInvocation.MyCommand.Path) "setup_vpn.applescript")


# Connect VPN
# networksetup -connectpppoeservice "DevelopersInc VPN"


# Mount File share