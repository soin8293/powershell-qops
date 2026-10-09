Describe 'Cleanup wrapper' {
    It 'passes explicit locations and writes a dry-run plan without deleting files' {
        $fixture = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'input')
        $oldFile = Join-Path $fixture.FullName 'old.txt'
        Set-Content -LiteralPath $oldFile -Value 'disposable fixture'
        (Get-Item -LiteralPath $oldFile).LastWriteTime = (Get-Date).AddDays(-40)
        Push-Location $TestDrive
        try {
            $result = & (Join-Path $PSScriptRoot '..' 'scripts' 'Invoke-DiskCleanup.ps1') -Locations $fixture.FullName -DryRun -DaysOld 30
            $result.ItemsIdentified | Should -Be 1
            $result.ItemsDeleted | Should -Be 0
            Test-Path -LiteralPath $oldFile | Should -BeTrue
            (Get-Content CleanupPlan.json -Raw | ConvertFrom-Json).Path | Should -Be $oldFile
        } finally {
            Pop-Location
        }
    }
}
