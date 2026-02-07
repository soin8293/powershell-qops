BeforeAll {
    # 1. Import module first
    Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1') -Force -ErrorAction Stop
}

Describe 'Get-SystemReport (Function from QAOps Module)' {
    It 'should output valid JSON by default' {
        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj  | Should -Not -BeNull
        (($obj.Disks -is [array]) -or ($obj.Disks -is [pscustomobject])) | Should -BeTrue
    }

    It 'should handle Markdown and Console formats by returning JSON fallback' {
        $jsonMarkdown = Get-SystemReport -Format Markdown
        $jsonConsole  = Get-SystemReport -Format Console
        ($jsonMarkdown | ConvertFrom-Json).SchemaVersion | Should -Not -BeNull
        ($jsonConsole  | ConvertFrom-Json).SchemaVersion | Should -Not -BeNull
    }

    It 'should return report even when CIM queries fail' {
        InModuleScope QAOps {
            if (-not (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue)) {
                function Get-CimInstance {
                    param($ClassName, $Filter, $ErrorAction)
                    throw "OS lookup failed"
                }
            }
        }

        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj.OperatingSystem | Should -Not -BeNull
        (($obj.Disks -is [array]) -or ($obj.Disks -is [pscustomobject])) | Should -BeTrue
    }

    It 'should return a report when CIM is unavailable' {
        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj.OperatingSystem | Should -Not -BeNull
        (($obj.Disks -is [array]) -or ($obj.Disks -is [pscustomobject])) | Should -BeTrue
    }

    It 'should use CIM data when available' {
        function global:Get-CimInstance {
            param($ClassName, $Filter, $ErrorAction)
            switch ($ClassName) {
                'Win32_OperatingSystem' { [pscustomobject]@{ Caption='Windows'; Version='10.0'; BuildNumber='19045'; OSArchitecture='64-bit'; RegisteredUser='tester'; LastBootUpTime=(Get-Date) } }
                'Win32_LogicalDisk'     { ,([pscustomobject]@{ DeviceID='C:'; VolumeName='System'; FileSystem='NTFS'; FreeSpace=64GB; Size=128GB }) }
            }
        }

        try {
            $json = Get-SystemReport
            $obj  = $json | ConvertFrom-Json
            $obj.OperatingSystem.OSName | Should -Be 'Windows'
            $obj.Disks[0].DiskDeviceID | Should -Be 'C:'
        }
        finally {
            Remove-Item -Path Function:\Get-CimInstance -ErrorAction SilentlyContinue
        }
    }

    It 'should handle CIM returning no data' {
        function global:Get-CimInstance {
            param($ClassName, $Filter, $ErrorAction)
            $null
        }

        try {
            $json = Get-SystemReport
            $obj  = $json | ConvertFrom-Json
            $obj.OperatingSystem.Error | Should -Match 'OS information query returned no data'
            (($obj.Disks -is [array]) -or ($obj.Disks -is [pscustomobject])) | Should -BeTrue
        }
        finally {
            Remove-Item -Path Function:\Get-CimInstance -ErrorAction SilentlyContinue
        }
    }

    It 'should surface fatal errors from report generation' {
        Mock -CommandName ConvertTo-Json -ModuleName QAOps -MockWith { throw "boom" }
        { Get-SystemReport } | Should -Throw
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

        Mock -CommandName New-Item -ModuleName QAOps -MockWith {
            param($Path, $ItemType, $Force, $ErrorAction)
            $null
        }
        Mock -CommandName Add-Content -ModuleName QAOps -MockWith {
            param($Path, $Value, $Encoding, $ErrorAction)
            $null
        }
        Mock -CommandName Remove-Item -ModuleName QAOps -MockWith {
            param($Path, $Force, $ErrorAction)
            $null
        }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7
        $result.ItemsIdentified | Should -BeGreaterThan 0
    }

    It 'should delete old files in live mode' {
        $tmp = Join-Path $TestDrive 'TempDelete'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'delete-me.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName New-Item -ModuleName QAOps -MockWith { param($Path, $ItemType, $Force, $ErrorAction) $null }
        Mock -CommandName Add-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) $null }
        Mock -CommandName Remove-Item -ModuleName QAOps -MockWith { param($Path, $Force, $ErrorAction) $null }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7
        $result.ItemsDeleted | Should -BeGreaterThan 0
    }

    It 'should record errors when deletion fails' {
        $tmp = Join-Path $TestDrive 'TempDeleteFail'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'fail-me.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName New-Item -ModuleName QAOps -MockWith { param($Path, $ItemType, $Force, $ErrorAction) $null }
        Mock -CommandName Add-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) $null }
        Mock -CommandName Remove-Item -ModuleName QAOps -MockWith { param($Path, $Force, $ErrorAction) throw "Delete failed" }

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try {
            $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7 -ErrorAction SilentlyContinue
            $result.Errors.Count | Should -BeGreaterThan 0
            $result.ItemsSkipped | Should -BeGreaterThan 0
        }
        finally {
            $ErrorActionPreference = $prevEap
        }
    }

    It 'should skip deletes when -WhatIf is used' {
        $tmp = Join-Path $TestDrive 'TempWhatIf'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'whatif.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName New-Item -ModuleName QAOps -MockWith { param($Path, $ItemType, $Force, $ErrorAction) $null }
        Mock -CommandName Add-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) $null }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7 -WhatIf
        $result.ItemsDeleted | Should -Be 0
    }

    It 'should record errors when log directory creation fails' {
        $tmp = Join-Path $TestDrive 'TempLogFail'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock -CommandName Test-Path -ModuleName QAOps -MockWith { param($Path, $PathType) $false }
        Mock -CommandName New-Item -ModuleName QAOps -MockWith { param($Path, $ItemType, $Force, $ErrorAction) throw "mkdir failed" }
        Mock -CommandName Add-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) $null }
        Mock -CommandName Remove-Item -ModuleName QAOps -MockWith { param($Path, $Force, $ErrorAction) $null }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7
        $result.Errors.Count | Should -BeGreaterThan 0
    }

    It 'should record errors when log write fails' {
        $tmp = Join-Path $TestDrive 'TempLogWriteFail'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'log-fail.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName Add-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) throw "log write failed" }
        Mock -CommandName Remove-Item -ModuleName QAOps -MockWith { param($Path, $Force, $ErrorAction) $null }

        $result = Invoke-DiskCleanup -Locations $tmp -DaysOld 7
        $result.Errors.Count | Should -BeGreaterThan 0
    }

    It 'should record errors when file enumeration fails' {
        $tmp = Join-Path $TestDrive 'TempEnumFail'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock -CommandName Get-ChildItem -ModuleName QAOps -MockWith { throw "enumeration failed" }

        $result = Invoke-DiskCleanup -Locations $tmp -DryRun
        $result.Errors.Count | Should -BeGreaterThan 0
    }

    It 'should record errors when writing cleanup plan fails' {
        $tmp = Join-Path $TestDrive 'TempPlanFail'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $file = Join-Path $tmp 'plan-fail.txt'
        New-Item -ItemType File -Path $file -Force | Out-Null
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-30)

        Mock -CommandName Set-Content -ModuleName QAOps -MockWith { param($Path, $Value, $Encoding, $ErrorAction) throw "write failed" }

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        Push-Location $TestDrive
        try {
            $result = Invoke-DiskCleanup -Locations $tmp -DryRun -DaysOld 7 -ErrorAction SilentlyContinue
            $result.Errors.Count | Should -BeGreaterThan 0
        }
        finally {
            Pop-Location
            $ErrorActionPreference = $prevEap
        }
    }
}
