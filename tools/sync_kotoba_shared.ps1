# Sync shared Kotoba translator assets between Ashita and Windower trees.
# Usage (from repo root):  powershell -File tools/sync_kotoba_shared.ps1
# Default source: Windower/addons/kotoba  →  Ashita/addons/kotoba

param(
    [ValidateSet('windower-to-ashita', 'ashita-to-windower')]
    [string]$Direction = 'windower-to-ashita'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$w = Join-Path $root 'Windower\addons\kotoba'
$a = Join-Path $root 'Ashita\addons\kotoba'

$files = @(
    'translator.py',
    'build_seed_db.py',
    'ffxi_glossary.txt',
    'requirements.txt',
    'translator_config.example.txt',
    'GLOSSARY_COVERAGE.md'
)

if ($Direction -eq 'windower-to-ashita') {
    $src, $dst = $w, $a
} else {
    $src, $dst = $a, $w
}

foreach ($f in $files) {
    $from = Join-Path $src $f
    $to = Join-Path $dst $f
    if (-not (Test-Path $from)) {
        Write-Warning "Missing source: $from"
        continue
    }
    Copy-Item -Path $from -Destination $to -Force
    Write-Host "OK $f"
}

Write-Host "Synced $Direction"
