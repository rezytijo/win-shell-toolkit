# scrcpy.ps1 -- Interactive wrapper for bundled scrcpy + adb
# 2026-05-16 -- v1.0.0: USB/wireless launcher with per-run audio selection

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

function Get-WrapperPath {
    param(
        [string]$OverrideValue,
        [string]$DefaultRelativePath,
        [string]$Label
    )

    $candidate = if ($OverrideValue) { $OverrideValue } else { Join-Path $PSScriptRoot $DefaultRelativePath }
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Missing bundled ${Label}: $candidate"
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-QueuedInput {
    if (-not $script:QueuedInputsInitialized) {
        $script:QueuedInputsInitialized = $true
        $script:QueuedInputs = New-Object System.Collections.Generic.Queue[string]

        if ($env:SCRCPY_WRAPPER_INPUTS) {
            foreach ($line in ($env:SCRCPY_WRAPPER_INPUTS -split "`r?`n")) {
                [void]$script:QueuedInputs.Enqueue($line)
            }
        }
    }

    return ,$script:QueuedInputs
}

function Read-MenuInput {
    param(
        [string]$Prompt
    )

    $queue = Get-QueuedInput
    if ($queue.Count -gt 0) {
        $value = $queue.Dequeue()
        Write-Host "$Prompt $value" -ForegroundColor DarkGray
        return $value
    }

    return Read-Host $Prompt
}

function Invoke-Tool {
    param(
        [string]$Executable,
        [string[]]$ArgumentList
    )

    $output = & $Executable @ArgumentList 2>&1
    $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

    return [PSCustomObject]@{
        Output   = @($output)
        ExitCode = $exitCode
    }
}

function Invoke-Scrcpy {
    param(
        [string]$Executable,
        [string[]]$ArgumentList,
        [switch]$DuplicationRequested
    )

    & $Executable @ArgumentList
    $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

    if ($exitCode -ne 0 -and $DuplicationRequested) {
        Write-Host ''
        Write-Host 'Audio duplication failed. This usually means the device does not support playback capture in this mode.' -ForegroundColor Yellow
        Write-Host 'Retry with "forward audio to PC only" or "disable audio".' -ForegroundColor Yellow
    }

    exit $exitCode
}

function Parse-AdbDeviceLine {
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $null
    }

    $tokens = $Line.Trim() -split '\s+'
    if ($tokens.Count -lt 2) {
        return $null
    }

    $meta = @{}
    foreach ($token in $tokens | Select-Object -Skip 2) {
        if ($token -match '^([^:]+):(.+)$') {
            $meta[$matches[1]] = $matches[2]
        }
    }

    $serial = $tokens[0]
    $state = $tokens[1]
    $transport = if ($meta.ContainsKey('transport_id')) { $meta['transport_id'] } else { '-' }
    $model = if ($meta.ContainsKey('model')) { $meta['model'] -replace '_', ' ' } else { '-' }
    $connection = if ($meta.ContainsKey('usb')) { "USB $($meta['usb'])" } elseif ($serial -match '^\d{1,3}(\.\d{1,3}){3}:\d+$') { 'TCP/IP' } else { '-' }
    $isUsb = $meta.ContainsKey('usb')

    return [PSCustomObject]@{
        Serial     = $serial
        State      = $state
        Model      = $model
        Transport  = $transport
        Connection = $connection
        IsUsb      = $isUsb
    }
}

function Get-AdbDevices {
    param(
        [string]$AdbExecutable
    )

    $result = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('devices', '-l')
    if ($result.ExitCode -ne 0) {
        throw (($result.Output | Out-String).Trim())
    }

    $devices = @()
    foreach ($line in $result.Output) {
        if ($line -match '^List of devices attached') {
            continue
        }

        $parsed = Parse-AdbDeviceLine -Line ([string]$line)
        if ($parsed) {
            $devices += $parsed
        }
    }

    return $devices
}

function Show-DeviceList {
    param(
        [object[]]$Devices
    )

    Write-Host ''
    Write-Host 'Available Android devices:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $Devices.Count; $i++) {
        $device = $Devices[$i]
        Write-Host ("  [{0}] {1}  {2}  {3}  state={4}  transport={5}" -f ($i + 1), $device.Serial, $device.Model, $device.Connection, $device.State, $device.Transport)
    }
}

function Select-Device {
    param(
        [object[]]$Devices
    )

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Select device number'
        $index = 0
        if ([int]::TryParse($raw, [ref]$index) -and $index -ge 1 -and $index -le $Devices.Count) {
            return $Devices[$index - 1]
        }

        Write-Host 'Enter a valid device number.' -ForegroundColor Yellow
    }
}

function Get-ConnectionMode {
    Write-Host ''
    Write-Host 'Connection mode:' -ForegroundColor Cyan
    Write-Host '  [1] USB'
    Write-Host '  [2] Wireless via USB bootstrap'
    Write-Host '  [3] Wireless via manual IP:port'

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Choose connection mode'
        switch ($raw) {
            '1' { return 'usb' }
            '2' { return 'wireless-bootstrap' }
            '3' { return 'wireless-manual' }
            default { Write-Host 'Enter 1, 2, or 3.' -ForegroundColor Yellow }
        }
    }
}

function Get-AudioSelection {
    Write-Host ''
    Write-Host 'Audio mode:' -ForegroundColor Cyan
    Write-Host '  [1] Forward audio to PC only'
    Write-Host '  [2] Duplicate audio to PC and phone'
    Write-Host '  [3] Disable audio'

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Choose audio mode'
        switch ($raw) {
            '1' { return [PSCustomObject]@{ Args = @('--audio-source=output'); DuplicationRequested = $false } }
            '2' { return [PSCustomObject]@{ Args = @('--audio-source=playback', '--audio-dup'); DuplicationRequested = $true } }
            '3' { return [PSCustomObject]@{ Args = @('--no-audio'); DuplicationRequested = $false } }
            default { Write-Host 'Enter 1, 2, or 3.' -ForegroundColor Yellow }
        }
    }
}

function Assert-ReadyDevice {
    param(
        [object]$Device
    )

    switch ($Device.State) {
        'device' { return }
        'unauthorized' {
            throw "The selected device is unauthorized. Unlock the phone, accept the USB debugging prompt, then run scrcpy again."
        }
        'offline' {
            throw "The selected device is offline. Reconnect the cable or restart adb, then try again."
        }
        default {
            throw "The selected device is not ready: state=$($Device.State)"
        }
    }
}

function Get-ManualEndpoint {
    while ($true) {
        $endpoint = (Read-MenuInput -Prompt 'Enter device IP:port').Trim()
        if ($endpoint -match '^\d{1,3}(\.\d{1,3}){3}:\d{1,5}$') {
            return $endpoint
        }

        Write-Host 'Enter a valid endpoint such as 192.168.1.50:5555.' -ForegroundColor Yellow
    }
}

function Connect-AdbTcpEndpoint {
    param(
        [string]$AdbExecutable,
        [string]$Endpoint
    )

    $result = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('connect', $Endpoint)
    $text = ($result.Output | Out-String).Trim()
    if ($result.ExitCode -ne 0 -or $text -match 'failed|unable|cannot') {
        throw "Failed to connect to $Endpoint. adb said: $text"
    }

    return $Endpoint
}

function Resolve-DeviceWifiIp {
    param(
        [string]$AdbExecutable,
        [string]$Serial
    )

    $attempts = @(
        @('-s', $Serial, 'shell', 'ip', 'route'),
        @('-s', $Serial, 'shell', 'getprop', 'dhcp.wlan0.ipaddress'),
        @('-s', $Serial, 'shell', 'getprop', 'dhcp.wifi.ipaddress')
    )

    foreach ($args in $attempts) {
        $result = Invoke-Tool -Executable $AdbExecutable -ArgumentList $args
        $text = ($result.Output | Out-String).Trim()
        if ($text -match '\bsrc\s+(\d{1,3}(?:\.\d{1,3}){3})\b') {
            return $matches[1]
        }

        if ($text -match '^\d{1,3}(\.\d{1,3}){3}$') {
            return $text
        }
    }

    throw 'Unable to determine the device Wi-Fi IP address for wireless bootstrap.'
}

function Start-WirelessBootstrap {
    param(
        [string]$AdbExecutable,
        [object]$Device
    )

    if (-not $Device.IsUsb) {
        throw 'Wireless bootstrap requires a USB-connected device.'
    }

    $tcpipResult = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Device.Serial, 'tcpip', '5555')
    if ($tcpipResult.ExitCode -ne 0) {
        throw "Failed to enable TCP/IP mode on $($Device.Serial). adb said: $(($tcpipResult.Output | Out-String).Trim())"
    }

    $ipAddress = Resolve-DeviceWifiIp -AdbExecutable $AdbExecutable -Serial $Device.Serial
    $endpoint = "$ipAddress`:5555"

    Connect-AdbTcpEndpoint -AdbExecutable $AdbExecutable -Endpoint $endpoint | Out-Null
    return $endpoint
}

try {
    $scrcpyExe = Get-WrapperPath -OverrideValue $env:SCRCPY_WRAPPER_SCRCPY_EXE -DefaultRelativePath 'scrcpy\scrcpy.exe' -Label 'scrcpy binary'
    $adbExe = Get-WrapperPath -OverrideValue $env:SCRCPY_WRAPPER_ADB_EXE -DefaultRelativePath 'scrcpy\adb.exe' -Label 'adb binary'

    if ($Arguments.Count -gt 0) {
        & $scrcpyExe @Arguments
        exit $LASTEXITCODE
    }

    $devices = @(Get-AdbDevices -AdbExecutable $adbExe)
    if ($devices.Count -eq 0) {
        Write-Host 'No Android devices were found. Connect a phone over USB or run `adb connect <ip:port>` first.' -ForegroundColor Yellow
        exit 1
    }

    Show-DeviceList -Devices $devices
    $selectedDevice = Select-Device -Devices $devices
    Assert-ReadyDevice -Device $selectedDevice

    $connectionMode = Get-ConnectionMode
    $targetSerial = $selectedDevice.Serial

    switch ($connectionMode) {
        'usb' {
            $targetSerial = $selectedDevice.Serial
        }
        'wireless-bootstrap' {
            $targetSerial = Start-WirelessBootstrap -AdbExecutable $adbExe -Device $selectedDevice
        }
        'wireless-manual' {
            $targetSerial = Get-ManualEndpoint
            Connect-AdbTcpEndpoint -AdbExecutable $adbExe -Endpoint $targetSerial | Out-Null
        }
    }

    $audio = Get-AudioSelection
    $scrcpyArgs = @('--serial', $targetSerial) + $audio.Args
    Invoke-Scrcpy -Executable $scrcpyExe -ArgumentList $scrcpyArgs -DuplicationRequested:$audio.DuplicationRequested
} catch {
    Write-Host ''
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
