param()

$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallScript = Join-Path $RootDir 'install\install.ps1'

& $InstallScript @args
