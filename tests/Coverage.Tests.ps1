Describe 'Coverage release gate' {
    It 'rejects missing reports instead of skipping the gate' {
        { & (Join-Path $PSScriptRoot '..' 'scripts' 'Test-Coverage.ps1') -Path (Join-Path $TestDrive 'missing.xml') } | Should -Throw
    }

    It 'uses report-level counts without rounding a failing result up' {
        $path = Join-Path $TestDrive 'coverage.xml'
        Set-Content $path '<report><package><counter type="LINE" covered="100" missed="0"/></package><counter type="LINE" covered="159" missed="41"/></report>'
        { & (Join-Path $PSScriptRoot '..' 'scripts' 'Test-Coverage.ps1') -Path $path } | Should -Throw
        Set-Content $path '<report><counter type="LINE" covered="80" missed="20"/></report>'
        & (Join-Path $PSScriptRoot '..' 'scripts' 'Test-Coverage.ps1') -Path $path | Should -Match '80% meets'
    }

    It 'rejects empty or malformed counts' {
        $path = Join-Path $TestDrive 'invalid.xml'
        foreach ($xml in @('<report/>', '<report><counter type="LINE" covered="0" missed="0"/></report>', '<report><counter type="LINE" covered="bad" missed="2"/></report>')) {
            Set-Content $path $xml
            { & (Join-Path $PSScriptRoot '..' 'scripts' 'Test-Coverage.ps1') -Path $path } | Should -Throw
        }
    }
}
