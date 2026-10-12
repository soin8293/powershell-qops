# Read-only operations pilot

## Current engineering work

Import the module and run Invoke-FullAudit -Format Object. Inspect collection errors before interpreting Healthy. Retain reports privately because they describe the host. Compare disk findings with Get-SystemReport and record the date, module revision and environment. Cleanup is a separate opt-in operation: preview explicit disposable Locations with -DryRun, review CleanupPlan.json, then use -WhatIf or -Confirm as appropriate.

## Next operational acceptance

A recurring host-check task and operator, a baseline manual inspection time, and repeated observations over an agreed period. Record incomplete collection, capacity changes and interventions. Do not infer uptime or security from the limited audit status. Cloud provisioning is justified only if this workload requires it.

Implementation, automated checks and synthetic drills establish bounded behavior.
An operational record must separately identify the problem, requirements, exact
version/environment, deployment, upgrade/rollback, repeated use and measured outcome.
Those lifecycle fields are pending until actual use supplies evidence.

## Change and recovery

Extend this project before creating another repository for a related capability.
Add cloud hosting, infrastructure as code or monitoring only for a demonstrated
workload requirement. Preserve the previous version and configuration; reproduce
failures in a disposable environment, revert the scoped change if acceptance fails,
and record any lost in-memory state or required operator recovery. Never test
cleanup against personal data or publish raw host, customer or session records.
