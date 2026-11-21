$ErrorActionPreference = "Stop"

$devkitPath = $PSScriptRoot
$rootPath = Split-Path $devkitPath -Parent
$exePath = Join-Path $rootPath "ParrotBoost.exe"
$reportPath = Join-Path $rootPath "test_report.txt"

function Log-Report($msg) {
    Write-Host "  [TEST] $msg" -ForegroundColor Yellow
}

Log-Report "Starting clean diagnostic suite from DevKit..."

if (-not (Test-Path $exePath)) {
    Log-Report "ERROR: ParrotBoost.exe not found in root. Run build.ps1 first."
    exit 1
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Log-Report "Running in standard user mode (non-Admin)."
}
else {
    Log-Report "Admin privileges confirmed."
}

Log-Report "Running headless self-diagnostics..."
try {
    $diagProc = Start-Process -FilePath $exePath -ArgumentList "--self-diagnostics" -Wait -PassThru -ErrorAction Stop
    $diagExit = $diagProc.ExitCode
    if ($diagExit -ne 0) {
        Log-Report "ERROR: Self-diagnostics failed with exit code: $diagExit"
        "--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: FAIL (Self-diagnostics exit $diagExit)" | Out-File $reportPath -Force
        exit 1
    }
    Log-Report "SUCCESS: Self-diagnostics passed."
}
catch {
    Log-Report "CRITICAL ERROR during self-diagnostics: $($_.Exception.Message)"
    "--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: FAIL ($($_.Exception.Message))" | Out-File $reportPath -Force
    exit 1
}

Log-Report "Probing application stability (5s)..."
try {
    $process = Start-Process -FilePath $exePath -PassThru -ErrorAction Stop
    Log-Report "Process PID: $($process.Id). Waiting for stability..."
    Start-Sleep -Seconds 5

    if ($process.HasExited) {
        $exitCode = $process.ExitCode
        Log-Report "ERROR: Process exited prematurely with code: $exitCode"
        "--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: FAIL (Exited early with code $exitCode)" | Out-File $reportPath -Force
        exit 1
    }
    else {
        Log-Report "SUCCESS: Application is running stably."
        $process.Kill()
    }
}
catch {
    Log-Report "CRITICAL ERROR during execution test: $($_.Exception.Message)"
    "--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: FAIL ($($_.Exception.Message))" | Out-File $reportPath -Force
    exit 1
}

Log-Report "Diagnostic completed. Generating report..."
"--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: PASS" | Out-File $reportPath -Force
Log-Report "Report saved: $reportPath"

Remove-Item -Path "$exePath.old" -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $rootPath "build_log.txt") -ErrorAction SilentlyContinue

Write-Host "`n--- DIAGNOSTIC COMPLETE ---" -ForegroundColor Green
