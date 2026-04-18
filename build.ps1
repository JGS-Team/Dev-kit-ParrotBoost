# build.ps1 - ParrotBoost Professional Build Orchestrator
$ErrorActionPreference = "Stop"

# Paths relative to this script
$rootPath = $PSScriptRoot
$sourcePath = Join-Path $rootPath "Source\ParrotBoost"
$outputExe = Join-Path $rootPath "ParrotBoost.exe"

function Write-Log($msg) {
    Write-Host "  [BUILD] $msg" -ForegroundColor Cyan
}

Write-Log "Initializing zero-clutter build..."

# 1. Cleaning existing binary and stopping process
if (Test-Path $outputExe) { 
    Write-Log "Ensuring binary is not in use..."
    try {
        $processes = Get-Process "ParrotBoost" -ErrorAction SilentlyContinue
        if ($processes) { $processes | Stop-Process -Force }
        Remove-Item $outputExe -Force -ErrorAction Stop
    } catch {
        Write-Log "Binary is locked. Attempting to rotate..."
        $lockedExe = "$outputExe.locked"
        if (Test-Path $lockedExe) { Remove-Item $lockedExe -Force -ErrorAction SilentlyContinue }
        Move-Item $outputExe $lockedExe -Force -ErrorAction SilentlyContinue
    }
}

# 2. Build and Publish
try {
    Write-Log "Compiling Source..."
    $currentDir = Get-Location
    Set-Location $sourcePath
    
    # Using dotnet publish to create a self-contained single file in a temporary folder
    $tempPublish = Join-Path $sourcePath "temp_publish"
    
    dotnet publish -c Release -f net11.0-windows -r win-x64 --self-contained true `
        -p:PublishSingleFile=true `
        -p:PublishReadyToRun=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -o $tempPublish | Out-Null
        
    $generatedExe = Join-Path $tempPublish "ParrotBoost.exe"
    if (Test-Path $generatedExe) {
        Copy-Item $generatedExe $outputExe -Force
        Write-Log "Success: ParrotBoost.exe generated in Project Root."
    } else {
        throw "Build failed: Output binary not found."
    }
    
    # 3. Cleanup "garbage" (Zero-Clutter)
    Write-Log "Cleaning up build artifacts..."
    Set-Location $rootPath
    Remove-Item (Join-Path $sourcePath "bin") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $sourcePath "obj") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tempPublish -Recurse -Force -ErrorAction SilentlyContinue
    
    Set-Location $currentDir
} catch {
    Write-Host "!!! Build Error: $_" -ForegroundColor Red
    Set-Location $currentDir
    exit 1
}

Write-Host "`n--- BUILD SUCCESSFUL ---" -ForegroundColor Green
