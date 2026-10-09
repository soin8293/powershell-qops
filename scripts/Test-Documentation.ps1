#Requires -Version 7
[CmdletBinding()]
param()

$repoRoot = Split-Path $PSScriptRoot -Parent
$documents = @('README.md', 'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md', 'CHANGELOG.md')
$documents += Get-ChildItem (Join-Path $repoRoot 'docs') -Filter '*.md' -Recurse -File |
    ForEach-Object { [IO.Path]::GetRelativePath($repoRoot, $_.FullName) }
$failures = [Collections.Generic.List[string]]::new()
foreach ($relative in $documents) {
    $document = Join-Path $repoRoot $relative
    $content = Get-Content -LiteralPath $document -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        $failures.Add("Empty document: $relative")
        continue
    }
    $prose = [regex]::Replace($content, '(?s)```.*?```', '')
    foreach ($match in [regex]::Matches($prose, '\]\(([^\s)]+)\)')) {
        $target = $match.Groups[1].Value.Trim('<', '>')
        if ($target -match '^(https?://|mailto:|#)') { continue }
        $target = [Uri]::UnescapeDataString(($target -split '[#?]', 2)[0])
        $resolved = Join-Path (Split-Path $document -Parent) $target
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failures.Add("Broken link in ${relative}: $target")
        }
    }
}
if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
Write-Output "Documentation checks passed for $($documents.Count) files."
