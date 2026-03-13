param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$CargoHomeDir = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $HOME '.cargo' }
$ConfigFile = Join-Path $CargoHomeDir 'config.toml'
$CargoBinDir = Join-Path $CargoHomeDir 'bin'
$RustperfCmdBin = Join-Path $CargoBinDir 'rustperf.cmd'
$RustperfTemplate = Join-Path $RootDir 'templates\rustperf.cmd'
$RustToolchainFile = Join-Path $RootDir 'rust-toolchain.toml'
$LintCrateDir = Join-Path $RootDir 'machine-oriented-lints'
$LintCargoConfigDir = Join-Path $LintCrateDir '.cargo'
$LintCargoConfigFile = Join-Path $LintCargoConfigDir 'config.toml'
$ProjectDylintTemplate = Join-Path $RootDir 'templates\project.dylint.toml'
$GeneratedProjectDylint = Join-Path $RootDir 'templates\project.dylint.generated.toml'
$DylintConfigTemplate = Join-Path $RootDir 'templates\dylint.toml'
$GeneratedDylintConfig = Join-Path $RootDir 'templates\dylint.generated.toml'
$VsCodeUserDir = Join-Path $env:APPDATA 'Code\User'
$PinnedNightly = if ($env:PINNED_NIGHTLY) { $env:PINNED_NIGHTLY } else { 'nightly-2026-03-01' }

function Write-Section([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Blue
}

function Write-Step([string]$Message) {
    Write-Host "  - $Message" -ForegroundColor Cyan
}

function Write-Success([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

function Write-WarnLine([string]$Message) {
    Write-Host "Warning: $Message" -ForegroundColor Yellow
}

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Set-FileContentAtomically([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    $filename = Split-Path -Leaf $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $tempFile = Join-Path $directory ("{0}.{1}.tmp" -f $filename, [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Force $tempFile $Path
}

function Add-CargoAliasIfMissing([string]$Name, [string]$Value) {
    $line = "$Name = `"$Value`""
    if (-not (Test-Path $ConfigFile)) {
        Set-FileContentAtomically $ConfigFile "[alias]`n$line`n"
        return
    }

    $raw = Get-Content $ConfigFile -Raw
    if ($raw -match "(?m)^\s*$([regex]::Escape($Name))\s*=") {
        return
    }

    if ($raw -match '(?m)^\[alias\]\s*$') {
        $updated = [regex]::Replace($raw, '(?m)^\[alias\]\s*$', "[alias]`r`n$line", 1)
        Set-FileContentAtomically $ConfigFile $updated
        return
    }

    $separator = if ($raw.EndsWith("`n")) { "" } else { "`r`n" }
    $updated = "$raw$separator`r`n[alias]`r`n$line`r`n"
    Set-FileContentAtomically $ConfigFile $updated
}

function Ensure-CdylibInLintCrate() {
    $cargoToml = Join-Path $LintCrateDir 'Cargo.toml'
    if (-not (Test-Path $cargoToml)) {
        throw "Lint crate Cargo.toml not found: $cargoToml"
    }

    $raw = Get-Content $cargoToml -Raw
    if ($raw -notmatch 'crate-type\s*=\s*\[[^\]]*"cdylib"[^\]]*\]') {
        Write-WarnLine "$cargoToml does not appear to declare [lib] crate-type = [""cdylib""]"
    }
}

function Write-RustToolchainFile() {
    $content = @"
[toolchain]
channel = "$PinnedNightly"
components = ["rust-src", "rustc-dev", "llvm-tools-preview"]
profile = "minimal"
"@
    Set-FileContentAtomically $RustToolchainFile $content
}

function Write-LintCargoConfig() {
    $content = @"
[target.aarch64-apple-darwin]
linker = "dylint-link"

[target.x86_64-apple-darwin]
linker = "dylint-link"

[target.x86_64-unknown-linux-gnu]
linker = "dylint-link"

[target.aarch64-unknown-linux-gnu]
linker = "dylint-link"

[target.x86_64-pc-windows-msvc]
linker = "dylint-link"

[target.aarch64-pc-windows-msvc]
linker = "dylint-link"

[target.x86_64-pc-windows-gnu]
linker = "dylint-link"
"@
    Set-FileContentAtomically $LintCargoConfigFile $content
}

function Generate-ProjectDylintTemplates() {
    if (Test-Path $ProjectDylintTemplate) {
        $raw = Get-Content $ProjectDylintTemplate -Raw
        $updated = $raw.Replace('__RUST_PERF_NORM_ROOT__', $RootDir.Replace('\', '/'))
        Set-FileContentAtomically $GeneratedProjectDylint $updated
    } else {
        $content = @"
[workspace.metadata.dylint]
libraries = [
  { path = "$($RootDir.Replace('\', '/'))/machine-oriented-lints" },
]
"@
        Set-FileContentAtomically $GeneratedProjectDylint $content
    }

    if (Test-Path $DylintConfigTemplate) {
        Copy-Item -Force $DylintConfigTemplate $GeneratedDylintConfig
    } else {
        $content = @"
[machine_oriented_lints]
small_vec_capacity_threshold = 64
vec_new_then_push_min_pushes = 2
"@
        Set-FileContentAtomically $GeneratedDylintConfig $content
    }
}

function Warn-IfNoWindowsToolchain() {
    $hasMsvcLinker = (Get-Command cl.exe -ErrorAction SilentlyContinue) -or (Get-Command link.exe -ErrorAction SilentlyContinue)
    $hasGnuLinker = (Get-Command gcc.exe -ErrorAction SilentlyContinue) -or (Get-Command clang.exe -ErrorAction SilentlyContinue)

    if (-not $hasMsvcLinker -and -not $hasGnuLinker) {
        Write-WarnLine 'No native Windows C/C++ toolchain was detected. Prefer the MSVC Rust toolchain with Visual Studio Build Tools installed, or ensure a GNU linker is available.'
    }
}

function Install-RustperfCommand() {
    if (-not (Test-Path $RustperfTemplate)) {
        throw "rustperf command template not found: $RustperfTemplate"
    }

    New-Item -ItemType Directory -Force -Path $CargoBinDir | Out-Null
    Copy-Item -Force $RustperfTemplate $RustperfCmdBin
}

Write-Section 'Checking prerequisites'
Write-Step 'Target platform: Windows'
Require-Command cargo
Require-Command rustup
Warn-IfNoWindowsToolchain

New-Item -ItemType Directory -Force -Path $CargoHomeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $VsCodeUserDir 'snippets') | Out-Null

Write-Section 'Installing Rust toolchain support'
Write-Step "Ensuring pinned nightly exists: $PinnedNightly"
& rustup toolchain install $PinnedNightly --profile minimal

Write-Step 'Installing nightly components required by Dylint'
& rustup component add --toolchain $PinnedNightly rust-src rustc-dev llvm-tools-preview

Write-Section 'Installing lint runtime'
Write-Step 'Installing cargo-dylint and dylint-link'
& cargo install cargo-dylint dylint-link

Write-Section 'Configuring this repository'
Write-Step 'Writing pinned rust-toolchain.toml'
Write-RustToolchainFile

Write-Step 'Writing machine-oriented-lints/.cargo/config.toml'
Write-LintCargoConfig

Write-Step 'Checking machine-oriented-lints/Cargo.toml'
Ensure-CdylibInLintCrate

Write-Section 'Configuring user shortcuts'
Write-Step "Updating Cargo aliases in $ConfigFile"
Add-CargoAliasIfMissing 'pc' 'clippy --workspace --all-targets --all-features -- -D warnings -W clippy::pedantic -W clippy::perf -D clippy::linkedlist -D clippy::vec_box -D clippy::ptr_arg'
Add-CargoAliasIfMissing 'pd' 'dylint --all'

Write-Step "Installing rustperf command into $RustperfCmdBin"
Install-RustperfCommand

Write-Section 'Installing editor assets'
Write-Step 'Installing VS Code Rust snippet'
Copy-Item -Force (Join-Path $RootDir 'snippets\rust.json') (Join-Path $VsCodeUserDir 'snippets\rust.json')

Write-Step 'Generating Cargo.toml and dylint.toml examples'
Generate-ProjectDylintTemplates

Write-Host ""
Write-Success 'Installation complete.'
Write-Host ""
Write-Host 'Installed assets:'
Write-Host "  VS Code snippet: $VsCodeUserDir\snippets\rust.json"
Write-Host "  rust-toolchain:  $RustToolchainFile"
Write-Host "  lint config:     $LintCargoConfigFile"
Write-Host "  rustperf cmd:    $RustperfCmdBin"
Write-Host "  Cargo.toml snippet: $GeneratedProjectDylint"
Write-Host "  dylint.toml:        $GeneratedDylintConfig`n"
Write-Host 'Quick checks:'
Write-Host "  cd `"$RootDir`""
Write-Host '  cargo check -p machine_oriented_lints'
Write-Host '  rustperf'
Write-Host "`nAdd this to Cargo.toml:`n"
Get-Content $GeneratedProjectDylint
Write-Host "`nAdd this to dylint.toml:`n"
Get-Content $GeneratedDylintConfig
