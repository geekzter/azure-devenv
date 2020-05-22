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
schtasks.exe /create /f /rl HIGHEST /sc onlogon /tn "Bootstrap" /tr $localBatchScript
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 99

# Download PowerShell script
$localPSScript = "$env:PUBLIC\setup.ps1"
if ($config.scripturl) {
    Invoke-WebRequest -UseBasicParsing -Uri $config.scripturl -OutFile $localPSScript
}
if ($config.environmentscripturl) {
    $null = New-Item -ItemType directory -path $env:USERPROFILE\Documents\PowerShell -Force
    Invoke-WebRequest -UseBasicParsing -Uri $config.environmentscripturl -OutFile $env:USERPROFILE\Documents\PowerShell\environment.ps1
}

# Create shortcut
$wsh = New-Object -ComObject WScript.Shell
$shortcutFile = "$($env:USERPROFILE)\Desktop\Setup.lnk"
$bootstrapShortcut = $wsh.CreateShortcut($shortcutFile)
$bootstrapShortcut.TargetPath = $localBatchScript
$bootstrapShortcut.Save()
# Set shortcut to run as Administrator
# https://stackoverflow.com/questions/28997799/how-to-create-a-run-as-administrator-shortcut-using-powershell/29002207#29002207
$bytes = [System.IO.File]::ReadAllBytes($shortcutFile)
$bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
[System.IO.File]::WriteAllBytes($shortcutFile, $bytes)

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

# Remove apps not needed on a developer workstation
# Taken from https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Get-AppxPackage "Microsoft.BingFinance" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingFoodAndDrink" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingHealthAndFitness" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingMaps" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingNews" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingSports" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingTranslator" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingTravel" | Remove-AppxPackage
Get-AppxPackage "Microsoft.BingWeather" | Remove-AppxPackage
Get-AppxPackage "Microsoft.CommsPhone" | Remove-AppxPackage
Get-AppxPackage "Microsoft.FreshPaint" | Remove-AppxPackage
Get-AppxPackage "Microsoft.GetHelp" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Getstarted" | Remove-AppxPackage
Get-AppxPackage "Microsoft.HelpAndTips" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Media.PlayReadyClient.2" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Messaging" | Remove-AppxPackage
Get-AppxPackage "Microsoft.MicrosoftSolitaireCollection" | Remove-AppxPackage
Get-AppxPackage "Microsoft.MicrosoftStickyNotes" | Remove-AppxPackage
Get-AppxPackage "Microsoft.MinecraftUWP" | Remove-AppxPackage
Get-AppxPackage "Microsoft.MoCamera" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Office.Sway" | Remove-AppxPackage
Get-AppxPackage "Microsoft.OneConnect" | Remove-AppxPackage
Get-AppxPackage "Microsoft.People" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Reader" | Remove-AppxPackage
Get-AppxPackage "Microsoft.SkypeApp" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Todos" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Wallet" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WebMediaExtensions" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsAlarms" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsCamera" | Remove-AppxPackage
Get-AppxPackage "microsoft.windowscommunicationsapps" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsFeedbackHub" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsMaps" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsPhone" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Windows.Photos" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsReadingList" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsScan" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WindowsSoundRecorder" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WinJS.1.0" | Remove-AppxPackage
Get-AppxPackage "Microsoft.WinJS.2.0" | Remove-AppxPackage
Get-AppxPackage "Microsoft.XboxApp" | Remove-AppxPackage
Get-AppxPackage "Microsoft.XboxIdentityProvider" | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage "Microsoft.XboxSpeechToTextOverlay" | Remove-AppxPackage
Get-AppxPackage "Microsoft.XboxGameOverlay" | Remove-AppxPackage
Get-AppxPackage "Microsoft.XboxGamingOverlay" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Xbox.TCUI" | Remove-AppxPackage
Get-AppxPackage "Microsoft.YourPhone" | Remove-AppxPackage
Get-AppxPackage "Microsoft.ZuneMusic" | Remove-AppxPackage
Get-AppxPackage "Microsoft.ZuneVideo" | Remove-AppxPackage
Get-AppxPackage "Microsoft.Advertising.Xaml" | Remove-AppxPackage

# Invoke bootstrap script from bootstrap-os repository
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/geekzter/bootstrap-os/master/windows/bootstrap_windows.ps1'))
$settingsFile = "~\Source\GitHub\geekzter\bootstrap-os\common\settings.json"
if (!(Test-Path $settingsFile)) {
    $settings = (Get-Content "$settingsFile.sample" | ConvertFrom-Json)
    $settings.GitEmail = $config.gitemail
    $settings.GitName = $config.gitname
    $settings | ConvertTo-Json | Out-File $settingsFile
}
& ~\Source\GitHub\geekzter\bootstrap-os\windows\bootstrap_windows.ps1 -All

# Developer shortcuts
if (Test-Path "$env:userprofile\Azure VPN Profiles") {
    $null = New-Item -ItemType symboliclink -path "$env:userprofile\Azure VPN Profiles" -value "$env:userprofile\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState" -Force
    if (Get-Command PinToQuickAccess) {
        PinToQuickAccess $env:userprofile
    }
}

# Remove password expiration
Set-LocalUser -Name $env:USERNAME -PasswordNeverExpires 1

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
