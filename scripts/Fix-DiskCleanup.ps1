#Requires -Version 7
<#
.SYNOPSIS
    Cleans up temporary files by calling the Fix-DiskCleanup function from the QAOps module.
.DESCRIPTION
    This script serves as a wrapper to import the QAOps PowerShell module and execute its Fix-DiskCleanup function.
    It identifies and removes files older than a specified number of days from common temporary locations.
    Supports a DryRun mode and logs actions.
.PARAMETER DryRun
    If specified, the function will only list files that would be deleted.
.PARAMETER DaysOld
    Specifies the minimum age in days for files to be considered for deletion. Defaults to 14.
.EXAMPLE
    PS C:\> .\Fix-DiskCleanup.ps1 -DryRun -DaysOld 7
    Lists files older than 7 days in temp locations that would be deleted.
.EXAMPLE
    PS C:\> .\Fix-DiskCleanup.ps1 -DaysOld 30 -Confirm
    Prompts for confirmation before deleting files older than 30 days.
.NOTES
    This script depends on the QAOps module being available in the module path or located at '..\modules\QAOps\QAOps.psd1' relative to this script.
    Running the live cleanup (not -DryRun) for certain locations (e.g. C:\Windows\Temp) or logging to C:\ProgramData typically requires Administrator privileges.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$DaysOld = 14
)

# Determine the script's directory to reliably find the module
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ScriptDirectory -ChildPath '..\modules\QAOps\QAOps.psd1'

try {
    Import-Module -Name $ModulePath -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import the QAOps module from '$ModulePath'. Please ensure it exists and is accessible. Error: $($_.Exception.Message)"
    exit 1
}

try {
    # Pass all bound parameters from the script to the function
    Fix-DiskCleanup @PSBoundParameters
}
catch {
    # The function Fix-DiskCleanup will write its own errors or re-throw.
    Write-Error "An error occurred while executing Fix-DiskCleanup: $($_.Exception.Message)"
    exit 1 # Ensure script exits with an error code for CI
}