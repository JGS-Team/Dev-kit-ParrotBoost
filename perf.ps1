param(
    [string]$ExePath = (Join-Path $PSScriptRoot "..\ParrotBoost.exe"),
    [int]$Iterations = 3,
    [int]$ReadyTimeoutSeconds = 10,
    [int]$SampleSeconds = 5,
    [string]$TargetOsLabel = "",
    [string]$ReportPath = (Join-Path $PSScriptRoot "perf_report.md")
)

$ExePath = [System.IO.Path]::GetFullPath($ExePath)
if (-not (Test-Path $ExePath)) {
    throw "Executable not found: $ExePath"
}

$osInfo = Get-CimInstance Win32_OperatingSystem
$osLabel = if ([string]::IsNullOrWhiteSpace($TargetOsLabel)) {
    "$($osInfo.Caption) ($($osInfo.Version))"
} else {
    $TargetOsLabel
}

$results = @()

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "Iteration ${i}/${Iterations}: $ExePath"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $ExePath -PassThru

    try {
        $deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
        do {
            Start-Sleep -Milliseconds 100
            $process.Refresh()
        } while (-not $process.HasExited -and $process.MainWindowHandle -eq 0 -and (Get-Date) -lt $deadline)

        $stopwatch.Stop()

        $cpuStart = $process.CPU
        $readStart = $process.ReadTransferCount
        $writeStart = $process.WriteTransferCount

        Start-Sleep -Seconds $SampleSeconds
        $process.Refresh()

        $results += [pscustomobject]@{
            Iteration       = $i
            StartupMs       = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 0)
            PeakWorkingSetMB = [math]::Round($process.PeakWorkingSet64 / 1MB, 2)
            WorkingSetMB    = [math]::Round($process.WorkingSet64 / 1MB, 2)
            CpuSecondsDelta = [math]::Round(($process.CPU - $cpuStart), 2)
            ReadMBDelta     = [math]::Round(($process.ReadTransferCount - $readStart) / 1MB, 2)
            WriteMBDelta    = [math]::Round(($process.WriteTransferCount - $writeStart) / 1MB, 2)
            ExitedEarly     = $process.HasExited
        }
    }
    finally {
        if (-not $process.HasExited) {
            $null = $process.CloseMainWindow()
            Start-Sleep -Seconds 2
        }

        if (-not $process.HasExited) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            } catch {
                Write-Warning "Unable to stop ParrotBoost process $($process.Id): $($_.Exception.Message)"
            }
        }
    }
}

$results | Format-Table -AutoSize
$results | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $PSScriptRoot "perf_results.json") -Encoding UTF8

if ($results.Count -gt 0) {
    $summary = [pscustomobject]@{
        TargetOsLabel      = $osLabel
        Iterations         = $results.Count
        AvgStartupMs       = [math]::Round(($results | Measure-Object -Property StartupMs -Average).Average, 0)
        AvgPeakWorkingSetMB = [math]::Round(($results | Measure-Object -Property PeakWorkingSetMB -Average).Average, 2)
        AvgWorkingSetMB    = [math]::Round(($results | Measure-Object -Property WorkingSetMB -Average).Average, 2)
        AvgCpuSecondsDelta = [math]::Round(($results | Measure-Object -Property CpuSecondsDelta -Average).Average, 2)
        AvgReadMBDelta     = [math]::Round(($results | Measure-Object -Property ReadMBDelta -Average).Average, 2)
        AvgWriteMBDelta    = [math]::Round(($results | Measure-Object -Property WriteMBDelta -Average).Average, 2)
    }

    $report = @"
# ParrotBoost Performance Report

## Environment

- Target OS: $($summary.TargetOsLabel)
- Executable: $ExePath
- Iterations: $($summary.Iterations)
- Sample window: $SampleSeconds second(s)

## Average Metrics

| Metric | Value |
| :--- | ---: |
| Startup (ms) | $($summary.AvgStartupMs) |
| Peak working set (MB) | $($summary.AvgPeakWorkingSetMB) |
| Working set (MB) | $($summary.AvgWorkingSetMB) |
| CPU delta (s) | $($summary.AvgCpuSecondsDelta) |
| Read delta (MB) | $($summary.AvgReadMBDelta) |
| Write delta (MB) | $($summary.AvgWriteMBDelta) |

## Iteration Details

| Iteration | Startup (ms) | Peak WS (MB) | WS (MB) | CPU delta (s) | Read delta (MB) | Write delta (MB) | Exited early |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
$(($results | ForEach-Object { "| $($_.Iteration) | $($_.StartupMs) | $($_.PeakWorkingSetMB) | $($_.WorkingSetMB) | $($_.CpuSecondsDelta) | $($_.ReadMBDelta) | $($_.WriteMBDelta) | $($_.ExitedEarly) |" }) -join [Environment]::NewLine)
"@

    $report | Set-Content -Path $ReportPath -Encoding UTF8
}
