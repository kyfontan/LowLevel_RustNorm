param()

$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CargoHomeDir = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $HOME '.cargo' }
$ConfigFile = Join-Path $CargoHomeDir 'config.toml'
$RustperfCmdBin = Join-Path $CargoHomeDir 'bin\rustperf.cmd'
$RustToolchainFile = Join-Path $RootDir 'rust-toolchain.toml'
$LintCargoConfig = Join-Path $RootDir 'machine-oriented-lints\.cargo\config.toml'
$VsCodeUserDir = Join-Path $env:APPDATA 'Code\User'
$SnippetFile = Join-Path $VsCodeUserDir 'snippets\rust.json'

function Set-FileContentAtomically([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    $filename = Split-Path -Leaf $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $tempFile = Join-Path $directory ("{0}.{1}.tmp" -f $filename, [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tempFile $Path
}

function Remove-CargoAliasIfPresent([string]$Name) {
    if (-not (Test-Path $ConfigFile)) {
        return
    }

    $lines = Get-Content $ConfigFile
    $inAlias = $false
    $kept = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match '^\[alias\]$') {
            $inAlias = $true
            $kept.Add($line)
            continue
        }

        if ($line -match '^\[' -and $line -ne '[alias]') {
            $inAlias = $false
        }

        if ($inAlias -and $line -match ("^\s*{0}\s*=" -f [regex]::Escape($Name))) {
            continue
        }

        $kept.Add($line)
    }

    Set-FileContentAtomically $ConfigFile (($kept -join "`r`n") + "`r`n")
}

Write-Host '==> Removing cargo aliases' -ForegroundColor Blue
Remove-CargoAliasIfPresent 'pc'
Remove-CargoAliasIfPresent 'pd'

Write-Host '==> Removing rustperf command' -ForegroundColor Blue
Remove-Item $RustperfCmdBin -ErrorAction SilentlyContinue

Write-Host '==> Removing rust-toolchain.toml' -ForegroundColor Blue
Remove-Item $RustToolchainFile -ErrorAction SilentlyContinue

Write-Host '==> Removing dylint linker config' -ForegroundColor Blue
Remove-Item $LintCargoConfig -ErrorAction SilentlyContinue

Write-Host '==> Removing VS Code snippet' -ForegroundColor Blue
Remove-Item $SnippetFile -ErrorAction SilentlyContinue

Write-Host '==> Optionally uninstall dylint tools' -ForegroundColor Blue
$answer = Read-Host 'Remove cargo-dylint and dylint-link? [y/N]'
if ($answer -match '^[Yy]$') {
    & cargo uninstall cargo-dylint | Out-Null
    & cargo uninstall dylint-link | Out-Null
}

Write-Host ""
Write-Host 'Uninstall complete.' -ForegroundColor Green
Write-Host ""
Write-Host 'Remaining files:'
Write-Host "  $RootDir\templates\"
Write-Host "  $RootDir\machine-oriented-lints\"
Write-Host "`nYou can delete the repo manually if you no longer need it."
