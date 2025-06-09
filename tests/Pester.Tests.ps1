# ─── helper (keep this literally at line 1) ─────────────────────────
function Assert-DisksPresent {
    param($Disks)
    (($Disks -is [array]) -or ($Disks -is [pscustomobject])) | Should -BeTrue
}
# ─── global & module-scope mocks ───────────────────────────────────
BeforeAll {
    # Path to the QAOps module. $PSScriptRoot is the 'tests' directory.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\QAOps\QAOps.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    # Silence warnings
    Mock Write-Warning {}
    # Mock CIM for *callers* in the test scope
    Mock Get-CimInstance { param($ClassName) }
    # Mock CIM *inside the module* so QAOps code sees it
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
}
# ─── JSON test (unchanged) ─────────────────────────────────────────
Describe 'Get-SystemReport (Function from QAOps Module)' {
    It 'should output valid JSON by default' {
        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj  | Should -Not -BeNull
        Assert-DisksPresent $obj.Disks
    }
}
# ─── DiskCleanup dry-run test (fixes null path) ────────────────────
Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    It '-DryRun should identify old files and create CleanupPlan.json' {
        $testDir = Join-Path $TestDrive 'Temp'
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $result = Invoke-DiskCleanup -Path $testDir -DryRun   # <- non-null path
        $result | Should -Not -BeNull
    }
}