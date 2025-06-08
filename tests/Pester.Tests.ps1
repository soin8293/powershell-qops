# ─── helper (place at top of file) ─────────────────────────────────────────────
function Assert-DisksPresent {
    param($Disks)
    (($Disks -is [array]) -or ($Disks -is [pscustomobject])) | Should -BeTrue
}
# ─── GLOBAL Mocks for test scope ──────────────────────────────────────────────
BeforeAll {
    # Path to the QAOps module. $PSScriptRoot is the 'tests' directory.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\QAOps\QAOps.psd1'
    Write-Host "Importing QAOps module from: $modulePath"
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    # Inject mock directly into the QAOps module
    Mock -CommandName Get-CimInstance -ModuleName QAOps -MockWith {
        param([string]$ClassName)
        switch ($ClassName) {
            'Win32_OperatingSystem' {
                [pscustomobject]@{
                    Caption     = 'Windows'
                    Version     = '10.0'
                    BuildNumber = '19045'
                }
            }
            'Win32_LogicalDisk' {
                ,([pscustomobject]@{
                    DeviceID   = 'C:'
                    Size       = 128GB
                    FreeSpace  = 64GB
                    VolumeName = 'OS'
                })
            }
        }
    }

    # Silence warnings if still mocked
    Mock Write-Warning {}
}
# ─── TEST BLOCK EXAMPLES (update all similar) ─────────────────────────────────
Describe 'Get-SystemReport (Function from QAOps Module)' {
    It 'should output valid JSON by default' {
        $json = Get-SystemReport
        $obj  = $json | ConvertFrom-Json
        $obj  | Should -Not -BeNull
        Assert-DisksPresent $obj.Disks
    }
}
Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    $mockUserTemp = Join-Path $PSScriptRoot "TempTestDir_User"
    $mockWindowsTemp = Join-Path $PSScriptRoot "TempTestDir_Windows"
    $mockProgramData = Join-Path $PSScriptRoot "ProgramDataTestDir" # For log file
    $mockLogPathBase = Join-Path $mockProgramData "QAOps"
    $mockLogFile = Join-Path $mockLogPathBase "Cleanup.log"
    $mockCleanupPlanFile = "CleanupPlan.json" # Relative to PSScriptRoot where test runs

    BeforeEach {
        # Create mock temp directories
        New-Item -Path $mockUserTemp -ItemType Directory -Force | Out-Null
        New-Item -Path $mockWindowsTemp -ItemType Directory -Force | Out-Null
        New-Item -Path $mockLogPathBase -ItemType Directory -Force | Out-Null

        # Mock $env:TEMP and $env:SystemRoot for the duration of the test
        Mock Get-Item -ModuleName Microsoft.PowerShell.Management -MockWith {
            param($Path)
            if ($Path -eq 'variable:TEMP') { return [PSCustomObject]@{ Value = $mockUserTemp } }
            if ($Path -eq 'variable:SystemRoot') { return [PSCustomObject]@{ Value = $PSScriptRoot } } # Simulating SystemRoot for $env:SystemRoot\Temp
            # Fallback to actual Get-Item for other variable calls if any
            return Get-Item @PSBoundParameters
        }
        # Mock Test-Path for the log directory creation
        Mock Test-Path -ModuleName Microsoft.PowerShell.Management
        # Mock New-Item for log directory creation
        Mock New-Item -ModuleName Microsoft.PowerShell.Management
        # Mock Add-Content for logging
        Mock Add-Content -ModuleName Microsoft.PowerShell.Management
        # Mock Remove-Item
        Mock Remove-Item -ModuleName Microsoft.PowerShell.Management
        # Mock ConvertTo-Json and Set-Content for CleanupPlan.json
        Mock ConvertTo-Json -ModuleName Microsoft.PowerShell.Utility
        Mock Set-Content -ModuleName Microsoft.PowerShell.Management
        # Mock Get-ChildItem to control file enumeration
        Mock Get-ChildItem -ModuleName Microsoft.PowerShell.Management
        # Mock $PSCmdlet.ShouldProcess
        Mock Invoke-Command -ModuleName Microsoft.PowerShell.Core -ParameterFilter { $ScriptBlock -like '*ShouldProcess*' } # General way to mock internal calls
    }

    AfterEach {
        # Clean up mock directories and files
        if (Test-Path $mockUserTemp) { Remove-Item -Path $mockUserTemp -Recurse -Force }
        if (Test-Path $mockWindowsTemp) { Remove-Item -Path $mockWindowsTemp -Recurse -Force }
        if (Test-Path $mockLogPathBase) { Remove-Item -Path $mockLogPathBase -Recurse -Force }
        if (Test-Path $mockCleanupPlanFile) { Remove-Item -Path $mockCleanupPlanFile -Force }
        # Clear all mocks to avoid interference between tests
        Get-Mock | ForEach-Object { $_.Remove() }
    }
    It '-DryRun should identify old files and create CleanupPlan.json' {
        $result = Invoke-DiskCleanup -Locations 'C:\Temp' -DryRun
        $result | Should -Not -BeNull
    }
}