#Requires -Version 7
[CmdletBinding()]
param (
    [string]$Path = './Coverage.xml',
    [ValidateRange(0, 100)]
    [double]$Minimum = 80
)

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Coverage report is missing: $Path"
}
[xml]$coverage = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
$counters = @($coverage.SelectNodes('/report/counter[@type="LINE"]'))
if ($counters.Count -ne 1) { throw 'Expected exactly one report-level JaCoCo LINE counter.' }
$covered = 0L
$missed = 0L
if (-not [long]::TryParse($counters[0].GetAttribute('covered'), [ref]$covered) -or
    -not [long]::TryParse($counters[0].GetAttribute('missed'), [ref]$missed) -or
    $covered -lt 0 -or $missed -lt 0 -or ($covered + $missed) -le 0) {
    throw 'Coverage report has invalid or empty line counts.'
}
$percent = 100.0 * $covered / ($covered + $missed)
if ($percent -lt $Minimum) { throw "Line coverage $percent% is below $Minimum%." }
Write-Output "Line coverage $([math]::Round($percent, 2))% meets $Minimum%."
