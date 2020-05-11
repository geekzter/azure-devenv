<# 
.SYNOPSIS 
    Script used to bootstrap Management server
 
.DESCRIPTION 
    This script is downloaded and executed during first logon

.EXAMPLE
    cmd.exe /c start PowerShell.exe -ExecutionPolicy Bypass -Noexit -Command "&amp; {Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('${scripturl}'))}"
#> 

$config = (Get-Content $env:SystemDrive\AzureData\CustomData.bin | ConvertFrom-Json)

# Capture bootstrap command as script
$localBatchScript = "$env:PUBLIC\setup.cmd"
Write-Output "PowerShell.exe -ExecutionPolicy Bypass -Noexit -Command `"`& {$($MyInvocation.MyCommand.Definition)}`"" | Out-File -FilePath $localBatchScript -Encoding OEM

# Schedule bootstrap command to run on every logon
schtasks.exe /create /f /sc onlogon /tn "Bootstrap" /tr $localBatchScript
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 99

# Download PowerShell script
$localPSScript = "$env:PUBLIC\setup.ps1"
if ($config.scripturl) {
    Invoke-WebRequest -UseBasicParsing -Uri $config.scripturl -OutFile $localPSScript
}

# Create shortcut
$wsh = New-Object -ComObject WScript.Shell
$bootstrapShortcut = $wsh.CreateShortcut("$($env:USERPROFILE)\Desktop\Setup.lnk")
$bootstrapShortcut.TargetPath = $localBatchScript
$bootstrapShortcut.Save()

# Create Private DNS demo script
$lookupScript = "$env:USERPROFILE\Desktop\privatelink_lookup.cmd"
if ($config -and $config.privatelinkfqdns) {
    $privateLinkFQDNs = $config.privatelinkfqdns.Split(",")
    Write-Output "echo Private DNS resolved PaaS FQDNs:" | Out-File $lookupScript -Force -Encoding OEM
    foreach ($privateLinkFQDN in $privateLinkFQDNs) {
        Write-Output "nslookup $privateLinkFQDN" | Out-File $lookupScript -Append -Encoding OEM
    }
    Write-Output "pause" | Out-File $lookupScript -Append -Encoding OEM
}

# Invoke bootstrap script from bootstrap-os repository
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/geekzter/bootstrap-os/master/windows/bootstrap_windows.ps1'))
$settingsFile = "~\Source\GitHub\geekzter\bootstrap-os\common\settings.json"
if (!(Test-Path $settingsFile)) {
    $settings = (Get-Content "$settingsFile.sample" | ConvertFrom-Json)
    $settings.GitEmail = config.gitemail
    $settings.GitName = config.gitname
    $settings | ConvertTo-Json | Out-File $settingsFile
}
& ~\Source\GitHub\geekzter\bootstrap-os\windows\bootstrap_windows.ps1 -All

# Install software required for demo
choco install azure-data-studio microsoftazurestorageexplorer sql-server-management-studio vscode -r -y
choco install TelnetClient --source windowsfeatures -r -y

# Clone repositories
$repoRoot = "~\Source\GitHub\geekzter"
$null = New-Item -ItemType Directory -Force -Path $repoRoot
Push-Location $repoRoot
$repoData = Invoke-RestMethod https://api.github.com/users/geekzter/repos
$repos = ($repoData | Select-Object -ExpandProperty name)
foreach ($repo in $repos) {
    if (!(Test-Path $repo)) {
        git clone https://github.com/geekzter/$repo
    }
}

Invoke-Item $repoRoot
