BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1') -Force
}

Describe 'Literal cleanup boundaries' {
    BeforeEach {
        Mock Add-Content -ModuleName QAOps {}
        Mock New-Item -ModuleName QAOps {}
    }

    It 'deletes exactly the old bracket-named file in the dry-run plan' {
        $root = Join-Path $TestDrive 'literal[1]'
        [System.IO.Directory]::CreateDirectory($root) | Out-Null
        $old = Join-Path $root 'item[1].txt'
        $fresh = Join-Path $root 'item1.txt'
        Set-Content -LiteralPath $old -Value 'old disposable fixture'
        Set-Content -LiteralPath $fresh -Value 'fresh disposable fixture'
        (Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-40)
        Push-Location $TestDrive
        try {
            $plan = Invoke-DiskCleanup -Locations $root -DryRun -DaysOld 30
            $plan.ItemsIdentified | Should -Be 1
            (Get-Content CleanupPlan.json -Raw | ConvertFrom-Json).Path | Should -Be $old
            $preview = Invoke-DiskCleanup -Locations $root -DaysOld 30 -WhatIf
            $preview.ItemsDeleted | Should -Be 0
            Test-Path -LiteralPath $old | Should -BeTrue
            $live = Invoke-DiskCleanup -Locations $root -DaysOld 30 -Confirm:$false
            $live.ItemsDeleted | Should -Be 1
            Test-Path -LiteralPath $old | Should -BeFalse
            Test-Path -LiteralPath $fresh | Should -BeTrue
        } finally {
            Pop-Location
        }
    }

    It 'rejects negative ages before any selection or removal' {
        { Invoke-DiskCleanup -Locations $TestDrive -DaysOld -1 } | Should -Throw
    }
}
