$ErrorActionPreference = "Stop"

$devkitPath = $PSScriptRoot
$rootPath = Split-Path $devkitPath -Parent
$projectPath = Join-Path $rootPath "Source\ParrotBoost\ParrotBoost.csproj"
$publishStage = Join-Path $rootPath "Source\ParrotBoost\bin\Publish"
$targetExe = Join-Path $rootPath "ParrotBoost.exe"

Write-Host "Publishing ParrotBoost (Single-File win-x64)..." -ForegroundColor Cyan

dotnet publish $projectPath -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $publishStage --no-restore
if ($LASTEXITCODE -ne 0) {
    dotnet publish $projectPath -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $publishStage
    if ($LASTEXITCODE -ne 0) {
        throw "Publish failed with exit code $LASTEXITCODE"
    }
}

$builtExe = Join-Path $publishStage "ParrotBoost.exe"
if (-not (Test-Path $builtExe)) {
    throw "Published executable not found at $builtExe"
}

if (Test-Path $targetExe) {
    try {
        Remove-Item "$targetExe.old" -Force -ErrorAction SilentlyContinue
        Rename-Item $targetExe "ParrotBoost.exe.old" -Force
    } catch {
        Write-Warning "Could not rename existing ParrotBoost.exe: $($_.Exception.Message)"
    }
}

Copy-Item $builtExe $targetExe -Force
Remove-Item "$targetExe.old" -Force -ErrorAction SilentlyContinue
Write-Host "Successfully built: $targetExe" -ForegroundColor Green
