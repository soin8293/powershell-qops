# PowerShell-QOps
*A cross-platform PowerShell module for system auditing, cleanup, and self-healing tasks with automated testing and CI/CD.*

[![Build](https://github.com/soin8293/powershell-qops/actions/workflows/windows-ci.yml/badge.svg)](https://github.com/soin8293/powershell-qops/actions/workflows/windows-ci.yml)
[![PowerShell Version](https://img.shields.io/badge/PowerShell-7%2B-blue)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
[![License](https://img.shields.io/github/license/soin8293/powershell-qops)](https://github.com/soin8293/powershell-qops/blob/main/LICENSE)
---
## 📜 Overview
PowerShell-QOps is a modular, test-driven system diagnostics and remediation toolkit for Windows and PowerShell Core environments. Designed for IT professionals and QA engineers, it features:
- Modular PowerShell cmdlets for system reporting and cleanup
- Cross-platform compatibility (Windows + Ubuntu via PowerShell 7)
- CI/CD with linting, Pester testing, and enforced code coverage
- JSON output for integration into dashboards or monitoring tools
- CLI wrapper scripts for command-line usage
- Module manifest for PSGallery readiness
---
## 📦 Features
### ✅ `Get-SystemReport`
- Collects OS, disk, RAM, network info (RAM & network info are future enhancements for this function)
- Structured JSON output with schema versioning (`1.0.0`)
- Robust error handling
- CI tested with Pester and snapshot validation (snapshot validation is a future test enhancement)

### ✅ `Fix-DiskCleanup`
- Cleans temporary files from user and system TEMP directories based on age (`-DaysOld` parameter, default 14).
- Supports `-DryRun` mode to preview deletions in `CleanupPlan.json` without making changes.
- Live mode uses `ShouldProcess` for `-Confirm` and `-WhatIf` support.
- Logs actions (identified, deleted, skipped files, errors) to `C:\ProgramData\QAOps\Cleanup.log` (requires admin privileges for default log path).
- Returns a summary object of actions taken.
- Includes CLI wrapper script: `scripts\Fix-DiskCleanup.ps1`.

### 🧪 `Invoke-FullAudit` (Upcoming)
- High-level system scoring
- Exit codes reflect severity
- Combines system report + cleanup recommendations
---
## 🔬 Testing
### ✅ Unit Tests (Pester)
- Verifies output schema fields for `Get-SystemReport`
- Mocks WMI failures for `Get-SystemReport`
- Validates safe handling of missing data for `Get-SystemReport`
### ✅ Unit Tests (Pester) for `Fix-DiskCleanup`
- Verifies dry run logic, `CleanupPlan.json` creation, and no actual deletions.
- Verifies live run deletions, logging, and `ShouldProcess` interactions using mocks.
- Tests handling of empty/inaccessible locations and log directory creation.
### 🔄 Integration Tests (Planned)
- Future tests may involve actual file system manipulation in controlled environments.
- CI runs all unit tests across Windows and Linux.
### 📈 Code Coverage
- JaCoCo XML generated from Pester for `QAOps.psm1`
- 80% minimum threshold enforced in CI for `QAOps.psm1`
- Failing coverage fails the build
- Coverage results uploaded to CI artifacts
---
## 🧪 Usage
### As a module
```powershell
# Ensure the module is in your $env:PSModulePath or provide the full path to QAOps.psd1
Import-Module QAOps 
# Or from the project root:
# Import-Module ./modules/QAOps/QAOps.psd1 -Force

Get-SystemReport -Format JSON

Fix-DiskCleanup -DryRun -DaysOld 7
Fix-DiskCleanup -DaysOld 30 -Confirm
```
### As CLI wrapper scripts
```powershell
.\scripts\Get-SystemReport.ps1 -Format JSON
.\scripts\Fix-DiskCleanup.ps1 -DryRun -DaysOld 7
.\scripts\Fix-DiskCleanup.ps1 -DaysOld 30 # Will prompt for confirmation due to Medium ConfirmImpact
```
---
## 🔧 Project Structure
```
.
├── .github/
│   └── workflows/
│       └── windows-ci.yml      # Main CI/CD workflow
├── docs/                       # Documentation files (architecture.md, etc.)
│   └── screenshots/
├── modules/
│   └── QAOps/
│       ├── QAOps.psm1          # Core module functions (exported)
│       └── QAOps.psd1          # Module manifest
├── scripts/                    # Wrapper scripts for CLI use
│   ├── Get-SystemReport.ps1
│   ├── Fix-DiskCleanup.ps1
│   └── utils/                  # (Utility scripts, if any)
├── tests/
│   ├── Pester.Tests.ps1        # Pester tests for the module
│   └── data/                   # Test data (e.g., golden JSON files)
├── .gitattributes
├── .gitignore
├── .pre-commit-config.yaml     # For pre-commit hooks
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── Dockerfile.win              # (Optional) For Windows Nano container
├── LICENSE
├── qaops-summary.py            # (Optional) Python helper for JSON -> Rich table
└── requirements.txt            # Python dependencies
```
---
## ⚙️ CI/CD
Our Continuous Integration (CI) pipeline runs on every push and pull request via GitHub Actions.
Key features:
- **Linting**: PSScriptAnalyzer (fails on errors/warnings)
- **Testing**: Pester v5, cross-platform
- **Coverage**: Enforced ≥80% for `QAOps.psm1`, JaCoCo XML
- **Manifest Check**: `Test-ModuleManifest` on every run
- **OS Matrix**: Windows (latest, 2019), Ubuntu (latest)
- **Artifacts Uploaded**: Lint logs, test reports, coverage XML

➡️ [View GitHub Actions Workflows](https://github.com/soin8293/powershell-qops/actions)
---
## 🔄 Versioning
Current version: `v0.2.0` (See [`CHANGELOG.md`](CHANGELOG.md:1) and `modules/QAOps/QAOps.psd1`)

Next milestone: `v0.3.0` (Implement `Invoke-FullAudit`)
---
## 🤝 Contributing
Pull requests are welcome! Please see [`CONTRIBUTING.md`](CONTRIBUTING.md:1) for guidelines.
All contributors are expected to adhere to our [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md:1).
---
## 🧭 Roadmap
- ✅ `Get-SystemReport` with schema versioning and JSON output.
- ✅ `Fix-DiskCleanup` with dry-run, logging, and confirmation support.
- ⏳ `Invoke-FullAudit` orchestration command.
- ⏳ Python CLI: `qaops-summary.py` to parse JSON into console tables
- ⏳ GitHub Pages summary dashboard
- ⏳ Publish to PSGallery
---
## 📜 License
This project is licensed under the MIT License. See [`LICENSE`](LICENSE:0) for full text.