#Requires -Version 7
<#
.SYNOPSIS
    Collects basic system information including OS and disk usage by calling the Get-SystemReport function from the QAOps module.
.DESCRIPTION
    This script serves as a wrapper to import the QAOps PowerShell module and execute its Get-SystemReport function.
    It gathers details about the operating system (like version and build) and disk drives (like free space and total size).
    The output is typically a JSON object by default, as determined by the underlying function.
.PARAMETER Format
    Specifies the output format for the Get-SystemReport function.
    Valid values: "JSON", "Markdown", "Console" (future).
.EXAMPLE
    PS C:\> .\Get-SystemReport.ps1
    Outputs system report in JSON format.
.EXAMPLE
    PS C:\> .\Get-SystemReport.ps1 -Format JSON
    Explicitly outputs system report in JSON format.
.NOTES
    This script depends on the QAOps module being available in the module path or located at '..\modules\QAOps\QAOps.psd1' relative to this script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("JSON", "Markdown", "Console")]
    [string]$Format = "JSON" # Default to JSON, will be passed to the function
)

# Determine the script's directory to reliably find the module
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path -Path $ScriptDirectory -ChildPath '..\modules\QAOps\QAOps.psd1' # Adjusted path

try {
    Import-Module -Name $ModulePath -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import the QAOps module from '$ModulePath'. Please ensure it exists and is accessible. Error: $($_.Exception.Message)"
    exit 1
}

try {
    # Pass all bound parameters from the script to the function
    Get-SystemReport @PSBoundParameters
}
catch {
    # The function Get-SystemReport will write its own errors.
    # This catch is for any critical failure in invoking the function itself or if it re-throws.
    Write-Error "An error occurred while executing Get-SystemReport: $($_.Exception.Message)"
    exit 1 # Ensure script exits with an error code for CI
}