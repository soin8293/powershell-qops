[CmdletBinding()]
param (
    [ValidateSet('JSON', 'Object')]
    [string]$Format = 'JSON'
)

$modulePath = Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1'
Import-Module $modulePath -Force -ErrorAction Stop
Invoke-FullAudit -Format $Format
