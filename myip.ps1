# myip.ps1 -- Shows public and private IP/network information
# 2026-04-05 -- v2.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Shows public IP + private network info (interface, SSID, signal, tunnel detection)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    myip
#>

function Show-MyIP {
    $separator = "=========================================="

    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   YOUR NETWORK INFORMATION" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray

    # ================================================================
    # [1/2] PUBLIC IP (via ip-api.com, 45 req/min limit)
    # ================================================================
    Write-Host ""
    Write-Host "--- Public IP ---" -ForegroundColor Yellow

    try {
        $pub = Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=status,message,query,country,regionName,city,zip,isp,org,as,timezone,mobile,proxy,hosting' -ErrorAction Stop
        if ($pub.status -eq 'success') {
            Write-Host "  IP           : " -NoNewline; Write-Host $pub.query -ForegroundColor Green
            Write-Host "  Location     : $($pub.city), $($pub.regionName), $($pub.country)"
            Write-Host "  ZIP          : $($pub.zip)"
            Write-Host "  Timezone     : $($pub.timezone)"
            Write-Host "  ISP          : $($pub.isp)"
            Write-Host "  Organization : $($pub.org)"
            Write-Host "  AS           : $($pub.as)"
            Write-Host "  Mobile       : $($pub.mobile)"
            Write-Host "  Proxy/VPN    : $($pub.proxy)"
            Write-Host "  Hosting/DC   : $($pub.hosting)"
        } else {
            Write-Host "  Query failed: $($pub.message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  Failed to fetch: $($_.Exception.Message)" -ForegroundColor Red
    }

    # ================================================================
    # [2/2] PRIVATE NETWORK
    # ================================================================
    Write-Host ""
    Write-Host "--- Private Network ---" -ForegroundColor Yellow

    # Pattern for known tunnel/VPN virtual adapters
    $tunnelPatterns = 'tunnel|virtual|vpn|tap(\d|-)| tun(\d|-)|wintun|wireguard|cloudflare|warp|zerotier|hamachi|openconnect|fortinet|cisco|juniper'

    # Find default route to determine active internet interface
    $defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object -Property RouteMetric |
        Select-Object -First 1

    if (-not $defaultRoute) {
        Write-Host "  No active internet connection detected." -ForegroundColor Red
        Write-Host ""
        Write-Host $separator -ForegroundColor DarkGray
        return
    }

    $defaultIfIndex = $defaultRoute.InterfaceIndex
    $defaultAdapter = Get-NetAdapter -InterfaceIndex $defaultIfIndex -ErrorAction SilentlyContinue

    # Detect if default route goes through a tunnel/VPN
    $isTunnel = $defaultAdapter -and (
        (-not $defaultAdapter.HardwareInterface) -or
        ($defaultAdapter.InterfaceDescription -match $tunnelPatterns)
    )

    if ($isTunnel) {
        $tunnelIP = (Get-NetIPAddress -InterfaceIndex $defaultIfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object -First 1).IPAddress

        Write-Host ""
        Write-Host "  [Tunnel/VPN Active]" -ForegroundColor Magenta
        Write-Host "  Interface    : $($defaultAdapter.Name)"
        Write-Host "  Description  : $($defaultAdapter.InterfaceDescription)"
        Write-Host "  Tunnel IP    : $tunnelIP"
        Write-Host "  Status       : $($defaultAdapter.Status)"
    }

    # --- Resolve primary PHYSICAL adapter ---
    if ($isTunnel) {
        # When tunnel is active, find the underlying hardware adapter
        $primaryAdapter = Get-NetAdapter | Where-Object {
            $_.Status -eq 'Up' -and
            $_.HardwareInterface -eq $true -and
            $_.InterfaceDescription -notmatch $tunnelPatterns
        } | Where-Object {
            $ip = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $ip -and $ip.IPAddress -ne '127.0.0.1'
        } | Select-Object -First 1
    } else {
        $primaryAdapter = $defaultAdapter
    }

    if (-not $primaryAdapter) {
        Write-Host "  No physical network adapter found." -ForegroundColor Red
        Write-Host ""
        Write-Host $separator -ForegroundColor DarkGray
        return
    }

    # --- Gather network details ---
    $ipInfo = Get-NetIPAddress -InterfaceIndex $primaryAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' } |
        Select-Object -First 1

    $adapterGateway = (Get-NetRoute -InterfaceIndex $primaryAdapter.InterfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Select-Object -First 1).NextHop

    $dns = (Get-DnsClientServerAddress -InterfaceIndex $primaryAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses

    # --- Display primary interface info ---
    Write-Host ""
    Write-Host "  [Primary Interface]" -ForegroundColor Cyan
    Write-Host "  Interface    : $($primaryAdapter.Name)"
    Write-Host "  Description  : $($primaryAdapter.InterfaceDescription)"
    Write-Host "  MAC Address  : $($primaryAdapter.MacAddress)"
    Write-Host "  Link Speed   : $($primaryAdapter.LinkSpeed)"
    # Convert prefix length to subnet mask (e.g., /24 -> 255.255.255.0)
    $prefixLen = $ipInfo.PrefixLength
    $maskInt = [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefixLen))
    $maskBytes = [BitConverter]::GetBytes($maskInt)
    [Array]::Reverse($maskBytes)
    $subnetMask = ($maskBytes | ForEach-Object { $_.ToString() }) -join '.'

    Write-Host "  Private IP   : " -NoNewline; Write-Host "$($ipInfo.IPAddress)/$prefixLen" -ForegroundColor Green
    Write-Host "  Subnet       : $subnetMask"

    if ($adapterGateway) {
        Write-Host "  Gateway      : $adapterGateway"
    }
    if ($dns -and $dns.Count -gt 0) {
        Write-Host "  DNS Servers  : $($dns -join ', ')"
    }

    # --- WiFi-specific details (SSID, signal, band, channel) ---
    $isWiFi = $primaryAdapter.Name -match 'Wi-?Fi|Wireless' -or
              $primaryAdapter.InterfaceDescription -match 'Wireless|802\.11|WiFi'

    if ($isWiFi) {
        try {
            $wlanOutput = netsh wlan show interfaces 2>$null
            if ($wlanOutput) {
                $fields = @(
                    @{ Pattern = '^\s+SSID\s+:\s+';           Label = 'Network SSID' }
                    @{ Pattern = '^\s+Signal\s+:\s+';         Label = 'Signal' }
                    @{ Pattern = '^\s+Authentication\s+:\s+'; Label = 'Auth' }
                    @{ Pattern = '^\s+Band\s+:\s+';           Label = 'Band' }
                    @{ Pattern = '^\s+Channel\s+:\s+';        Label = 'Channel' }
                    @{ Pattern = '^\s+Radio type\s+:\s+';     Label = 'Radio Type' }
                )

                foreach ($field in $fields) {
                    $match = $wlanOutput | Select-String $field.Pattern | Select-Object -First 1
                    if ($match) {
                        $value = ($match.Line -replace $field.Pattern, '').Trim()
                        $padded = $field.Label.PadRight(12)
                        Write-Host "  $padded : $value"
                    }
                }
            }
        } catch {
            # Silently ignore WiFi info errors (no wireless adapter)
        }
    }

    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

# Run if executed directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Show-MyIP
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
