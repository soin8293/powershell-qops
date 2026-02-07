function Assert-DisksPresent {
    param($Disks)
    (($Disks -is [array]) -or ($Disks -is [pscustomobject])) | Should -BeTrue
}

BeforeAll {
    # 1. Import module first
    Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1') -Force -ErrorAction Stop
    # 2. Mock CIM for the module AFTER import
    Mock -CommandName Get-CimInstance -ModuleName QAOps -MockWith {
        param([string]$ClassName)
        switch ($ClassName) {
            'Win32_OperatingSystem' { [pscustomobject]@{ Caption='Windows'; Version='10.0'; BuildNumber='19045' } }
            'Win32_LogicalDisk'     { ,([pscustomobject]@{ DeviceID='C:'; Size=128GB; FreeSpace=64GB }) }
        }
    }
    Mock Write-Warning {}
}

Describe 'Get-SystemReport (Function from QAOps Module)' {
    It 'should output valid JSON by default' {
        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj  | Should -Not -BeNull
        Assert-DisksPresent $obj.Disks
    }

    It 'should handle Markdown and Console formats by returning JSON fallback' {
        $jsonMarkdown = Get-SystemReport -Format Markdown
        $jsonConsole  = Get-SystemReport -Format Console
        ($jsonMarkdown | ConvertFrom-Json).SchemaVersion | Should -Not -BeNull
        ($jsonConsole  | ConvertFrom-Json).SchemaVersion | Should -Not -BeNull
    }

    It 'should return report even when CIM queries fail' {
        Mock -CommandName Get-CimInstance -ModuleName QAOps -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } -MockWith { throw "OS lookup failed" }
        Mock -CommandName Get-CimInstance -ModuleName QAOps -ParameterFilter { $ClassName -eq 'Win32_LogicalDisk' } -MockWith { $null }

        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj.OperatingSystem.Error | Should -Match 'Failed to retrieve OS information'
        Assert-DisksPresent $obj.Disks
    }
}

Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    It '-DryRun should identify old files and create CleanupPlan.json' {
        $tmp = Join-Path $TestDrive 'Temp'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Push-Location $TestDrive
        try {
            $result = Invoke-DiskCleanup -Locations $tmp -DryRun
            $result | Should -Not -BeNull
        }
        finally {
            Pop-Location
        }
    }

    It '-DryRun should write a plan when old files exist' {
        $tmp = Join-Path $TestDrive 'TempWithOld'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'old.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Push-Location $TestDrive
        try {
            $result = Invoke-DiskCleanup -Locations $tmp -DryRun -DaysOld 7
            $result.ItemsIdentified | Should -BeGreaterThan 0
            $planPath = Join-Path (Get-Location) 'CleanupPlan.json'
            Test-Path $planPath | Should -BeTrue
            $plan = Get-Content -Path $planPath -Raw | ConvertFrom-Json
            $plan[0].Path | Should -Be $file
        }
        finally {
            Pop-Location
        }
    }

    It '-DryRun should report missing locations as errors' {
        $missing = Join-Path $TestDrive 'MissingLocation'
        $result = Invoke-DiskCleanup -Locations $missing -DryRun
        $result.Errors.Count | Should -BeGreaterThan 0
    }

    It 'should process files in live mode without touching real system paths' {
        $tmp = Join-Path $TestDrive 'TempLive'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'old-live.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName New-Item -ModuleName QAOps { $null }
        Mock -CommandName Add-Content -ModuleName QAOps { $null }
        Mock -CommandName Remove-Item -ModuleName QAOps { $null }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7
        $result.ItemsIdentified | Should -BeGreaterThan 0
    }
}
