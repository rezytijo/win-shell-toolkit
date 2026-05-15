Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptUnderTest = Join-Path $RepoRoot 'scrcpy.ps1'
$FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
$OutputRoot = Join-Path $PSScriptRoot 'artifacts'

function Reset-TestArtifacts {
    if (Test-Path $OutputRoot) {
        Remove-Item -LiteralPath $OutputRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
}

function Set-TestEnv {
    param(
        [string]$Scenario,
        [string[]]$Inputs = @()
    )

    $env:SCRCPY_WRAPPER_SCRCPY_EXE = (Join-Path $FixtureRoot 'fake-scrcpy.ps1')
    $env:SCRCPY_WRAPPER_ADB_EXE = (Join-Path $FixtureRoot 'fake-adb.ps1')
    $env:SCRCPY_WRAPPER_TEST_OUTPUT = $OutputRoot
    $env:SCRCPY_WRAPPER_SCENARIO = $Scenario
    $env:SCRCPY_WRAPPER_INPUTS = ($Inputs -join "`n")
}

function Clear-TestEnv {
    foreach ($name in @(
        'SCRCPY_WRAPPER_SCRCPY_EXE',
        'SCRCPY_WRAPPER_ADB_EXE',
        'SCRCPY_WRAPPER_TEST_OUTPUT',
        'SCRCPY_WRAPPER_SCENARIO',
        'SCRCPY_WRAPPER_INPUTS'
    )) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
}

function Invoke-Wrapper {
    param(
        [string[]]$Arguments = @()
    )

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptUnderTest @Arguments 2>&1
    return [PSCustomObject]@{
        Output   = @($output)
        ExitCode = $LASTEXITCODE
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message`nExpected: $Expected`nActual:   $Actual"
    }
}

function Assert-Match {
    param(
        [string]$Actual,
        [string]$Pattern,
        [string]$Message
    )

    if ($Actual -notmatch $Pattern) {
        throw "$Message`nPattern: $Pattern`nActual:  $Actual"
    }
}

function Read-ArgsLog {
    $path = Join-Path $OutputRoot 'scrcpy-args.txt'
    if (-not (Test-Path $path)) {
        return @()
    }
    return Get-Content $path
}

Reset-TestArtifacts
Clear-TestEnv

$tests = @(
    @{
        Name = 'Pass-through forwards raw arguments'
        Body = {
            Set-TestEnv -Scenario 'passthrough'
            $result = Invoke-Wrapper -Arguments @('--fullscreen', '--video-bit-rate=12M')
            $argsLog = Read-ArgsLog
            Assert-Equal ($argsLog -join '|') '--fullscreen|--video-bit-rate=12M' 'Wrapper did not forward scrcpy arguments unchanged.'
            Assert-Equal $result.ExitCode 0 'Pass-through should exit cleanly.'
            Assert-Match (($result.Output | Out-String).Trim()) 'fake scrcpy invoked' 'Expected fake scrcpy passthrough output.'
        }
    },
    @{
        Name = 'No devices shows clean message'
        Body = {
            Set-TestEnv -Scenario 'no-devices'
            $result = Invoke-Wrapper
            Assert-Equal $result.ExitCode 1 'No-device case should exit with error.'
            Assert-Match (($result.Output | Out-String).Trim()) 'No Android devices were found' 'Expected no-device guidance.'
        }
    },
    @{
        Name = 'Unauthorized device shows actionable message'
        Body = {
            Set-TestEnv -Scenario 'unauthorized' -Inputs @('1')
            $result = Invoke-Wrapper
            Assert-Equal $result.ExitCode 1 'Unauthorized device selection should exit with error.'
            Assert-Match (($result.Output | Out-String).Trim()) 'unauthorized' 'Expected unauthorized device warning.'
            Assert-Match (($result.Output | Out-String).Trim()) 'USB debugging prompt' 'Expected actionable guidance for authorization.'
        }
    },
    @{
        Name = 'USB interactive launch maps duplicate audio flags'
        Body = {
            Set-TestEnv -Scenario 'usb-device' -Inputs @('1', '1', '2')
            $result = Invoke-Wrapper
            Assert-Equal $result.ExitCode 0 'USB interactive launch should exit cleanly.'
            $argsLog = Read-ArgsLog
            Assert-Equal ($argsLog -join '|') '--serial|USB123|--audio-source=playback|--audio-dup' 'USB launch did not map duplicate audio flags as expected.'
        }
    },
    @{
        Name = 'Manual wireless connect launches against TCP endpoint'
        Body = {
            Set-TestEnv -Scenario 'manual-wireless' -Inputs @('1', '3', '192.168.1.77:5555', '1')
            $result = Invoke-Wrapper
            Assert-Equal $result.ExitCode 0 'Manual wireless launch should exit cleanly.'
            $scrcpyArgs = Read-ArgsLog
            $adbLog = Get-Content (Join-Path $OutputRoot 'adb-args.txt')
            Assert-Match ($adbLog -join '|') 'connect\|192\.168\.1\.77:5555' 'Expected adb connect for manual TCP/IP mode.'
            Assert-Equal ($scrcpyArgs -join '|') '--serial|192.168.1.77:5555|--audio-source=output' 'Manual wireless launch used unexpected scrcpy arguments.'
        }
    }
)

$failures = New-Object System.Collections.Generic.List[string]

foreach ($test in $tests) {
    Reset-TestArtifacts
    Clear-TestEnv

    try {
        & $test.Body
        Write-Host "[PASS] $($test.Name)" -ForegroundColor Green
    } catch {
        $failures.Add("[FAIL] $($test.Name)`n$($_.Exception.Message)")
        Write-Host "[FAIL] $($test.Name)" -ForegroundColor Red
    } finally {
        Clear-TestEnv
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}

Write-Host 'All scrcpy wrapper tests passed.' -ForegroundColor Green
