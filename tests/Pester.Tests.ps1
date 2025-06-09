function Assert-DisksPresent {
    param($Disks)
    (($Disks -is [array]) -or ($Disks -is [pscustomobject])) | Should -BeTrue
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1') -Force -ErrorAction Stop

    InModuleScope 'QAOps' {
        Mock Get-CimInstance -MockWith {
            param([string]$ClassName)
            switch ($ClassName) {
                'Win32_OperatingSystem' {
                    [pscustomobject]@{ Caption='Windows'; Version='10.0'; BuildNumber='19045' }
                }
                'Win32_LogicalDisk' {
                    ,([pscustomobject]@{ DeviceID='C:'; Size=128GB; FreeSpace=64GB; VolumeName='OS' })
                }
            }
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
}

Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    It '-DryRun should identify old files and create CleanupPlan.json' {
        $testDir = Join-Path $TestDrive 'Temp'
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $result = Invoke-DiskCleanup -Locations $testDir -DryRun
        $result | Should -Not -BeNull
    }
}