# ParrotBoost Professional Dev Kit

![Build Tool](https://img.shields.io/badge/tool-powershell-blue?style=for-the-badge&logo=powershell)
![Environment](https://img.shields.io/badge/env-windows-0078D6?style=for-the-badge&logo=windows)
![Quality](https://img.shields.io/badge/quality-zero--clutter-brightgreen?style=for-the-badge)

The Dev Kit is the repository's isolated build and diagnostics layer for ParrotBoost Professional v1.2.6 Stable. Its purpose is to provide predictable local automation without leaving unnecessary build artifacts in the source tree.

## Overview

The Dev Kit follows a zero-clutter workflow:

- build into a temporary publish directory,
- copy the final executable to the repository root,
- remove transient `bin`, `obj`, and temporary publish folders,
- execute a short runtime stability check when requested.

This approach is intended for contributors who want a repeatable Windows-based workflow with minimal manual cleanup.

## Prerequisites

- Windows 10 or Windows 11
- PowerShell
- .NET 11 SDK installed and available on `PATH`
- Administrator privileges when testing features that require elevated access

## Included Scripts

| File | Purpose |
| :--- | :--- |
| `build.ps1` | Publishes the application and copies `ParrotBoost.exe` to the repository root. |
| `test.ps1` | Starts the generated executable, performs a short stability probe, and writes a diagnostic report. |

## Build Workflow

Run the build orchestrator from the `DevKit` directory:

```powershell
.\build.ps1
```

What it does:

1. Stops a running `ParrotBoost` process if necessary.
2. Publishes the application as a self-contained single-file executable.
3. Copies the generated `ParrotBoost.exe` to the repository root.
4. Removes temporary publish output and intermediate build folders.

Expected result:

- `ParrotBoost.exe` is available in the repository root.
- source-level build clutter is removed after the script completes.

## Diagnostic Workflow

Run the diagnostic suite after building the executable:

```powershell
.\test.ps1
```

What it verifies:

1. The expected executable exists.
2. The current session's elevation state is reported.
3. The application starts and remains alive during a short runtime probe.
4. A diagnostic summary is written to `test_report.txt` in the repository root.

## Recommended Development Flow

1. Update the application in `Source/ParrotBoost`.
2. Run `dotnet build` or `dotnet test` while iterating locally.
3. Use `DevKit\build.ps1` for a clean distributable build.
4. Use `DevKit\test.ps1` to validate that the packaged executable starts correctly.

## Notes

- The Dev Kit is designed for repository-local usage and does not replace full CI.
- Some hardware telemetry and optimization routines depend on the target machine, installed drivers, and administrator access.
- If runtime monitoring features are unavailable on a specific machine, build validation may still pass while hardware data remains partially unavailable at runtime.
