#Requires -Version 5.1
<#
.SYNOPSIS
  Clones upstream VS Code / VSCodium sources and applies OpenPi patches.
  Idempotent: safe to re-run; skips completed steps unless -Force.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [int]$VscodeDepth = 1
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent

$repoTools = Join-Path $root 'tools'
if (Test-Path $repoTools) { $env:PATH = "$repoTools;$env:PATH" }

$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
if ((Test-Path $wingetLinks) -and ($env:PATH -notlike "*$wingetLinks*")) {
    $env:PATH = "$wingetLinks;$env:PATH"
}
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { throw 'jq not found on PATH (required by VSCodium scripts)' }

$env:VSCODE_QUALITY = 'stable'
$env:CI_BUILD = 'no'
$upstream = Join-Path $root 'upstream'
$codiumDir = Join-Path $upstream 'vscodium'
$vscodeDir = Join-Path $codiumDir 'vscode'
$patchesDir = Join-Path $root 'patches\vscodium'

$gitBash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path $gitBash)) { throw "Git Bash not found at $gitBash" }

function Invoke-Git([string]$Repo, [string[]]$GitArgs) {
    Write-Host "> git $($GitArgs -join ' ') [$((Split-Path $Repo -Leaf))]"

    git -C $Repo @GitArgs

    if ($LASTEXITCODE -ne 0) { throw "git failed in $Repo" }
}

New-Item -ItemType Directory -Force -Path $upstream | Out-Null

if ((Test-Path $codiumDir) -and -not $Force) {
    Write-Host '[skip] vscodium already cloned'
} else {
    if (Test-Path $codiumDir) { Remove-Item -Recurse -Force $codiumDir }
    Write-Host '[clone] VSCodium (shallow)'
    git clone --depth 1 https://github.com/VSCodium/vscodium.git $codiumDir
    if ($LASTEXITCODE -ne 0) { throw 'vscodium clone failed' }
}

if ((Test-Path $vscodeDir) -and -not $Force) {
    Write-Host '[skip] vscode already cloned/prepared'
} else {
    Write-Host '[prepare] resolving pinned VS Code version via PowerShell (bypasses bash curl TLS issues)'
    $updateApi = Invoke-RestMethod -Uri 'https://update.code.visualstudio.com/api/update/darwin/stable/0000000000000000000000000000000000000000' -TimeoutSec 30
    $stableJson = @{ tag = $updateApi.name; commit = $updateApi.version } | ConvertTo-Json
    $stablePath = Join-Path $codiumDir 'upstream\stable.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $stablePath) | Out-Null
    Set-Content -Path $stablePath -Value $stableJson -Encoding Ascii
    Write-Host "[prepare] pinned VS Code $($updateApi.name) ($($updateApi.version))"

        Write-Host '[prepare] get_repo.sh (clones pinned microsoft/vscode)'
        Push-Location $codiumDir
        try {
            & $gitBash ./get_repo.sh
        if ($LASTEXITCODE -ne 0) { throw 'get_repo.sh failed' }

        Write-Host '[prepare] prepare_vscode.sh (overlays + VSCodium patches + product.json)'
        & $gitBash ./prepare_vscode.sh
        if ($LASTEXITCODE -ne 0) { throw 'prepare_vscode.sh failed' }
    } finally { Pop-Location }
}

if (Test-Path $patchesDir) {
    $patches = Get-ChildItem $patchesDir -Filter '*.patch' | Sort-Object Name
    if ($patches.Count -gt 0) {
        foreach ($p in $patches) {
            Write-Host "[patch] applying $($p.Name)"
            Invoke-Git $vscodeDir @('apply', '--check', "--directory=$($vscodeDir)", $p.FullName) 2>$null
            if ($LASTEXITCODE -eq 0) {
                Invoke-Git $vscodeDir @('apply', $p.FullName)
            } else {
                Write-Host "[patch] $($p.Name) already applied or not applicable - skipping"
            }
        }
    } else {
        Write-Host '[patch] no OpenPi patches yet - baseline only'
    }
}

Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. cd upstream\vscodium\vscode && npm ci   (10-20 min)'
Write-Host '  2. npm run compile                          (first build ~20-40 min)'
Write-Host '  or run scripts\build-installer.ps1 for the full pipeline'
