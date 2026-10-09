# Architecture

QOps is a PowerShell 7 module with three exported functions. The CLI scripts import the same module relative to their own location and pass parameters through; there is no separate service, database, Python runtime or web dashboard.

## Data flow

```text
Get-SystemReport wrapper -> Get-SystemReport -> OS + disk data -> JSON
Invoke-FullAudit wrapper -> Invoke-FullAudit -> Get-SystemReport
                                            -> capacity findings -> JSON / object
Invoke-DiskCleanup wrapper -> Invoke-DiskCleanup -> explicit directories
                                                -> dry-run plan OR confirmed deletion + log
```

Implementation: [QAOps.psm1](../modules/QAOps/QAOps.psm1). Exports and version: [QAOps.psd1](../modules/QAOps/QAOps.psd1).

## Reporting and audit

`Get-SystemReport` uses `Get-CimInstance` when present, otherwise basic environment/runtime OS fields and `Get-PSDrive`. The report contains schema version, timestamp, operating-system information and disk capacities. Collection failures are retained as error information or an empty disk collection. JSON is the implemented output; the Markdown and Console options fall back to JSON with a warning.

`Invoke-FullAudit` consumes that JSON and calculates free disk percentage. At most 10% free creates a Critical finding; above 10% through 20% creates a Warning. Unavailable OS information creates a Warning. Disks with nonpositive total capacity are skipped. No findings produces Healthy, so missing disk data is not evidence that every disk is healthy. The returned audit includes findings, counts and the underlying report. It does not execute cleanup.

The [audit schema](../schemas/full-audit.schema.json) and [synthetic example](../examples/full-audit.sample.json) describe the public data contract. Reports can contain local usernames, volume names and environment details; review them before sharing.

## Cleanup boundary

`Invoke-DiskCleanup` requires caller-supplied directories. It recursively enumerates files and selects those with `LastWriteTime` earlier than the age cutoff. It returns scanned, identified, deleted and skipped counts, output paths and errors.

- `-DryRun` writes a JSON plan in the working directory and does not delete files.
- Live mode asks `ShouldProcess` for each file. Use `-Confirm` for explicit prompts or `-WhatIf` to skip deletion. WhatIf can still write logs.
- Windows logs use `C:/ProgramData/QAOps/Cleanup.log`; other platforms use the temporary directory's `QAOps/Cleanup.log`.
- A plan is an observation, not a transaction or a reservation of files. Live execution enumerates again; there is no rollback or restore mechanism.
- Inaccessible enumeration entries can be omitted. Counts describe collected data, not guaranteed coverage of a filesystem.

Use bounded disposable fixtures when testing cleanup. The module is not a filesystem sandbox, backup tool or automatic remediation service.

## Verification

[The CI workflow](../.github/workflows/windows-ci.yml) validates the module manifest, checks documentation, lints PowerShell, runs [Pester tests](../tests/Pester.Tests.ps1), and evaluates module coverage on Windows and Ubuntu. The tests use controlled fixtures/mocks. Coverage and green CI do not establish production ownership or real-user outcomes.
