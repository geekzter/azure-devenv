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
Write-Verbose "`$certPassword: $certPassword"
$clientCert   = $(terraform output client_cert        2>$null | Out-String)
Write-Verbose "`$clientCert: $clientCert"
$clientKey    = $(terraform output client_key         2>$null | Out-String)
Write-Verbose "`$clientKey: $clientKey"
$dnsServer    = $(terraform output dns_server_address 2>$null)
Write-Verbose "`$dnsServer: $dnsServer"
$gatewayId    = $(terraform output gateway_id         2>$null)
Write-Verbose "`$gatewayId: $gatewayId"
Pop-Location


# Download VPN package
AzLogin
if ($gatewayId) {
    $tempPackagePath = (DownloadAndExtract-VPNProfile -GatewayID $gatewayId)

    # Azure VPN
    $azureVPNProfileFile = Join-Path $tempPackagePath AzureVPN azurevpnconfig.xml
    Update-AzureVPNProfile -ProfileFileName $azureVPNProfileFile -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer

    # IKEv2
    $genericProfileFile = Join-Path $tempPackagePath Generic VpnSettings.xml
    Update-GenericVPNProfile -ProfileFileName $genericProfileFile -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer

    # OpenVPN
    $openVPNProfileFile = Join-Path $tempPackagePath OpenVPN vpnconfig.ovpn
    Update-OpenVPNProfile -ProfileFileName $openVPNProfileFile -ClientCert $clientCert -ClientKey $clientKey -DnsServer $dnsServer

} else {
    Write-Warning "Gateway not found, have you run 'terraform apply' yet?"    
}

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