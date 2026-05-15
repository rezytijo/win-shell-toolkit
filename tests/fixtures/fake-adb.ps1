param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

$outputRoot = $env:SCRCPY_WRAPPER_TEST_OUTPUT
$scenario = $env:SCRCPY_WRAPPER_SCENARIO

if (-not $outputRoot) {
    throw 'SCRCPY_WRAPPER_TEST_OUTPUT is required for fake-adb.'
}

$logPath = Join-Path $outputRoot 'adb-args.txt'
Add-Content -Path $logPath -Value ($ArgsList -join '|')

function Write-DeviceList {
    param([string[]]$Lines)
    Write-Output 'List of devices attached'
    foreach ($line in $Lines) {
        Write-Output $line
    }
}

if ($ArgsList.Count -eq 0) {
    exit 0
}

switch -Regex (($ArgsList -join ' ')) {
    '^devices -l$' {
        switch ($scenario) {
            'no-devices' { Write-DeviceList @() }
            'unauthorized' { Write-DeviceList @('USB123 unauthorized usb:1-1 product:pixel model:Pixel_8 device:shiba transport_id:7') }
            default { Write-DeviceList @('USB123 device usb:1-1 product:pixel model:Pixel_8 device:shiba transport_id:7') }
        }
        break
    }
    '^connect 192\.168\.1\.77:5555$' {
        Write-Output 'connected to 192.168.1.77:5555'
        break
    }
    default {
        break
    }
}
