<# 
.SYNOPSIS 
    Script used to bootstrap devevloper workstation
 
.DESCRIPTION 
    This script is downloaded and executed during first logon

.EXAMPLE
    cmd.exe /c start PowerShell.exe -ExecutionPolicy Bypass -Noexit -Command "&amp; {Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('{script_url}'))}"
#> 

# Propagate vareiables passed into Terraform templatefile
$armSubscriptionID = '${arm_subscription_id}'
$armTenantID       = '${arm_tenant_id}'
$gitEmail          = '${git_email}'
$gitName           = '${git_name}'
$packages          = '${packages}'
$subnetID          = '${subnet_id}'
$tfStateResourceGroup = '${tf_state_resource_group}'
$tfStateStorageAccount = '${tf_state_storage_account}'
$virtualNetworkID  = '${virtual_network_id}'

# Set up environment
if ($armSubscriptionID) {
    [Environment]::SetEnvironmentVariable("ARM_SUBSCRIPTION_ID", $armSubscriptionID, 'User')
}
if ($armTenantID) {
    [Environment]::SetEnvironmentVariable("ARM_TENANT_ID", $armTenantID, 'User')
}
if ($subnetID) {
    [Environment]::SetEnvironmentVariable("GEEKZTER_AGENT_SUBNET_ID", $subnetID, 'Machine')
}
if ($tfStateResourceGroup) {
    [Environment]::SetEnvironmentVariable("TF_STATE_backend_resource_group", $tfStateResourceGroup, 'User')
}
if ($tfStateStorageAccount) {
    [Environment]::SetEnvironmentVariable("TF_STATE_backend_storage_account", $tfStateStorageAccount, 'User')
}
if ($virtualNetworkID) {
    [Environment]::SetEnvironmentVariable("GEEKZTER_AGENT_VIRTUAL_NETWORK_ID", $virtualNetworkID, 'Machine')
}

# Schedule bootstrap command to run on every logon
$localBatchScript = "$env:PUBLIC\setup.cmd"
$localPSScript = $PSCommandPath
Write-Output "PowerShell.exe -ExecutionPolicy Bypass -Noexit -File $localPSScript" | Out-File -FilePath $localBatchScript -Encoding OEM
schtasks.exe /create /f /rl HIGHEST /sc onlogon /tn "Bootstrap" /tr $localBatchScript
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 99

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

# Run post generation chocolatey cleanup, if present on image
if (Test-Path C:\post-generation\Choco.ps1) {
    # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
    & C:\post-generation\Choco.ps1
}

# Invoke bootstrap script from bootstrap-os repository
$bootstrapScript = "$env:PUBLIC\bootstrap_windows.ps1"
(New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/geekzter/bootstrap-os/${bootstrap_branch}/windows/bootstrap_windows.ps1') | Out-File $bootstrapScript -Force
. $bootstrapScript -Branch ${bootstrap_branch} -Packages $packages 
$settingsFile = "~\Source\GitHub\geekzter\bootstrap-os\common\settings.json"
$settingsFileSample = $settingsFile + ".sample"
if (!(Test-Path $settingsFile)) {
    if (Test-Path $settingsFileSample) {
        [object]$settings = (Get-Content $settingsFileSample | ConvertFrom-Json)
        if ($gitEmail) {
            $settings.GitEmail = $gitEmail       
        }
        if ($gitName) {
            $settings.GitName = $gitName
        }
        Write-Host "Settings:"
        $settings
        $settings | ConvertTo-Json | Out-File $settingsFile
    } else {
        Write-Warning "Unable to configure GitHub settings, settings file not found"
    }
}

& ~\Source\GitHub\geekzter\bootstrap-os\windows\bootstrap_windows.ps1 -Branch ${bootstrap_branch} -Packages None -PowerShell:$true -Settings:$true

# Developer shortcuts
if (Test-Path "$env:userprofile\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState") {
    $null = New-Item -ItemType symboliclink -path "$env:userprofile\Azure VPN Profiles" -value "$env:userprofile\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState" -Force
}
if (Get-Command PinToQuickAccess) {
    PinToQuickAccess $env:userprofile
    PinToQuickAccess "$env:userprofile\Azure VPN Profiles"
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

# Run post generation, of available on image
if (Test-Path C:\post-generation) {
    # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
    Get-ChildItem C:\post-generation -Filter *.ps1 | ForEach-Object { & $_.FullName }
}