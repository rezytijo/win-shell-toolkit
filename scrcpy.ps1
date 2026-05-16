# scrcpy.ps1 -- Interactive wrapper for installed scrcpy + adb
# 2026-05-16 -- v1.1.0: USB/wireless launcher backed by installed scrcpy runtime

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\scrcpy-install.ps1')

function Show-WrapperHelp {
    Write-Host 'scrcpy - interactive Android remote launcher' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  scrcpy'
    Write-Host '      Open the interactive device launcher.'
    Write-Host ''
    Write-Host '  scrcpy --raw <scrcpy arguments>'
    Write-Host '      Forward arguments directly to the installed scrcpy binary.'
    Write-Host ''
    Write-Host '  scrcpy --version'
    Write-Host '      Show installed scrcpy version.'
    Write-Host ''
    Write-Host '  scrcpy --help'
    Write-Host '      Show this wrapper help.'
}

function Get-WrapperPath {
    param(
        [string]$OverrideValue,
        [string]$Label
    )

    $candidate = $OverrideValue
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Missing ${Label}: $candidate"
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-QueuedInput {
    if (-not (Get-Variable -Name QueuedInputsInitialized -Scope Script -ErrorAction SilentlyContinue)) {
        $script:QueuedInputsInitialized = $false
    }

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
    $lastExit = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $exitCode = if ($lastExit) { [int]$lastExit.Value } else { 0 }

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
    $lastExit = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $exitCode = if ($lastExit) { [int]$lastExit.Value } else { 0 }

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
    $isTcpEndpoint = $serial -match '^\d{1,3}(\.\d{1,3}){3}:\d+$'
    $transport = if ($meta.ContainsKey('transport_id')) { $meta['transport_id'] } else { '-' }
    $model = if ($meta.ContainsKey('model')) { $meta['model'] -replace '_', ' ' } else { '-' }
    $connection = if ($meta.ContainsKey('usb')) { "USB $($meta['usb'])" } elseif ($isTcpEndpoint) { 'TCP/IP' } else { 'USB / local adb' }
    $isUsb = $meta.ContainsKey('usb') -or (-not $isTcpEndpoint)

    return [PSCustomObject]@{
        Serial     = $serial
        State      = $state
        Model      = $model
        Transport  = $transport
        Connection = $connection
        IsUsb      = $isUsb
        IsTcpip    = $isTcpEndpoint
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

function Show-NoDeviceMenu {
    Write-Host ''
    Write-Host 'No Android devices detected yet.' -ForegroundColor Yellow
    Write-Host 'Choose how to continue:' -ForegroundColor Cyan
    Write-Host '  [1] Re-scan USB / adb devices'
    Write-Host '  [2] Connect wirelessly with IP:port'
    Write-Host '  [3] Exit'

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Choose an option'
        switch ($raw) {
            '1' { return 'rescan' }
            '2' { return 'manual-wireless' }
            '3' { return 'exit' }
            default { Write-Host 'Enter 1, 2, or 3.' -ForegroundColor Yellow }
        }
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

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Choose connection mode'
        switch ($raw) {
            '1' { return 'usb' }
            '2' { return 'wireless-bootstrap' }
            default { Write-Host 'Enter 1 or 2.' -ForegroundColor Yellow }
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

function Get-VideoProfileSelection {
    Write-Host ''
    Write-Host 'Video profile:' -ForegroundColor Cyan
    Write-Host '  [1] Quality      - 8M, native size, 60 fps'
    Write-Host '  [2] Balanced     - 6M, 1920 max-size, 30 fps'
    Write-Host '  [3] Livestream   - 6M, 1600 max-size, 30 fps'
    Write-Host '  [4] Low-end      - 4M, 1280 max-size, 30 fps'

    while ($true) {
        $raw = Read-MenuInput -Prompt 'Choose video profile'
        switch ($raw) {
            '1' {
                return [PSCustomObject]@{
                    Name = 'Quality'
                    Args = @('--video-bit-rate=8M', '--max-fps=60')
                }
            }
            '2' {
                return [PSCustomObject]@{
                    Name = 'Balanced'
                    Args = @('--video-bit-rate=6M', '--max-size=1920', '--max-fps=30')
                }
            }
            '3' {
                return [PSCustomObject]@{
                    Name = 'Livestream'
                    Args = @('--video-bit-rate=6M', '--max-size=1600', '--max-fps=30')
                }
            }
            '4' {
                return [PSCustomObject]@{
                    Name = 'Low-end'
                    Args = @('--video-bit-rate=4M', '--max-size=1280', '--max-fps=30')
                }
            }
            default { Write-Host 'Enter 1, 2, 3, or 4.' -ForegroundColor Yellow }
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

function Get-DeviceFromEndpoint {
    param(
        [string]$Endpoint
    )

    return [PSCustomObject]@{
        Serial     = $Endpoint
        State      = 'device'
        Model      = 'Wireless device'
        Transport  = '-'
        Connection = 'TCP/IP'
        IsUsb      = $false
        IsTcpip    = $true
    }
}

function Resolve-DeviceWifiIp {
    param(
        [string]$AdbExecutable,
        [string]$Serial
    )

    function Find-Ipv4InText {
        param(
            [string]$Text
        )

        if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

        # Patterns prioritized by reliability
        $patterns = @(
            '\binet\s+(\d{1,3}(?:\.\d{1,3}){3})(?:/\d+)?\b',
            '\binet addr:(\d{1,3}(?:\.\d{1,3}){3})\b',
            '\bsrc\s+(\d{1,3}(?:\.\d{1,3}){3})\b',
            '\b(\d{1,3}(?:\.\d{1,3}){3})\b'
        )

        foreach ($p in $patterns) {
            $regex = [regex]::new($p, 'IgnoreCase')
            $matches = $regex.Matches($Text)
            foreach ($m in $matches) {
                $ip = $m.Groups[1].Value
                # Skip loopback, self-assigned (APIPA), and zero address
                if ($ip -ne '127.0.0.1' -and $ip -ne '0.0.0.0' -and $ip -notmatch '^169\.254\.') {
                    return $ip
                }
            }
        }

        return $null
    }

    # Attempt 1: Specific interface and routing
    $attempts = @(
        @('-s', $Serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0'),
        @('-s', $Serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show'),
        @('-s', $Serial, 'shell', 'ip', 'route', 'get', '1.1.1.1'),
        @('-s', $Serial, 'shell', 'ip', 'route')
    )

    foreach ($args in $attempts) {
        $result = Invoke-Tool -Executable $AdbExecutable -ArgumentList $args
        $text = ($result.Output | Out-String).Trim()
        $ipAddress = Find-Ipv4InText -Text $text
        if ($ipAddress) {
            return $ipAddress
        }
    }

    # Attempt 2: All properties containing 'ip' and a valid address
    $propResult = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Serial, 'shell', 'getprop')
    foreach ($line in $propResult.Output) {
        if ($line -match '\[.*ip.*\]: \[(\d{1,3}(?:\.\d{1,3}){3})\]') {
            $ip = $matches[1]
            if ($ip -ne '0.0.0.0' -and $ip -ne '127.0.0.1' -and $ip -notmatch '^169\.254\.') {
                return $ip
            }
        }
    }

    # Attempt 3: Interface fallbacks
    $wifiInterfaceResult = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Serial, 'shell', 'getprop', 'wifi.interface')
    $wifiInterface = (($wifiInterfaceResult.Output | Out-String).Trim())
    if (-not $wifiInterface -or $wifiInterface -match '\s') {
        $wifiInterface = 'wlan0'
    }

    $interfaceAttempts = @(
        @('-s', $Serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show', $wifiInterface),
        @('-s', $Serial, 'shell', 'ifconfig', $wifiInterface),
        @('-s', $Serial, 'shell', 'ifconfig'),
        @('-s', $Serial, 'shell', 'netcfg')
    )

    foreach ($args in $interfaceAttempts) {
        $result = Invoke-Tool -Executable $AdbExecutable -ArgumentList $args
        $text = ($result.Output | Out-String).Trim()
        $ipAddress = Find-Ipv4InText -Text $text
        if ($ipAddress) {
            return $ipAddress
        }
    }

    # Final attempt: Show diagnostics if failed
    Write-Host "`n[DIAGNOSTIC] IP discovery failed. Printing raw device network info..." -ForegroundColor Yellow
    
    Write-Host "`n--- adb shell ip -f inet addr show ---" -ForegroundColor Gray
    $debugIp = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show')
    $debugIp.Output | Write-Host -ForegroundColor Gray

    Write-Host "`n--- adb shell ip route ---" -ForegroundColor Gray
    $debugRoute = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Serial, 'shell', 'ip', 'route')
    $debugRoute.Output | Write-Host -ForegroundColor Gray

    Write-Host "`n--- relevant getprop values ---" -ForegroundColor Gray
    $debugProps = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Serial, 'shell', 'getprop')
    $debugProps.Output | Where-Object { $_ -match 'ip|wifi|wlan' } | Write-Host -ForegroundColor Gray

    throw 'Unable to determine the device Wi-Fi IP address for wireless bootstrap.'
}

function Start-WirelessBootstrap {
    param(
        [string]$AdbExecutable,
        [object]$Device
    )

    if ($Device.IsTcpip) {
        throw 'Wireless bootstrap requires a locally attached device, not an existing TCP/IP endpoint.'
    }

    Write-Host "Enabling TCP/IP mode on port 5555..." -ForegroundColor Gray
    $tcpipResult = Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Device.Serial, 'tcpip', '5555')
    if ($tcpipResult.ExitCode -ne 0) {
        throw "Failed to enable TCP/IP mode on $($Device.Serial). Make sure the phone is connected locally over USB and authorized for debugging. adb said: $(($tcpipResult.Output | Out-String).Trim())"
    }

    # Wait for device to reconnect and stabilize after mode switch
    Invoke-Tool -Executable $AdbExecutable -ArgumentList @('-s', $Device.Serial, 'wait-for-device') | Out-Null
    Start-Sleep -Seconds 1

    $ipAddress = Resolve-DeviceWifiIp -AdbExecutable $AdbExecutable -Serial $Device.Serial
    Write-Host "Detected device IP: $ipAddress" -ForegroundColor Green
    $endpoint = "$ipAddress`:5555"

    Connect-AdbTcpEndpoint -AdbExecutable $AdbExecutable -Endpoint $endpoint | Out-Null
    return $endpoint
}

if ($env:SCRCPY_WRAPPER_SKIP_MAIN -ne '1') {
try {
    if ($null -ne $Arguments -and $Arguments.Length -gt 0) {
        $firstArg = $Arguments[0]
        switch ($firstArg) {
            '--help' {
                Show-WrapperHelp
                exit 0
            }
            '-h' {
                Show-WrapperHelp
                exit 0
            }
            '--version' {
                $scrcpyExe = Get-WrapperPath -OverrideValue (Get-ScrcpyExecutablePath) -Label 'scrcpy binary'
                & $scrcpyExe '--version'
                $lastExit = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
                $exitCode = if ($lastExit) { [int]$lastExit.Value } else { 0 }
                exit $exitCode
            }
            '--raw' {
                $rawArgs = @($Arguments | Select-Object -Skip 1)
                if ($rawArgs.Count -eq 0) {
                    throw 'Missing arguments after --raw. Example: scrcpy --raw --fullscreen'
                }

                $scrcpyExe = Get-WrapperPath -OverrideValue (Get-ScrcpyExecutablePath) -Label 'scrcpy binary'
                & $scrcpyExe @rawArgs
                $lastExit = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
                $exitCode = if ($lastExit) { [int]$lastExit.Value } else { 0 }
                exit $exitCode
            }
            default {
                Show-WrapperHelp
                Write-Host ''
                throw "Unknown wrapper argument: $firstArg. Run 'scrcpy' with no arguments for the interactive launcher, or use '--raw' for direct scrcpy flags."
            }
        }
    }

    $scrcpyExe = Get-WrapperPath -OverrideValue (Get-ScrcpyExecutablePath) -Label 'scrcpy binary'
    $adbExe = Get-WrapperPath -OverrideValue (Get-ScrcpyAdbPath) -Label 'adb binary'

    $selectedDevice = $null
    $targetSerial = $null

    while (-not $selectedDevice) {
        $devices = @(Get-AdbDevices -AdbExecutable $adbExe)
        if ($devices.Count -gt 0) {
            Show-DeviceList -Devices $devices
            $selectedDevice = Select-Device -Devices $devices
            Assert-ReadyDevice -Device $selectedDevice
            break
        }

        $noDeviceAction = Show-NoDeviceMenu
        switch ($noDeviceAction) {
            'rescan' {
                continue
            }
            'manual-wireless' {
                $targetSerial = Get-ManualEndpoint
                Connect-AdbTcpEndpoint -AdbExecutable $adbExe -Endpoint $targetSerial | Out-Null
                $selectedDevice = Get-DeviceFromEndpoint -Endpoint $targetSerial
            }
            'exit' {
                Write-Host 'Exiting without starting scrcpy.' -ForegroundColor Yellow
                exit 1
            }
        }
    }

    if (-not $targetSerial) {
        $connectionMode = Get-ConnectionMode
        $targetSerial = $selectedDevice.Serial

        switch ($connectionMode) {
            'usb' {
                Write-Host 'Switching to USB mode (clearing wireless sessions)...' -ForegroundColor Gray
                Invoke-Tool -Executable $adbExe -ArgumentList @('disconnect') | Out-Null
                $targetSerial = $selectedDevice.Serial
            }
            'wireless-bootstrap' {
                $targetSerial = Start-WirelessBootstrap -AdbExecutable $adbExe -Device $selectedDevice
            }
        }
    }

    $videoProfile = Get-VideoProfileSelection
    $audio = Get-AudioSelection
    $scrcpyArgs = @('--serial', $targetSerial) + $videoProfile.Args + $audio.Args
    Invoke-Scrcpy -Executable $scrcpyExe -ArgumentList $scrcpyArgs -DuplicationRequested:$audio.DuplicationRequested
} catch {
    Write-Host ''
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
}
