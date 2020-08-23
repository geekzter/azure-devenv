#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Script used to configure developer vm
#> 


# Clone repositories
$repoRoot = "~\src\github\geekzter"
$null = New-Item -ItemType Directory -Force -Path $repoRoot
Push-Location $repoRoot
$repoData = Invoke-RestMethod https://api.github.com/users/geekzter/repos
$repos = ($repoData | Select-Object -ExpandProperty name)
foreach ($repo in $repos) {
    if (!(Test-Path $repo)) {
        git clone https://github.com/geekzter/$repo
    }
}
