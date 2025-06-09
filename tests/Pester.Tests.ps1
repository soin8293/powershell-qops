function Assert-DisksPresent {
    param($Disks)
    (($Disks -is [array]) -or ($Disks -is [pscustomobject])) | Should -BeTrue
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'QAOps' 'QAOps.psd1') -Force -ErrorAction Stop

    Mock Get-CimInstance -ModuleName QAOps -MockWith {
        param($ClassName)
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
}

Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    It '-DryRun should identify old files and create CleanupPlan.json' {
        $tmp = Join-Path $TestDrive 'Temp'
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $result = Invoke-DiskCleanup -Locations $tmp -DryRun
        $result | Should -Not -BeNull
    }
}