@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "RUSTPERF_NORM_ROOT=__RUST_PERF_NORM_ROOT__"
set "LINT_LIBRARY_PATH=%RUSTPERF_NORM_ROOT:\=/%/crates/machine-oriented-lints"
set "LEGACY_LIBRARY_PATH=%RUSTPERF_NORM_ROOT:\=/%/machine-oriented-lints"
for %%I in ("%RUSTPERF_NORM_ROOT%") do set "RUSTPERF_PARENT=%%~dpI"
set "RUSTPERF_PARENT=%RUSTPERF_PARENT:~0,-1%"
set "LEGACY_RENAMED_LIBRARY_PATH=%RUSTPERF_PARENT:\=/%/LowLevel_RustNorm/machine-oriented-lints"
set "CARGO_HOME_DIR=%CARGO_HOME%"
if "%CARGO_HOME_DIR%"=="" set "CARGO_HOME_DIR=%USERPROFILE%\.cargo"
set "RUSTPERF_CMD_BIN=%CARGO_HOME_DIR%\bin\rustperf.cmd"
set "RUSTPERF_TEMPLATE=%RUSTPERF_NORM_ROOT%\assets\templates\rustperf.cmd"

if "%~1"=="init" goto :init
if "%~1"=="repair" goto :repair_entry

goto :run_dylint

:init
shift
if not "%~1"=="" (
  echo Error: rustperf init does not accept extra arguments 1>&2
  exit /b 1
)
goto :repair_project

:repair_entry
shift
if "%~1"=="" (
  call :repair_project_maybe
  if errorlevel 2 exit /b 1
  call :repair_self
  exit /b 0
)
if "%~1"=="self" (
  call :repair_self
  exit /b 0
)
if "%~1"=="project" (
  call :repair_project
  exit /b %ERRORLEVEL%
)
echo Error: unknown rustperf repair target: %~1 1>&2
exit /b 1

:repair_project_maybe
if exist "Cargo.toml" (
  call :repair_project
  exit /b %ERRORLEVEL%
)
exit /b 0

:repair_project
if not exist "Cargo.toml" (
  echo Error: no Cargo.toml found in %CD% 1>&2
  exit /b 2
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cargoToml = 'Cargo.toml';" ^
  "$current = $env:LINT_LIBRARY_PATH;" ^
  "$legacy1 = $env:LEGACY_LIBRARY_PATH;" ^
  "$legacy2 = $env:LEGACY_RENAMED_LIBRARY_PATH;" ^
  "$content = Get-Content $cargoToml -Raw;" ^
  "$updated = $content.Replace($legacy1, $current).Replace($legacy2, $current);" ^
  "if ($updated -notmatch '(?m)^\[workspace\.metadata\.dylint\]$') {" ^
  "  $block = @'" ^
[workspace.metadata.dylint]
libraries = [
  { path = "__CURRENT__" },
]
'@.Replace('__CURRENT__', $current);" ^
  "  if ($updated.Length -gt 0) { if ($updated.EndsWith(\"`n\")) { $updated += \"`n\" + $block } else { $updated += \"`r`n`r`n\" + $block } } else { $updated = $block }" ^
  "}" ^
  "[System.IO.File]::WriteAllText($cargoToml, $updated, [System.Text.UTF8Encoding]::new($false))"
if errorlevel 1 exit /b 1
if not exist "dylint.toml" (
  > "dylint.toml" (
    echo [machine_oriented_lints]
    echo # Warn when Vec::with_capacity uses a tiny compile-time constant.
    echo small_vec_capacity_threshold = 64
    echo.
    echo # Warn when Vec::new() is followed by N or more consecutive push calls.
    echo vec_new_then_push_min_pushes = 2
    echo.
    echo # Warn when HashMap::new() is followed by N or more consecutive insert calls.
    echo hash_map_new_then_insert_min_inserts = 2
    echo.
    echo # Warn when HashSet::new() is followed by N or more consecutive insert calls.
    echo hash_set_new_then_insert_min_inserts = 2
    echo.
    echo # Warn when String::new() is followed by N or more consecutive push_str calls.
    echo string_new_then_push_str_min_calls = 2
  )
) else (
  findstr /C:"[machine_oriented_lints]" "dylint.toml" >nul 2>nul
  if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$path = 'dylint.toml';" ^
      "$block = @'" ^
[machine_oriented_lints]
# Warn when Vec::with_capacity uses a tiny compile-time constant.
small_vec_capacity_threshold = 64

# Warn when Vec::new() is followed by N or more consecutive push calls.
vec_new_then_push_min_pushes = 2

# Warn when HashMap::new() is followed by N or more consecutive insert calls.
hash_map_new_then_insert_min_inserts = 2

# Warn when HashSet::new() is followed by N or more consecutive insert calls.
hash_set_new_then_insert_min_inserts = 2

# Warn when String::new() is followed by N or more consecutive push_str calls.
string_new_then_push_str_min_calls = 2
'@;" ^
      "$content = Get-Content $path -Raw;" ^
      "if ($content.EndsWith(\"`n\")) { $content += \"`n\" + $block } else { $content += \"`r`n`r`n\" + $block }" ^
      "[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))"
    if errorlevel 1 exit /b 1
  )
)
echo Updated %CD%\Cargo.toml
echo Updated %CD%\dylint.toml
exit /b 0

:repair_self
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$template = Join-Path $env:RUSTPERF_NORM_ROOT 'assets\templates\rustperf.cmd';" ^
  "$target = $env:RUSTPERF_CMD_BIN;" ^
  "$raw = Get-Content $template -Raw;" ^
  "$updated = $raw.Replace('__RUST_PERF_NORM_ROOT__', $env:RUSTPERF_NORM_ROOT.Replace('\', '/'));" ^
  "$dir = Split-Path -Parent $target;" ^
  "New-Item -ItemType Directory -Force -Path $dir | Out-Null;" ^
  "[System.IO.File]::WriteAllText($target, $updated, [System.Text.UTF8Encoding]::new($false))"
if errorlevel 1 exit /b 1
echo Repaired %RUSTPERF_CMD_BIN%
exit /b 0

:run_dylint
if exist "Cargo.toml" (
  findstr /C:"%LEGACY_LIBRARY_PATH%" "Cargo.toml" >nul 2>nul
  if not errorlevel 1 (
    echo Error: detected an outdated Rustperf Dylint library path in %CD%\Cargo.toml 1>&2
    echo Run rustperf repair from this project root to fix it automatically. 1>&2
    exit /b 1
  )
  findstr /C:"%LEGACY_RENAMED_LIBRARY_PATH%" "Cargo.toml" >nul 2>nul
  if not errorlevel 1 (
    echo Error: detected an outdated Rustperf Dylint library path in %CD%\Cargo.toml 1>&2
    echo Run rustperf repair from this project root to fix it automatically. 1>&2
    exit /b 1
  )
)
cargo dylint --all %*
