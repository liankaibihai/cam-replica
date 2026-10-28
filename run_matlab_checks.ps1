param([string]$MatlabPath = 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe', [string]$Task = 'run_tests')
$ErrorActionPreference = 'Stop'
$taskRepo = $PSScriptRoot
$taskLocal = Join-Path $taskRepo 'local'
$taskRunId = [guid]::NewGuid().ToString('N')
$taskPrefs = Join-Path $taskLocal ('matlab_prefs_' + $taskRunId)
$taskLog = Join-Path $taskLocal ('matlab_' + $taskRunId + '.log')
New-Item -ItemType Directory -Force -Path $taskPrefs | Out-Null
$taskPreviousPrefs = $env:MATLAB_PREFDIR
try {
    $env:MATLAB_PREFDIR = $taskPrefs
    Write-Output ('MATLAB log: ' + $taskLog)
    & $MatlabPath -batch $Task -sd $taskRepo -logfile $taskLog
    if ($LASTEXITCODE -ne 0) { throw "MATLAB exited with code $LASTEXITCODE" }
} finally {
    if ($null -eq $taskPreviousPrefs) { Remove-Item Env:MATLAB_PREFDIR -ErrorAction SilentlyContinue }
    else { $env:MATLAB_PREFDIR = $taskPreviousPrefs }
}
