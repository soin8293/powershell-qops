# PowerShell QOps

PowerShell 7 commands for operating-system and disk reporting, read-only capacity audits, and explicit temporary-file cleanup. Windows and Ubuntu are covered by the GitHub Actions workflow.

[![Build](https://github.com/soin8293/powershell-qops/actions/workflows/windows-ci.yml/badge.svg)](https://github.com/soin8293/powershell-qops/actions/workflows/windows-ci.yml)

## Start with a read-only report

From the repository root in PowerShell 7:

```powershell
Import-Module ./modules/QAOps/QAOps.psd1 -Force
Get-SystemReport -Format JSON
Invoke-FullAudit -Format Object
# Equivalent wrapper:
./scripts/Invoke-FullAudit.ps1
```

`Get-SystemReport` collects operating-system and disk information. Windows uses CIM when available; other environments fall back to basic OS information and filesystem drives. RAM and network reporting are not implemented. The `Markdown` and `Console` format options currently warn and return JSON.

`Invoke-FullAudit` adds disk-capacity findings to that report. Free space at or below 10% is Critical; above 10% and at or below 20% is Warning. Its status is `Critical`, `NeedsAttention`, or `Healthy` according to the collected findings. `Healthy` means no findings from these limited checks, not complete host health or security assurance. Collection errors appear in the report. The audit never invokes cleanup.

- [Architecture and data flow](docs/architecture.md)
- [Versioned audit schema](schemas/full-audit.schema.json)
- [Synthetic example report](examples/full-audit.sample.json)

## Preview cleanup of a chosen directory

Both the module and wrapper require explicit `-Locations`. Use a directory you intend to clean; nothing chooses system directories for you.

```powershell
# Replace ./scratch with your intended directory before running.
Invoke-DiskCleanup -Locations ./scratch -DryRun -DaysOld 7
# Equivalent wrapper:
./scripts/Invoke-DiskCleanup.ps1 -Locations ./scratch -DryRun -DaysOld 7
```

Dry run writes `CleanupPlan.json` in the current directory and does not delete files. Selection uses `LastWriteTime`, recursively, for files older than the cutoff. Review the generated plan and the returned errors before running live cleanup:

```powershell
Invoke-DiskCleanup -Locations ./scratch -DaysOld 30 -Confirm
```

Live cleanup uses PowerShell `ShouldProcess`; request `-Confirm` explicitly when you want prompts. `ConfirmImpact = Medium` does not guarantee a prompt under default preferences. `-WhatIf` skips deletions but may still create/write the cleanup log, so use `-DryRun` for a deletion preview without live logging. Live logs use `C:/ProgramData/QAOps/Cleanup.log` on Windows (permissions may be required), or `QAOps/Cleanup.log` under the system temporary directory elsewhere. Failures are returned in the summary; enumeration may omit inaccessible files.

## Repository layout

```text
modules/QAOps/             Module manifest and three exported commands
scripts/                  CLI wrappers and documentation validator
schemas/                  Full-audit JSON Schema
examples/                 Synthetic sample output
docs/architecture.md      Implementation and operational boundaries
tests/                    Pester tests
.github/workflows/        Windows and Ubuntu CI
```

Unused empty container, Python-helper, utility and pre-commit scaffolds have been removed. There is no Python dependency or container requirement for the module.

## Development and checks

Install Pester 5 and PSScriptAnalyzer in your development environment, then run:

```powershell
Test-ModuleManifest ./modules/QAOps/QAOps.psd1
./scripts/Test-Documentation.ps1
Invoke-Pester -Path ./tests -Output Detailed
Invoke-ScriptAnalyzer -Path ./modules/QAOps -Recurse
Invoke-ScriptAnalyzer -Path ./scripts -Recurse
```

CI runs the manifest, documentation, linter and Pester checks on Windows and Ubuntu. It also generates JaCoCo coverage for the module and checks the 80% threshold. Tests use synthetic data and mocks; they do not establish production deployment or adoption. Release packaging is triggered only by version tags.

Current tagged version: `v0.3.0`. See [change history](CHANGELOG.md). Container packaging, a Python table renderer, a hosted dashboard and PowerShell Gallery publication remain possible future work; they are not shipped capabilities.

## Contributing and license

See [contribution guidelines](CONTRIBUTING.md), the [code of conduct](CODE_OF_CONDUCT.md), and the [MIT license](LICENSE).
