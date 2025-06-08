#Requires -Version 7

function Get-SystemReport {
<#
.SYNOPSIS
    Collects basic system information including OS and disk usage.
.DESCRIPTION
    This function gathers details about the operating system (like version and build)
    and disk drives (like free space and total size).
    It outputs this information as a JSON object by default.
    Future enhancements will include options for CSV and Markdown output.
.PARAMETER Format
    Specifies the output format. Currently, only JSON is fully implemented.
    Valid values: "JSON", "Markdown", "Console" (future).
.EXAMPLE
    PS C:\> Get-SystemReport
    Outputs system report in JSON format.
.EXAMPLE
    PS C:\> Get-SystemReport -Format JSON
    Explicitly outputs system report in JSON format.
.OUTPUTS
    System.String
    A JSON formatted string containing the system report, or an error object on failure.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateSet("JSON", "Markdown", "Console")]
        [string]$Format = "JSON" # Default to JSON
    )

    # Define the schema version for the report
    $SchemaVersion = "1.0.0"

    try {
        Write-Verbose "Starting system report generation (Schema: $SchemaVersion)..."

        # Gather OS Information
        $osInfo = $null
        try {
            Write-Verbose "Gathering Operating System information..."
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object @{Name="OSName";Expression={$_.Caption}}, @{Name="OSVersion";Expression={$_.Version}}, @{Name="OSBuildNumber";Expression={$_.BuildNumber}}, @{Name="OSArchitecture";Expression={$_.OSArchitecture}}, @{Name="RegisteredUser";Expression={$_.RegisteredUser}}, @{Name="LastBootUpTime";Expression={$_.LastBootUpTime}}
            if (-not $osInfo) {
                Write-Warning "OS information query returned no data."
                $osInfo = @{ Error = "OS information query returned no data." }
            }
        }
        catch {
            Write-Warning "Could not retrieve OS information: $($_.Exception.Message)"
            $osInfo = @{ Error = "Failed to retrieve OS information: $($_.Exception.Message)" }
        }

        # Gather Disk Information
        $diskInfo = @() # Default to empty array
        try {
            Write-Verbose "Gathering Disk information..."
            $rawDiskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
            if ($rawDiskInfo) {
                $diskInfo = $rawDiskInfo | Select-Object @{Name="DiskDeviceID";Expression={$_.DeviceID}}, @{Name="DiskVolumeName";Expression={$_.VolumeName}}, @{Name="DiskFileSystem";Expression={$_.FileSystem}}, @{Name="DiskFreeSpaceGB";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{Name="DiskTotalSizeGB";Expression={[math]::Round($_.Size / 1GB, 2)}}
            } else {
                Write-Warning "No logical disks (DriveType=3) found or disk information query returned no data."
                # $diskInfo remains an empty array, which is the desired state for "no disks"
            }
        }
        catch {
            Write-Warning "Could not retrieve Disk information: $($_.Exception.Message)"
            # $diskInfo remains an empty array, indicating an issue or no disks
        }

        # Combine into a single report object
        $report = [PSCustomObject]@{
            SchemaVersion   = $SchemaVersion
            ReportTimestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
            OperatingSystem = $osInfo
            Disks           = $diskInfo # Will be @() if no disks found or error
        }

        # Output based on format
        switch ($Format) {
            "JSON" {
                Write-Verbose "Converting report to JSON format."
                $output = $report | ConvertTo-Json -Depth 5
            }
            "Markdown" {
                # Placeholder for Markdown conversion
                Write-Warning "Markdown output is not yet implemented. Defaulting to JSON."
                $output = $report | ConvertTo-Json -Depth 5 # Fallback for now
            }
            "Console" {
                # Placeholder for Console pretty print
                Write-Warning "Console output is not yet implemented. Defaulting to JSON."
                $output = $report | ConvertTo-Json -Depth 5 # Fallback for now
            }
            default {
                Write-Error "Invalid format specified: $Format. Defaulting to JSON."
                $output = $report | ConvertTo-Json -Depth 5 # Fallback for now
            }
        }

        Write-Output $output
        Write-Verbose "System report generation complete."

    }
    catch {
        $errorMessage = "An error occurred during system report generation: $($_.Exception.Message)"
        Write-Error $errorMessage
        # Re-throw the exception so the caller (e.g., Pester test or shim script) can handle it
        throw $_
    }
}

Export-ModuleMember -Function Get-SystemReport, Invoke-DiskCleanup

function Invoke-DiskCleanup {
<#
.SYNOPSIS
    Cleans up temporary files from specified locations.
.DESCRIPTION
    Identifies and removes files older than a specified number of days from common temporary locations.
    Supports a DryRun mode to preview changes and logs actions to a central log file.
    Requires administrative privileges to write to the default log location in %ProgramData%.
.PARAMETER DryRun
    If specified, the function will only list files that would be deleted and save this plan
    to 'CleanupPlan.json' in the current directory. No files will actually be deleted.
.PARAMETER DaysOld
    Specifies the minimum age in days for files to be considered for deletion.
    Defaults to 14 days.
.EXAMPLE
    PS C:\> Invoke-DiskCleanup -DryRun -DaysOld 7
    Lists files older than 7 days in temp locations that would be deleted and saves the plan.
.EXAMPLE
    PS C:\> Invoke-DiskCleanup -DaysOld 30 -Confirm
    Prompts for confirmation before deleting files older than 30 days from temp locations.
.OUTPUTS
    PSCustomObject
    A summary object detailing the operation's results, including counts of items
    identified/deleted and paths to any generated plan or log files.
.NOTES
    Default log path: C:\ProgramData\QAOps\Cleanup.log (requires admin rights to create/write).
    Consider running PowerShell as Administrator if using the default log path and not in DryRun mode.
    Target locations currently include:
    - User's TEMP folder ($env:TEMP)
    - Windows TEMP folder ($env:SystemRoot\Temp) - (Requires Admin)
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [int]$DaysOld = 14
    )

    Write-Verbose "Starting Invoke-DiskCleanup (DryRun: $DryRun, DaysOld: $DaysOld)."

    $cleanupLogPathBase = "C:\ProgramData\QAOps" # Base directory for logs
    $cleanupLogFile = Join-Path -Path $cleanupLogPathBase -ChildPath "Cleanup.log"
    $cleanupPlanFile = "CleanupPlan.json" # In current working directory for DryRun

    $itemsToClean = @()
    $summary = [PSCustomObject]@{
        OperationMode   = if ($DryRun) { "DryRun" } else { "Live" }
        ItemsScanned    = 0
        ItemsIdentified = 0
        ItemsDeleted    = 0
        ItemsSkipped    = 0
        LogFile         = if (-not $DryRun) { $cleanupLogFile } else { $null }
        PlanFile        = if ($DryRun) { $cleanupPlanFile } else { $null }
        Errors          = @()
    }

    # Ensure log directory exists if not in DryRun
    if (-not $DryRun) {
        try {
            if (-not (Test-Path -Path $cleanupLogPathBase -PathType Container)) {
                Write-Verbose "Creating log directory: $cleanupLogPathBase"
                New-Item -Path $cleanupLogPathBase -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
        }
        catch {
            $errMsg = "Error creating log directory '$cleanupLogPathBase'. Logging may fail. Error: $($_.Exception.Message)"
            Write-Warning $errMsg
            $summary.Errors.Add($errMsg)
            # Proceed, but logging might go to a less privileged location or fail.
            # For simplicity, this version will attempt to log and let it fail if permissions are insufficient.
            # A more robust solution might try alternative log paths.
        }
    }
    # Helper function to log messages
    function Write-CleanupLog {
        param ([string]$Message)
        if (-not $DryRun) {
            try {
                $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                "[$timestamp] $Message" | Add-Content -Path $cleanupLogFile -ErrorAction Stop
            }
            catch {
                $errMsg = "Failed to write to log file '$cleanupLogFile'. Error: $($_.Exception.Message)"
                Write-Warning $errMsg
                # Add to summary errors only once per type of error to avoid flooding
                if ($summary.Errors -notcontains $errMsg) {
                    $summary.Errors.Add($errMsg)
                }
            }
        }
        Write-Verbose $Message # Also output to verbose stream
    }

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    Write-Verbose "Files older than $cutoffDate (i.e., created before or on this date) will be targeted."

    # Define locations to scan. Add more as needed.
    $locationsToScan = @(
        [PSCustomObject]@{ Path = $env:TEMP; Description = "User TEMP"; RequiresAdmin = $false }
        [PSCustomObject]@{ Path = "$($env:SystemRoot)\Temp"; Description = "Windows TEMP"; RequiresAdmin = $true }
        # Add other common locations: e.g., Windows Update cache, crash dumps (these often require specific enumeration methods)
    )

    foreach ($location in $locationsToScan) {
        Write-Verbose "Scanning location: $($location.Path) ($($location.Description))"
        if (-not (Test-Path -Path $location.Path)) {
            Write-Warning "Location not found or inaccessible: $($location.Path)"
            $summary.Errors.Add("Location not found or inaccessible: $($location.Path)")
            continue
        }

        # Check for admin rights if location requires it (simple check, might not be foolproof)
        if ($location.RequiresAdmin -and (-not $DryRun)) {
            $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warning "Skipping $($location.Path) as it requires administrator privileges and script is not running as admin."
                $summary.Errors.Add("Skipped $($location.Path): Requires admin privileges.")
                continue
            }
        }
        try {
            # Get all files, then filter by LastWriteTime. Recurse through subdirectories.
            # -ErrorAction SilentlyContinue for individual file access errors during enumeration
            $files = Get-ChildItem -Path $location.Path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $summary.ItemsScanned++
                $_ # Pass the object along
            } | Where-Object { $_.LastWriteTime -lt $cutoffDate }

            if ($null -eq $files) {
                Write-Verbose "No files older than $DaysOld days found in $($location.Path)."
                continue
            }

            foreach ($file in $files) {
                $summary.ItemsIdentified++
                $fileInfo = [PSCustomObject]@{
                    Path           = $file.FullName
                    SizeMB         = [math]::Round($file.Length / 1MB, 2)
                    LastWriteTime  = $file.LastWriteTime
                    LocationDesc   = $location.Description
                }
                $itemsToClean += $fileInfo

                if (-not $DryRun) {
                    Write-CleanupLog "Identified for deletion: $($file.FullName) (LastWrite: $($file.LastWriteTime))"
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Delete File (Older than $DaysOld days, LastWrite: $($file.LastWriteTime))")) {
                        try {
                            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                            Write-CleanupLog "DELETED: $($file.FullName)"
                            $summary.ItemsDeleted++
                        }
                        catch {
                            $errMsg = "Error deleting file '$($file.FullName)': $($_.Exception.Message)"
                            Write-Error $errMsg
                            Write-CleanupLog "ERROR deleting '$($file.FullName)': $($_.Exception.Message)"
                            $summary.Errors.Add($errMsg)
                            $summary.ItemsSkipped++
                        }
                    } else {
                        Write-CleanupLog "SKIPPED (ShouldProcess returned false or -WhatIf): $($file.FullName)"
                        $summary.ItemsSkipped++
                    }
                } else {
                     Write-Verbose "DRYRUN: Would delete $($file.FullName) (LastWrite: $($file.LastWriteTime))"
                }
            }
        }
        catch {
            # Catch errors from Get-ChildItem itself if the whole location is problematic
            $errMsg = "Error processing location '$($location.Path)': $($_.Exception.Message)"
            Write-Warning $errMsg
            $summary.Errors.Add($errMsg)
        }
    }

    if ($DryRun) {
        Write-Verbose "Dry run complete. Writing cleanup plan to $cleanupPlanFile"
        try {
            $itemsToClean | ConvertTo-Json -Depth 3 | Set-Content -Path $cleanupPlanFile -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "Dry run complete. Plan saved to $cleanupPlanFile"
        }
        catch {
            $errMsg = "Error writing cleanup plan to '$cleanupPlanFile': $($_.Exception.Message)"
            Write-Error $errMsg
            $summary.Errors.Add($errMsg)
        }
    } else {
        Write-Verbose "Cleanup process complete. Summary:"
        Write-CleanupLog "Cleanup process finished. Scanned: $($summary.ItemsScanned), Identified: $($summary.ItemsIdentified), Deleted: $($summary.ItemsDeleted), Skipped: $($summary.ItemsSkipped)."
    }

    return $summary
}