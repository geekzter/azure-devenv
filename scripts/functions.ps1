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
    $directory = (Join-Path (Split-Path $PSScriptRoot -Parent) "data" (Get-TerraformWorkspace) "certificates")
    if (!(Test-Path $directory)) {
        $null = New-Item -ItemType Directory -Force -Path $directory 
    }

    return $directory
}

function Get-TerraformDirectory {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) "terraform")
}

function Get-TerraformOutput (
    [parameter(Mandatory=$true)][string]$OutputVariable
) {
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "SilentlyContinue"
        Write-Verbose "terraform output ${OutputVariable}: evaluating..."
        $result = $(terraform output $OutputVariable 2>$null)
        $result = (($result -replace '^"','') -replace '"$','') # Remove surrounding quotes (Terraform 0.14)
        if ($result -match "\[\d+m") {
            # Terraform warning, return null for missing output
            Write-Verbose "terraform output ${OutputVariable}: `$null (${result})"
            return $null
        } else {
            Write-Verbose "terraform output ${OutputVariable}: ${result}"
            return $result
        }
    }
}

function Get-TerraformWorkspace () {
    Push-Location (Get-TerraformDirectory)
    try {
        return $(terraform workspace show)
    } finally {
        Pop-Location
    }
}

function Install-Certificates(
    [parameter(Mandatory=$true)][string]$CertPassword
) {
    Push-Location (Get-TerraformDirectory)
    $clientCertificateCommonName = (Get-TerraformOutput "client_cert_common_name")
    $clientCertMergedPEMFile = (Get-TerraformOutput "client_cert_merged_pem_file")
    $rootCertificateCommonName = (Get-TerraformOutput "root_cert_common_name")
    $rootCertPublicPEMFile = (Get-TerraformOutput "root_cert_pem_file")
    Pop-Location

    if ($IsMacOS) {
        Install-CertificatesMacOS   -CertPassword $CertPassword `
                                    -ClientCertificateCommonName $clientCertificateCommonName `
                                    -ClientCertMergedPEMFile $clientCertMergedPEMFile `
                                    -RootCertificateCommonName $rootCertificateCommonName `
                                    -RootCertPublicPEMFile $rootCertPublicPEMFile
        return
    }
    if ($IsWindows) {
        Install-CertificatesWindows -CertPassword $CertPassword `
                                    -ClientCertificateCommonName $clientCertificateCommonName `
                                    -ClientCertMergedPEMFile $clientCertMergedPEMFile `
                                    -RootCertificateCommonName $rootCertificateCommonName `
                                    -RootCertPublicPEMFile $rootCertPublicPEMFile
        return
    }
    Write-Error "Skipping certificate import on $($PSversionTable.OS)"
}

function Install-CertificatesMacOS (
    [parameter(Mandatory=$true)][string]$CertPassword,
    [parameter(Mandatory=$true)][string]$ClientCertificateCommonName,
    [parameter(Mandatory=$true)][string]$ClientCertMergedPEMFile,
    [parameter(Mandatory=$true)][string]$RootCertificateCommonName,
    [parameter(Mandatory=$true)][string]$RootCertPublicPEMFile
) {
    # Install certificates
    #security unlock-keychain ~/Library/Keychains/login.keychain
    if (Test-Path $RootCertPublicPEMFile) {
        if (security find-certificate -c $RootCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $RootCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing ${RootCertPublicPEMFile}? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipRootCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipRootCertImport) {
            Write-Host "Importing root certificate ${RootCertPublicPEMFile}..."
            security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $RootCertPublicPEMFile
        }
    } else {
        Write-Host "Certificate $RootCertPublicPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
    if (Test-Path $ClientCertMergedPEMFile) {
        if (security find-certificate -c $ClientCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $ClientCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing ${ClientCertMergedPEMFile}? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipClientCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipClientCertImport) {
            Write-Host "Importing client certificate ${ClientCertMergedPEMFile}..."
            # security import $certificateDirectory/client_cert.p12 -P $certPassword
            security import $ClientCertMergedPEMFile -P $certPassword
        }
    } else {
        Write-Host "Certificate $ClientCertMergedPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
}

function Install-CertificatesWindows (
    [parameter(Mandatory=$true)][string]$CertPassword,
    [parameter(Mandatory=$true)][string]$ClientCertificateCommonName,
    [parameter(Mandatory=$true)][string]$ClientCertMergedPEMFile,
    [parameter(Mandatory=$true)][string]$RootCertificateCommonName,
    [parameter(Mandatory=$true)][string]$RootCertPublicPEMFile
) {
    if (!(Get-Command certutil -ErrorAction SilentlyContinue)) {
        Write-Warning "certutil not found, skipping certificate import"
        return
    }
    # Install certificates
    if (Test-Path $RootCertPublicPEMFile) {
        Write-Host "Importing root certificate ${RootCertPublicPEMFile}..."
        certutil -f -user -addstore "My" $RootCertPublicPEMFile
    } else {
        Write-Host "Certificate $RootCertPublicPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
    if (Test-Path $ClientCertMergedPEMFile) {
        $clientCertMergedPFXFile = ($ClientCertMergedPEMFile -replace ".pem", ".pfx")
        # certutil -mergepfx -p "tmpew,tmpew" .\tmproot.pem .\tmproot.pfx
        Write-Verbose "Creating ${clientCertMergedPFXFile} from ${ClientCertMergedPEMFile}..."
        certutil -f -user -mergepfx -p "${CertPassword},${CertPassword}" $ClientCertMergedPEMFile $clientCertMergedPFXFile
        Write-Host "Importing ${clientCertMergedPFXFile}..."
        certutil -f -user -importpfx -p $CertPassword "My" $clientCertMergedPFXFile
    } else {
        Write-Host "Certificate $ClientCertMergedPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
}

function Update-AzureVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer,
    [parameter(Mandatory=$true)][string]$ProfileName
) {
    $profileFileName = Join-Path $PackagePath AzureVPN azurevpnconfig.xml
    if (!(Test-Path $profileFileName)) {
        Write-Error "$ProfileFileName not found"
        return
    }
    Write-Verbose "Azure VPN Profile ${ProfileFileName}"

    # Edit VPN Profile
    Write-Host "Modifying VPN profile DNS configuration..."
    $vpnProfileXml = [xml](Get-Content $profileFileName)
    $clientconfig = $vpnProfileXml.SelectSingleNode("//*[name()='clientconfig']")
    $dnsserversNode = $vpnProfileXml.CreateElement("dnsservers", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode = $vpnProfileXml.CreateElement("dnsserver", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode.InnerText = $dnsServer
    $dnsserversNode.AppendChild($dnsserverNode) | Out-Null
    $clientconfig.AppendChild($dnsserversNode) | Out-Null
    $clientconfig.RemoveAttribute("nil","http://www.w3.org/2001/XMLSchema-instance")

    Copy-Item $profileFileName "${profileFileName}.backup"
    $vpnProfileXml.Save($profileFileName)

    if (Get-Command azurevpn -ErrorAction SilentlyContinue) {
        $vpnProfileFile = (Join-Path $env:userprofile\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState "${ProfileName}.xml")
        Copy-Item $profileFileName $vpnProfileFile
        Write-Host "Azure VPN app importing profile '$vpnProfileFile'..."
        azurevpn -f -i (Split-Path $vpnProfileFile -Leaf)
    } else {
        Write-Host "Use the Azure VPN app (https://go.microsoft.com/fwlink/?linkid=2117554) to import this profile:`n${profileFileName}"
    }
}

function Update-GenericVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    $profileFileName = Join-Path $PackagePath Generic VpnSettings.xml
    if (!(Test-Path $profileFileName)) {
        Write-Error "$profileFileName not found"
        return
    }
    Write-Verbose "Generic Profile is ${ProfileFileName}"

    $genericProfileXml = [xml](Get-Content $profileFileName)

    # Locate DNS Server setting
    $dnsServersNode = $genericProfileXml.SelectSingleNode("//*[name()='CustomDnsServers']")
    $dnsServersNode.InnerText = $dnsServer

    # Locate VPN Server setting
    $vpnServersNode = $genericProfileXml.SelectSingleNode("//*[name()='VpnServer']")
    Write-Host "VPN Server is $($vpnServersNode.InnerText)"

    Copy-Item $profileFileName "${profileFileName}.backup"
    $genericProfileXml.Save($profileFileName)
}

function Update-OpenVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$true)][string]$ClientCert,
    [parameter(Mandatory=$true)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    $profileFileName = Join-Path $tempPackagePath OpenVPN vpnconfig.ovpn
    if (!(Test-Path $profileFileName)) {
        Write-Error "$profileFileName not found"
        return
    }
    Write-Verbose "OpenVPN Profile is ${profileFileName}"
    Copy-Item $ProfileFileName "${profileFileName}.backup"

    (Get-Content $profileFileName) -replace '\$CLIENTCERTIFICATE',($ClientCert -replace "$","`n") | Out-File $profileFileName
    (Get-Content $profileFileName) -replace '\$PRIVATEKEY',($ClientKey -replace "$","`n")         | Out-File $profileFileName

    # Add DNS
    Write-Output "`ndhcp-option DNS ${DnsServer}`n" | Out-File $profileFileName -Append

    Write-Debug "OpenVPN Profile:`n$(Get-Content $profileFileName -Raw)"
}