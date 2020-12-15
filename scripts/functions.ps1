$rootCertificateCommonName = "P2SRootCert"
$clientCertificateCommonName = "P2SChildCert"

function AzLogin (
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
) {
    # Azure CLI
    Invoke-Command -ScriptBlock {
        $private:ErrorActionPreference = "Continue"
        # Test whether we are logged in
        $script:loginError = $(az account show -o none 2>&1)
        if (!$loginError) {
            $script:userType = $(az account show --query "user.type" -o tsv)
            if ($userType -ieq "user") {
                # Test whether credentials have expired
                $Script:userError = $(az ad signed-in-user show -o none 2>&1)
            } 
        }
    }
    if ($loginError -or $userError) {
        az login -o none
    }
}

function DownloadAndExtract-VPNProfile (
    [parameter(Mandatory=$true)][string]$GatewayID
) {
    Write-Host "Generating VPN profiles..."
    $vpnPackageUrl = $(az network vnet-gateway vpn-client generate --ids $gatewayId --authentication-method EAPTLS -o tsv)

    # Download VPN Profile
    Write-Host "Downloading VPN profiles..."
    $packageFile = New-TemporaryFile
    Invoke-WebRequest -UseBasicParsing -Uri $vpnPackageUrl -OutFile $packageFile

    $tempPackagePath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    $null = New-Item -ItemType "directory" -Path $tempPackagePath
    # Extract package archive
    Expand-Archive -Path $packageFile -DestinationPath $tempPackagePath
    Write-Verbose "Package extracted at $tempPackagePath"

    return $tempPackagePath
}

function Get-CertificatesDirectory() {
    $certificateDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) "certificates")
    if (!(Test-Path $certificateDirectory)) {
        $null = New-Item -ItemType Directory -Force -Path $certificateDirectory 
    }

    return $certificateDirectory
}

function Install-Certificates() {
    if ($IsMacOS) {
        Install-CertificatesMacOS
        return
    }
    throw "OS not supported"
}

function Install-CertificatesMacOS() {
    $certificateDirectory = Get-CertificatesDirectory

    # Install certificates
    #security unlock-keychain ~/Library/Keychains/login.keychain
    if (Test-Path $certificateDirectory/root_cert_public.pem) {
        if (security find-certificate -c $rootCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $rootCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing $certificateDirectory/root_cert_public.pem? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipRootCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipRootCertImport) {
            Write-Host "Importing root certificate $certificateDirectory/root_cert_public.pem..."
            security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $certificateDirectory/root_cert_public.pem
        }
    } else {
        Write-Host "Certificate $certificateDirectory/root_cert_public.pem does not exist, have you run 'terraform apply' yet?"
        return
    }
    if (Test-Path $certificateDirectory/client_cert.p12) {
        if (security find-certificate -c $clientCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $clientCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing $certificateDirectory/client_cert.p12? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipClientCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipClientCertImport) {
            Write-Host "Importing client certificate $certificateDirectory/client_cert.p12..."
            security import $certificateDirectory/client_cert.p12 -P $certPassword
        }
    } else {
        Write-Host "Certificate $certificateDirectory/client_cert.p12 does not exist, have you run 'terraform apply' yet?"
        return
    }
}

function Update-AzureVPNProfile (
    [parameter(Mandatory=$true)][string]$ProfileFileName,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    if (!(Test-Path $ProfileFileName)) {
        Write-Warning "$ProfileFileName not found"
        return
    }

    Write-Verbose "Azure VPN Profile ${ProfileFileName}"

    # TODO: Add client secrets

    # Edit VPN Profile
    Write-Host "Modifying VPN profile DNS configuration..."
    $vpnProfileXml = [xml](Get-Content $ProfileFileName)
    $clientconfig = $vpnProfileXml.SelectSingleNode("//*[name()='clientconfig']")
    $dnsserversNode = $vpnProfileXml.CreateElement("dnsservers", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode = $vpnProfileXml.CreateElement("dnsserver", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode.InnerText = $dnsServer
    $dnsserversNode.AppendChild($dnsserverNode) | Out-Null
    $clientconfig.AppendChild($dnsserversNode) | Out-Null
    $clientconfig.RemoveAttribute("nil","http://www.w3.org/2001/XMLSchema-instance")
    $vpnProfileXml.Save($ProfileFileName)
}

function Update-GenericVPNProfile (
    [parameter(Mandatory=$true)][string]$ProfileFileName,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    if (!(Test-Path $ProfileFileName)) {
        Write-Warning "$ProfileFileName not found"
        return
    }

    Write-Verbose "Generic Profile is ${ProfileFileName}"

    # Locate VPN Server setting
    $genericProfileXml = [xml](Get-Content $ProfileFileName)
    $dnsServersNode = $genericProfileXml.SelectSingleNode("//*[name()='CustomDnsServers']")
    $dnsServersNode.InnerText = $dnsServer
    $genericProfileXml.Save($ProfileFileName)
}

function Update-OpenVPNProfile (
    [parameter(Mandatory=$true)][string]$ProfileFileName,
    [parameter(Mandatory=$true)][string]$ClientCert,
    [parameter(Mandatory=$true)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    if (!(Test-Path $ProfileFileName)) {
        Write-Warning "$ProfileFileName not found"
        return
    }

    Write-Verbose "OpenVPN Profile is ${ProfileFileName}"


    (Get-Content $ProfileFileName) -replace '\$CLIENTCERTIFICATE',($ClientCert -replace "$","`n") | Out-File $ProfileFileName
    (Get-Content $ProfileFileName) -replace '\$PRIVATEKEY',($ClientKey -replace "$","`n")         | Out-File $openVPNProfileFile

    # Add DNS
    Write-Output "`ndhcp-option DNS ${DnsServer}`n" | Out-File $ProfileFileName -Append

    Write-Verbose "OpenVPN Profile:`n$(Get-Content $ProfileFileName -Raw)"
}