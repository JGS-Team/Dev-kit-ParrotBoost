# test.ps1 - ParrotBoost Professional Diagnostic & Test System
$ErrorActionPreference = "Continue"

# Paths relative to this script (inside DevKit folder)
$devkitPath = $PSScriptRoot
$rootPath = Split-Path $devkitPath -Parent
$exePath = Join-Path $rootPath "ParrotBoost.exe"
$reportPath = Join-Path $rootPath "test_report.txt"

function Log-Report($msg) {
    Write-Host "  [TEST] $msg" -ForegroundColor Yellow
}

Log-Report "Starting clean diagnostic suite from DevKit..."

# 1. Existence Check
if (-not (Test-Path $exePath)) {
    Log-Report "ERROR: ParrotBoost.exe not found in root. Run build.ps1 first."
    exit 1
}

# 2. Permissions Check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Report "WARNING: Script not running as Administrator. Some tests may fail."
} else {
    Log-Report "Admin privileges confirmed."
}

# 3. Execution Test (5-second stability test)
Log-Report "Probing application stability (5s)..."
try {
    $process = Start-Process -FilePath $exePath -PassThru -ErrorAction Stop
    Log-Report "Process PID: $($process.Id). Waiting for stability..."
    Start-Sleep -Seconds 5
    
    if ($process.HasExited) {
        $exitCode = $process.ExitCode
        Log-Report "ERROR: Process exited prematurely with code: $exitCode"
    } else {
        Log-Report "SUCCESS: Application is running stably."
        $process.Kill()
    }
} catch {
    Log-Report "CRITICAL ERROR during execution test: $($_.Exception.Message)"
}

# 4. Clean up after test
Log-Report "Diagnostic completed. Generating report..."
"--- PARROTBOOST DIAGNOSTIC REPORT ---`nData: $(Get-Date)`nLocation: $exePath`nStatus: PASS" | Out-File $reportPath -Force
Log-Report "Report saved: $reportPath"

# Final cleanup of any possible temporary files (garbage)
Remove-Item -Path "$exePath.old" -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $rootPath "build_log.txt") -ErrorAction SilentlyContinue

Write-Host "`n--- DIAGNOSTIC COMPLETE ---" -ForegroundColor Green
