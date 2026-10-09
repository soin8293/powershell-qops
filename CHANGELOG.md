# Changelog

## Documentation and wrapper repair - 2026-10-08

- Corrected the coverage gate to read JaCoCo attributes and fail on missing/invalid reports, with threshold regressions.
- Added the architecture guide and a CI check for empty documents and broken local links.
- Corrected contribution links, cleanup examples, confirmation behavior and feature descriptions.
- Added explicit required `Locations` forwarding to the cleanup wrapper, with a disposable-file dry-run test.
- Removed six unused empty container, Python, utility and pre-commit scaffolds. Historical entries below describe the original scaffold, not current capabilities.

## [0.3.0] - 2026-08-23

- Added read-only `Invoke-FullAudit` orchestration.
- Added deterministic capacity findings and a stable JSON Schema.
- Added synthetic example output and Pester coverage for audit states.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Invoke-DiskCleanup` feature:
    - New function `Invoke-DiskCleanup` in `QAOps.psm1` to clean temporary files based on age.
    - Supports `-DryRun` mode to output a `CleanupPlan.json` without deleting files.
    - Live mode uses `ShouldProcess` for confirmation and logs actions to `%ProgramData%\QAOps\Cleanup.log`.
    - Includes wrapper script `scripts/Fix-DiskCleanup.ps1`.
- Pester tests for `Invoke-DiskCleanup`:
    - Unit tests for dry run, live run (deletion and skipping), logging, and edge cases using mocks.
- Updated `QAOps.psd1` to export `Invoke-DiskCleanup`.

## [0.1.0] - YYYY-MM-DD

### Added
- Initial `Get-SystemReport` feature:
    - Collects OS and disk information.
    - Outputs to JSON with schema versioning.
    - Includes wrapper script `scripts/Get-SystemReport.ps1`.
- `QAOps` PowerShell module (`QAOps.psm1` and `QAOps.psd1`):
    - `Get-SystemReport` implemented as an exported function.
    - Module manifest includes version, author, license, project URI, tags, and initial release notes.
- Pester tests for `Get-SystemReport`:
    - Unit tests covering basic execution, JSON output, schema validation.
    - Mocking for WMI failures and no-disk scenarios.
- GitHub Actions CI workflow (`.github/workflows/windows-ci.yml`):
    - Validates module manifest.
    - Lints PowerShell code using PSScriptAnalyzer.
    - Runs Pester tests.
    - Enforces 80% code coverage (JaCoCo XML output).
    - Runs on Windows (latest, 2019) and Ubuntu (latest).
    - Uploads lint results, test results (NUnit XML), and coverage reports as artifacts.
- `README.md` with project overview, features, usage, CI details, and badges.
- `LICENSE` file (MIT).
- `.pre-commit-config.yaml` for basic pre-commit hooks (placeholder, actual hooks to be defined).
- `Dockerfile.win` (placeholder for Windows Nano container).
- `qaops-summary.py` (placeholder for Python helper).
- `requirements.txt` (placeholder for Python dependencies).
- Basic folder structure including `docs/`, `modules/`, `scripts/`, `tests/`.

### Changed
- N/A (Initial Release)

### Fixed
- N/A (Initial Release)

*(Note: Replace YYYY-MM-DD with the actual release date for 0.1.0)*
