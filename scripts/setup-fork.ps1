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
$nodeDir = Join-Path $repoTools 'node-v24.15.0-win-x64'
if (Test-Path $nodeDir) {
    Write-Host '[env] using vendored Node 24.15.0'
    $env:PATH = "$nodeDir;$env:PATH"
}
if (Test-Path $repoTools) { $env:PATH = "$repoTools;$env:PATH" }

$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
if ((Test-Path $wingetLinks) -and ($env:PATH -notlike "*$wingetLinks*")) {
    $env:PATH = "$wingetLinks;$env:PATH"
}
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { throw 'jq not found on PATH (required by VSCodium scripts)' }

$env:VSCODE_QUALITY = 'stable'
$env:CI_BUILD = 'no'
$env:OS_NAME = 'windows'
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

$utilsSh = Join-Path $codiumDir 'utils.sh'
if ((Test-Path $utilsSh) -and ((Get-Content $utilsSh -Raw) -match 'exit 4')) {
    Write-Host '[normalize] tolerate missing entries in VSCodium removal lists (upstream version skew)'
    $raw = Get-Content $utilsSh -Raw
    $patched = $raw -replace 'echo "Not found: \$\{ENTRY_PATH\}" >&2\r?\n(\s*)exit 4', ('echo "Not found (tolerated by OpenPi): ${ENTRY_PATH}" >&2')
    Set-Content -Path $utilsSh -Value $patched -NoNewline -Encoding Ascii
}

$getRepoSh = Join-Path $codiumDir 'get_repo.sh'
if (Test-Path $getRepoSh) {
    Write-Host '[normalize] restore VSCodium-supported VS Code pin (never track latest)'
    git -C $codiumDir checkout -- upstream/stable.json 2>$null
    Write-Host '[normalize] make get_repo.sh idempotent for existing clones'
    $raw = Get-Content $getRepoSh -Raw
    $patched = $raw.Replace('git remote add origin https://github.com/Microsoft/vscode.git', 'git remote add origin https://github.com/Microsoft/vscode.git 2>/dev/null || true')
    Set-Content -Path $getRepoSh -Value $patched -NoNewline -Encoding Ascii
}

if ((Test-Path $codiumDir) -and -not $Force) {
    Write-Host '[skip] vscodium already cloned'
} else {
    if (Test-Path $codiumDir) { Remove-Item -Recurse -Force $codiumDir }
    Write-Host '[clone] VSCodium (shallow)'
    git clone --depth 1 https://github.com/VSCodium/vscodium.git $codiumDir
    if ($LASTEXITCODE -ne 0) { throw 'vscodium clone failed' }
}

$preparedMarker = Join-Path $codiumDir '.openpi-prepared'

if ((Test-Path $preparedMarker) -and -not $Force) {
    Write-Host '[skip] vscode already cloned/prepared'
} else {
    Write-Host '[prepare] get_repo.sh (clones microsoft/vscode at VSCodium-supported pin)'
        Push-Location $codiumDir
        try {
            & $gitBash ./get_repo.sh
        if ($LASTEXITCODE -ne 0) { throw 'get_repo.sh failed' }

        # Disable Spectre mitigation requirement for local dev builds (avoids needing Spectre libs)
        $propsPath = Join-Path $vscodeDir 'Directory.Build.props'
        if (-not (Test-Path $propsPath)) {
            Set-Content -Path $propsPath -Value @'
<Project>
  <PropertyGroup>
    <SpectreMitigation>false</SpectreMitigation>
  </PropertyGroup>
</Project>
'@ -Encoding Ascii
            Write-Host '[normalize] created Directory.Build.props (SpectreMitigation=false)'
        }

        Write-Host '[prepare] prepare_vscode.sh (overlays + VSCodium patches + product.json)'
        & $gitBash ./prepare_vscode.sh
        if ($LASTEXITCODE -ne 0) { throw 'prepare_vscode.sh failed' }
    } finally { Pop-Location }

    Set-Content -Path $preparedMarker -Value "prepared $(Get-Date -Format o)" -Encoding Ascii
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
