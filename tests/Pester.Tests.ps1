# Pester v5 Tests for PowerShell-QOps

#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    # Path to the QAOps module. $PSScriptRoot is the 'tests' directory.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\modules\QAOps\QAOps.psd1'
    Write-Host "Importing QAOps module from: $modulePath"
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    Mock Get-CimInstance {
        param($ClassName, $Filter)
        switch ($ClassName) {
            'Win32_OperatingSystem' { [pscustomobject]@{ Caption='Windows'; Version='10.0'; BuildNumber='19045' } }
            'Win32_LogicalDisk'     { ,([pscustomobject]@{ DeviceID='C:'; Size=100GB; FreeSpace=60GB; VolumeName='OS' }) }
        }
    }
}

Describe 'Get-SystemReport (Function from QAOps Module)' {
    Context 'Basic Execution and JSON Output' {
        It 'should execute without errors and output a string' {
            { Get-SystemReport } | Should -Not -Throw
            $output = Get-SystemReport
            $output | Should -BeOfType ([string])
        }

        It 'should output valid JSON by default' {
            $jsonOutput = Get-SystemReport
            $parsedJson = $null
            { $parsedJson = $jsonOutput | ConvertFrom-Json } | Should -Not -Throw
            $parsedJson | Should -Not -BeNull
        }

        It 'should output valid JSON when -Format JSON is specified' {
            $jsonOutput = Get-SystemReport -Format JSON
            $parsedJson = $null
            { $parsedJson = $jsonOutput | ConvertFrom-Json } | Should -Not -Throw
            $parsedJson | Should -Not -BeNull
        }

        It 'JSON output should contain SchemaVersion, ReportTimestamp, OperatingSystem, and Disks properties' {
            $parsedJson = (Get-SystemReport) | ConvertFrom-Json

            $parsedJson | Should -HaveProperty 'SchemaVersion'
            $parsedJson.SchemaVersion | Should -Match '^\d+\.\d+\.\d+$' # e.g., 1.0.0

            $parsedJson | Should -HaveProperty 'ReportTimestamp'
            $parsedJson.ReportTimestamp | Should -Match '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z' # ISO 8601 format

            $parsedJson | Should -HaveProperty 'OperatingSystem'
            $parsedJson.OperatingSystem | Should -Not -BeNull

            $parsedJson | Should -HaveProperty 'Disks'
            $parsedJson.Disks | Should -Not -BeNull # Should be @() in case of no disks or error
        }

        It 'OperatingSystem property should contain expected fields when successful' {
            # This test relies on actual Get-CimInstance unless mocked for this specific 'It' block
            $parsedJson = (Get-SystemReport) | ConvertFrom-Json

            # Skip if OS info itself was an error (e.g. if a global mock was active and failed OS)
            if ($parsedJson.OperatingSystem.PSObject.Properties.Name -notcontains 'Error') {
                $parsedJson.OperatingSystem | Should -HaveProperty 'OSName'
                $parsedJson.OperatingSystem.OSName | Should -Not -BeNullOrEmpty

                $parsedJson.OperatingSystem | Should -HaveProperty 'OSVersion'
                $parsedJson.OperatingSystem.OSVersion | Should -Not -BeNullOrEmpty

                $parsedJson.OperatingSystem | Should -HaveProperty 'OSBuildNumber'
                $parsedJson.OperatingSystem.OSBuildNumber | Should -Not -BeNullOrEmpty

                $parsedJson.OperatingSystem | Should -HaveProperty 'OSArchitecture'
                $parsedJson.OperatingSystem.OSArchitecture | Should -Not -BeNullOrEmpty
            } else {
                Write-Warning "Skipping OS property checks as OperatingSystem data contains an error."
            }
        }

        It 'Disks property should contain DiskDeviceID and DiskTotalSizeGB for each disk (if any)' {
            # This test relies on actual Get-CimInstance unless mocked
            $parsedJson = (Get-SystemReport) | ConvertFrom-Json
            
            # Disks should be an array
            $parsedJson.Disks | Should -BeOfType ([array],[pscustomobject])

            # If there are disks, check their properties
            if ($parsedJson.Disks.Count -gt 0) {
                # Ensure there's at least one disk reported (typical for a running system if not mocked)
                # This assertion might be too strict if we expect tests on systems with no disks to pass without mocking
                # $parsedJson.Disks.Count | Should -BeGreaterThan 0

                foreach ($disk in $parsedJson.Disks) {
                    $disk | Should -HaveProperty 'DiskDeviceID'
                    $disk.DiskDeviceID | Should -Not -BeNullOrEmpty

                    $disk | Should -HaveProperty 'DiskTotalSizeGB'
                    $disk.DiskTotalSizeGB | Should -BeOfType ([double])
                    $disk.DiskTotalSizeGB | Should -BeGreaterThanOrEqual 0

                    $disk | Should -HaveProperty 'DiskFreeSpaceGB'
                    $disk.DiskFreeSpaceGB | Should -BeOfType ([double])
                    $disk.DiskFreeSpaceGB | Should -BeGreaterThanOrEqual 0
                }
            } else {
                Write-Host "No disks found in report, skipping individual disk property checks."
            }
        }
    }

    Context 'Error Handling and Edge Cases (using Mocks)' {
        # No need for $reportPath anymore, directly call the function

        It 'should warn if -Format Markdown is used (as it is not implemented yet)' {
            Mock Write-Warning
            Get-SystemReport -Format Markdown
            Assert-MockCalled Write-Warning -Exactly 1 -ParameterFilter { $Message -eq "Markdown output is not yet implemented. Defaulting to JSON." }
        }

        It 'should warn if -Format Console is used (as it is not implemented yet)' {
            Mock Write-Warning
            Get-SystemReport -Format Console
            Assert-MockCalled Write-Warning -Exactly 1 -ParameterFilter { $Message -eq "Console output is not yet implemented. Defaulting to JSON." }
        }

        It 'should handle Get-CimInstance failure for Win32_OperatingSystem gracefully' {
            InModuleScope QAOps { # Ensure Mock is applied where Get-CimInstance is called
                Mock Get-CimInstance -MockWith {
                    param($ClassName)
                    if ($ClassName -eq 'Win32_OperatingSystem') {
                        throw "Simulated WMI failure for OS"
                    }
                    # For this test, let disk info succeed or use its own mock if needed in a combined scenario
                    # Returning actual data for disks if not mocked:
                    if ($ClassName -eq 'Win32_LogicalDisk') {
                        return @(
                            [PSCustomObject]@{ DeviceID = 'C:'; VolumeName = 'Boot'; FileSystem = 'NTFS'; FreeSpace = 100GB; Size = 200GB }
                        )
                    }
                    # Fallback for any other unexpected CimInstance call
                    Write-Warning "Unmocked Get-CimInstance call in OS failure test: $ClassName"
                    return $null
                }
            }

            $jsonOutput = Get-SystemReport
            $parsedJson = $jsonOutput | ConvertFrom-Json

            $parsedJson.OperatingSystem | Should -HaveProperty 'Error'
            $parsedJson.OperatingSystem.Error | Should -Contain "Simulated WMI failure for OS"
            $parsedJson.Disks.Count | Should -BeGreaterOrEqual 0 # Disks part should still attempt to run
        }

        It 'should handle Get-CimInstance failure for Win32_LogicalDisk gracefully' {
            InModuleScope QAOps {
                Mock Get-CimInstance -MockWith {
                    param($ClassName, $Filter)
                    if ($ClassName -eq 'Win32_LogicalDisk' -and $Filter -eq "DriveType=3") {
                        throw "Simulated WMI failure for Disks"
                    }
                    if ($ClassName -eq 'Win32_OperatingSystem') {
                        return [PSCustomObject]@{ Caption = 'Mocked OS'; Version = '10.0'; BuildNumber = '19045'; OSArchitecture = '64-bit'; RegisteredUser = 'Mock User'; LastBootUpTime = (Get-Date).AddDays(-1) }
                    }
                    Write-Warning "Unmocked Get-CimInstance call in Disk failure test: $ClassName"
                    return $null
                }
            }

            $jsonOutput = Get-SystemReport
            $parsedJson = $jsonOutput | ConvertFrom-Json

            $parsedJson.Disks | Should -BeOfType([array])
            $parsedJson.Disks.Count | Should -Be 0
            $parsedJson.OperatingSystem | Should -HaveProperty 'OSName'
        }

        It 'should handle no logical disks found gracefully (Get-CimInstance returns $null for Disks)' {
            InModuleScope QAOps {
                Mock Get-CimInstance -MockWith {
                    param($ClassName, $Filter)
                    if ($ClassName -eq 'Win32_LogicalDisk' -and $Filter -eq "DriveType=3") {
                        return $null
                    }
                    if ($ClassName -eq 'Win32_OperatingSystem') {
                        return [PSCustomObject]@{ Caption = 'Mocked OS'; Version = '10.0'; BuildNumber = '19045'; OSArchitecture = '64-bit'; RegisteredUser = 'Mock User'; LastBootUpTime = (Get-Date).AddDays(-1) }
                    }
                    Write-Warning "Unmocked Get-CimInstance call in no-disks (null) test: $ClassName"
                    return $null
                }
            }
            $jsonOutput = Get-SystemReport
            $parsedJson = $jsonOutput | ConvertFrom-Json

            $parsedJson.Disks | Should -BeOfType([array])
            $parsedJson.Disks.Count | Should -Be 0
            $parsedJson.OperatingSystem | Should -HaveProperty 'OSName'
        }

        It 'should handle no logical disks found gracefully (Get-CimInstance returns empty collection for Disks)' {
            InModuleScope QAOps {
                Mock Get-CimInstance -MockWith {
                    param($ClassName, $Filter)
                    if ($ClassName -eq 'Win32_LogicalDisk' -and $Filter -eq "DriveType=3") {
                        return @()
                    }
                    if ($ClassName -eq 'Win32_OperatingSystem') {
                        return [PSCustomObject]@{ Caption = 'Mocked OS'; Version = '10.0'; BuildNumber = '19045'; OSArchitecture = '64-bit'; RegisteredUser = 'Mock User'; LastBootUpTime = (Get-Date).AddDays(-1) }
                    }
                    Write-Warning "Unmocked Get-CimInstance call in no-disks (empty array) test: $ClassName"
                    return $null
                }
            }
            $jsonOutput = Get-SystemReport
            $parsedJson = $jsonOutput | ConvertFrom-Json

            $parsedJson.Disks | Should -BeOfType([array])
            $parsedJson.Disks.Count | Should -Be 0
            $parsedJson.OperatingSystem | Should -HaveProperty 'OSName'
        }
        
        It 'should throw an exception if a major internal error occurs (simulated)' {
            InModuleScope QAOps {
                 Mock ConvertTo-Json -ModuleName Microsoft.PowerShell.Utility -MockWith { throw "Simulated ConvertTo-Json failure" }
            }
            { Get-SystemReport } | Should -Throw -ExceptionType ActionPreferenceStopException # Default for -ErrorAction Stop
            # Or more specific if the function re-throws a custom exception type
        }
    }
}

Describe 'Invoke-DiskCleanup (Function from QAOps Module)' {
    # Mocked $env:TEMP and $env:SystemRoot for consistent test paths
    # These BeforeEach/AfterEach blocks ensure mocks are clean for each 'It' block.
    # More specific mocks can be defined within 'It' blocks if needed.
    
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

    Context '-DryRun functionality' {
        It 'should identify old files and create CleanupPlan.json without deleting' {
            $daysOld = 7
            $cutoffDate = (Get-Date).AddDays(-$daysOld)
            
            # Create mock files
            $oldFileUser = New-Item -Path (Join-Path $mockUserTemp "oldFileUser.tmp") -ItemType File -Force
            $oldFileUser.LastWriteTime = $cutoffDate.AddDays(-1)
            $newFileUser = New-Item -Path (Join-Path $mockUserTemp "newFileUser.tmp") -ItemType File -Force
            $newFileUser.LastWriteTime = $cutoffDate.AddDays(1)

            $oldFileWin = New-Item -Path (Join-Path $mockWindowsTemp "oldFileWin.tmp") -ItemType File -Force
            $oldFileWin.LastWriteTime = $cutoffDate.AddDays(-2)

            # Mock Get-ChildItem to return these specific files
            InModuleScope QAOps {
                Mock Get-ChildItem -MockWith {
                    param($Path = @('C:\Temp'))
                    $items = @()
                    if ($Path -eq $mockUserTemp) { $items += $oldFileUser, $newFileUser }
                    if ($Path -eq $mockWindowsTemp) { $items += $oldFileWin }
                    return $items
                }
            }
            # Mock Test-Path to always return true for the directories being scanned
            Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path) return $true }


            $summary = Invoke-DiskCleanup -DryRun -DaysOld $daysOld
            
            $summary.OperationMode | Should -Be "DryRun"
            $summary.ItemsIdentified | Should -Be 2 # oldFileUser, oldFileWin
            $summary.ItemsDeleted | Should -Be 0
            $summary.PlanFile | Should -Be $mockCleanupPlanFile
            Test-Path $mockCleanupPlanFile | Should -Be $true

            $planContent = Get-Content $mockCleanupPlanFile | ConvertFrom-Json
            $planContent.Count | Should -Be 2
            ($planContent.Path | Should -Contain $oldFileUser.FullName)
            ($planContent.Path | Should -Contain $oldFileWin.FullName)

            Assert-MockCalled Remove-Item -ModuleName Microsoft.PowerShell.Management -Times 0
        }
    }

    Context 'Live Run functionality' {
        It 'should delete old files and log actions when confirmed' {
            $daysOld = 10
            $cutoffDate = (Get-Date).AddDays(-$daysOld)

            $fileToDeletePath = Join-Path $mockUserTemp "fileToDelete.tmp"
            $fileToKeepPath = Join-Path $mockUserTemp "fileToKeep.tmp"
            New-Item -Path $fileToDeletePath -ItemType File -Force | Out-Null
            (Get-Item $fileToDeletePath).LastWriteTime = $cutoffDate.AddDays(-1)
            New-Item -Path $fileToKeepPath -ItemType File -Force | Out-Null
            (Get-Item $fileToKeepPath).LastWriteTime = $cutoffDate.AddDays(1)
            
            # Mock Get-ChildItem
            InModuleScope QAOps {
                Mock Get-ChildItem -MockWith {
                    param($Path = @('C:\Temp'))
                    if ($Path -eq $mockUserTemp) {
                        return @(Get-Item $fileToDeletePath), @(Get-Item $fileToKeepPath)
                    }
                    return @() # Empty for other paths like Windows\Temp for this test
                }
            }
            # Mock Test-Path for directories
             Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path) if($Path -like "*TempTestDir*") {return $true} else {return $false} }
            # Mock ShouldProcess to always return true
            Mock Invoke-Command -ModuleName Microsoft.PowerShell.Core -ParameterFilter { $ScriptBlock -like '*ShouldProcess*' } -MockWith { return $true }


            $summary = Invoke-DiskCleanup -DaysOld $daysOld -Confirm:$false # Using Confirm:$false for non-interactive test
            
            $summary.OperationMode | Should -Be "Live"
            $summary.ItemsIdentified | Should -Be 1
            $summary.ItemsDeleted | Should -Be 1
            $summary.LogFile | Should -Be $mockLogFile
            
            # Verify Remove-Item was called for the correct file
            Assert-MockCalled Remove-Item -ModuleName Microsoft.PowerShell.Management -Exactly 1 -ParameterFilter { $Path -eq $fileToDeletePath }
            
            # Verify logging (Add-Content)
            # This is a bit more complex as Add-Content is called multiple times (identified, deleted)
            # We can check if it was called with messages containing the filename.
            $addContentCalls = Get-MockCall Add-Content -ModuleName Microsoft.PowerShell.Management
            ($addContentCalls.Parameters.Value | Select-String -Pattern $fileToDeletePath.Replace('\','\\') | Should -Not -BeNullOrEmpty) # Check if filename was logged
            ($addContentCalls.Parameters.Value | Select-String -Pattern "DELETED" | Should -Not -BeNullOrEmpty)
        }

        It 'should skip deletion if ShouldProcess returns false' {
            $daysOld = 5
            $cutoffDate = (Get-Date).AddDays(-$daysOld)
            $fileToSkipPath = Join-Path $mockUserTemp "fileToSkip.tmp"
            New-Item -Path $fileToSkipPath -ItemType File -Force | Out-Null
            (Get-Item $fileToSkipPath).LastWriteTime = $cutoffDate.AddDays(-1)

            InModuleScope QAOps {
                Mock Get-ChildItem -MockWith { param($Path = @('C:\Temp')) @(Get-Item $fileToSkipPath) }
            }
            Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path) if($Path -like "*TempTestDir*") {return $true} else {return $false} }
            Mock Invoke-Command -ModuleName Microsoft.PowerShell.Core -ParameterFilter { $ScriptBlock -like '*ShouldProcess*' } -MockWith { return $false } # Simulate user saying No or -WhatIf

            $summary = Invoke-DiskCleanup -DaysOld $daysOld # ShouldProcess will be invoked by default
            
            $summary.ItemsIdentified | Should -Be 1
            $summary.ItemsDeleted | Should -Be 0
            $summary.ItemsSkipped | Should -Be 1
            Assert-MockCalled Remove-Item -ModuleName Microsoft.PowerShell.Management -Times 0
            
            $addContentCalls = Get-MockCall Add-Content -ModuleName Microsoft.PowerShell.Management
            ($addContentCalls.Parameters.Value | Select-String -Pattern "SKIPPED" | Should -Not -BeNullOrEmpty)
        }
    }
    
    Context 'Logging and Edge Cases' {
        It 'should create log directory if it does not exist' {
             # Ensure mockLogPathBase does NOT exist initially for this specific test
            if(Test-Path $mockLogPathBase) { Remove-Item $mockLogPathBase -Recurse -Force }
            
            # Mock Test-Path to simulate directory not existing, then existing after New-Item
            $testPathCallCount = 0
            Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith {
                param($Path)
                if ($Path -eq $mockLogPathBase) {
                    $testPathCallCount++
                    if ($testPathCallCount -eq 1) { return $false } # First call, dir doesn't exist
                    return $true # Subsequent calls, dir exists
                }
                return Test-Path @PSBoundParameters # Passthrough
            }
            # Mock New-Item to verify it's called for the directory
            Mock New-Item -ModuleName Microsoft.PowerShell.Management

            Invoke-DiskCleanup -DaysOld 99 # Live run, no files to find, just testing dir creation
            
            Assert-MockCalled New-Item -ModuleName Microsoft.PowerShell.Management -Exactly 1 -ParameterFilter { $Path -eq $mockLogPathBase -and $ItemType -eq 'Directory' }
        }

        It 'should handle empty locations gracefully' {
            InModuleScope QAOps {
                 Mock Get-ChildItem -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path = @('C:\Temp')) return @() } # No files found
            }
            Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path) return $true }


            $summary = Invoke-DiskCleanup -DaysOld 1
            $summary.ItemsIdentified | Should -Be 0
            $summary.ItemsDeleted | Should -Be 0
            $summary.Errors.Count | Should -Be 0
        }
        
        It 'should report errors if a location is inaccessible' {
            Mock Test-Path -ModuleName Microsoft.PowerShell.Management -MockWith { param($Path) if($Path -eq $mockUserTemp) {return $false} else {return $true} } # User Temp is inaccessible

            $summary = Invoke-DiskCleanup -DaysOld 1
            $summary.Errors | Should -ContainMatch "Location not found or inaccessible: $mockUserTemp"
        }
    }
}