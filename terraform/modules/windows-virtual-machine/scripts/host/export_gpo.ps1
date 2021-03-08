param ( 
    [parameter(Mandatory=$false)][switch]$InstallToolsIfMissing
) 

$onWindows = ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5))
if (!$onWindows) {
    Write-Warning "This can only be run from Windows, exiting"
    exit
}
$elevated = (New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole("Administrators")
if (!$elevated) {
    Write-Warning "Policy export requires administrative permissions, exiting"
    exit
}
if (!(Get-Command lgpo -ErrorAction SilentlyContinue)) {
    if ($InstallToolsIfMissing -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        choco install winsecuritybaseline
    }
}
if (!(Get-Command lgpo -ErrorAction SilentlyContinue)) {
    Write-Warning "LGPO not found. Please install by running 'choco install winsecuritybaseline' from an elevated shell, or downloading and installing it from https://www.microsoft.com/en-us/download/details.aspx?id=55319"
    exit
}

# Find root repo directory
$path = $PSScriptRoot
while($path -and !(Test-Path (Join-Path $path '.devcontainer'))){
    $path = Split-Path $path -Parent
}
$repoRoot = $path
$exportRoot = (Join-Path -Path $repoRoot "data\gpo\export")
Write-Host "Exporting Local Policy to ${exportRoot}..."
lgpo /b $exportRoot

$exportDirectory = (Get-ChildItem $exportRoot | Sort-Object -Property LastWriteTime -Descending | Where-Object -Property Name -Match '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$' | Select-Object -First 1)
Write-Host "Local Policy exported to ${exportDirectory}..."

$userPolicy = (Join-Path $exportDirectory.FullName "DomainSysvol\GPO\User\registry.pol")
if (!(Test-Path $userPolicy)) {
    Write-Warning "Policy ${userPolicy} not found, exiting"
    exit
}

$userPolicyText = (Join-Path $PSScriptRoot "user-policy.txt")
Write-Host "Parsing policy file ${userPolicy} to ${userPolicyText}..."
lgpo /parse /ua $userPolicy | Out-File $userPolicyText