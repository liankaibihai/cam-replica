param([string]$MatlabPath = 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe', [string]$Task = 'run_tests')
$ErrorActionPreference = 'Stop'
$taskRepo = $PSScriptRoot
$taskLocal = Join-Path $taskRepo 'local'
$taskPrefs = Join-Path $taskLocal 'matlab_prefs'
New-Item -ItemType Directory -Force -Path $taskPrefs | Out-Null
$taskPreviousPrefs = $env:MATLAB_PREFDIR
try {
    $env:MATLAB_PREFDIR = $taskPrefs
    & $MatlabPath -batch $Task -sd $taskRepo -logfile (Join-Path $taskLocal 'matlab_checks.log')
    if ($LASTEXITCODE -ne 0) { throw "MATLAB exited with code $LASTEXITCODE" }
} finally {
    if ($null -eq $taskPreviousPrefs) { Remove-Item Env:MATLAB_PREFDIR -ErrorAction SilentlyContinue }
    else { $env:MATLAB_PREFDIR = $taskPreviousPrefs }
}
