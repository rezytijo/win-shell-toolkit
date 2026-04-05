# check-host.ps1 -- IP/Domain intelligence lookup
# 2026-04-05 -- v3.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Performs an IP or Domain intelligence lookup using the ip-api.com JSON API.

.DESCRIPTION
    Retrieves geolocation, ISP, and security details (proxy, VPN, mobile) for a target.
    This script is part of the CustomScripts arsenal.

.PARAMETER Target
    The IP address or Domain name to investigate.

.EXAMPLE
    check-host 8.8.8.8
#>

param(
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true, HelpMessage="Target IP, Domain, or path to a file (.txt, .csv)")]
    [string[]]$Target
)

function Invoke-CheckHost {
    begin {
        $targets = New-Object System.Collections.Generic.List[string]
        $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) v3.5.0"
    }

    process {
        $rawTargets = New-Object System.Collections.Generic.List[string]
        foreach ($t in $Target) {
            if (-not $t) { continue }
            if (Test-Path $t -PathType Leaf -ErrorAction SilentlyContinue) {
                # Handle File Input
                $ext = [System.IO.Path]::GetExtension($t).ToLower()
                if ($ext -eq ".csv") {
                    try {
                        $csv = Import-Csv $t
                        $cols = $csv[0].psobject.Properties.Name
                        $targetCol = $cols | Where-Object { $_ -match "IP|Domain|Target|Host" } | Select-Object -First 1
                        if (-not $targetCol) { $targetCol = $cols[0] }
                        $csv | ForEach-Object { if ($_.($targetCol)) { $rawTargets.Add($_.($targetCol).Trim()) } }
                    } catch { Write-Host "  [Error] Failed to read CSV: $($_.Exception.Message)" -ForegroundColor Red }
                } else {
                    # Assume raw text or txt
                    try {
                       Get-Content $t -ErrorAction SilentlyContinue | ForEach-Object { if ($_) { $rawTargets.Add($_.Trim()) } }
                    } catch { }
                }
            } else {
                # Direct Input
                $rawTargets.Add($t.Trim())
            }
        }

        # Resolve Domains to IPs since /batch only supports IP addresses
        foreach ($val in $rawTargets) {
            if (-not $val) { continue }
            $ipParsed = $null
            if ([System.Net.IPAddress]::TryParse($val, [ref]$ipParsed)) {
                $targets.Add($val)
            } else {
                try {
                    $ips = [System.Net.Dns]::GetHostAddresses($val)
                    # Pick the first IPv4 Address
                    $ipv4 = $ips | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
                    if ($ipv4) {
                        $targets.Add($ipv4.IPAddressToString)
                    } else {
                        Write-Host "  [X] $($val): Could not resolve to an IPv4 address" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  [X] $($val): Could not resolve hostname/domain" -ForegroundColor Red
                }
            }
        }
    }

    end {
        if ($targets.Count -eq 0) {
            Write-Host "  [Error] No valid targets found." -ForegroundColor Red
            return
        }

        Write-Host "`n  ==========================================" -ForegroundColor Cyan
        Write-Host "       IP BATCH INTELLIGENCE LOOKUP" -ForegroundColor White
        Write-Host "       Processing $($targets.Count) target(s)" -ForegroundColor Gray
        Write-Host "  ==========================================`n" -ForegroundColor Cyan

        # Chunk processing: ip-api.com Batch limit is 100 per request
        $chunkSize = 100
        for ($i = 0; $i -lt $targets.Count; $i += $chunkSize) {
            $chunk = $targets[$i .. ($i + $chunkSize - 1)] | Where-Object { $_ }
            
            try {
                $fieldList = "status,message,query,country,regionName,city,zip,isp,org,as,reverse,mobile,proxy,hosting"
                $uri = "http://ip-api.com/batch?fields=$fieldList"
                
                # Send Batch POST request
                $payload = ConvertTo-Json -InputObject @($chunk)
                $response = Invoke-RestMethod -Uri $uri -Method Post -Body $payload -ContentType "application/json" -UserAgent $userAgent -ErrorAction Stop

                foreach ($info in $response) {
                    if ($info.status -eq 'success') {
                        Write-Host "  [OK] $($info.query)" -ForegroundColor Green
                        $details = @(
                            @{ Name = "Location"; Value = "$($info.city), $($info.regionName), $($info.country)" },
                            @{ Name = "ISP/Org";  Value = "$($info.isp) ($($info.org))" },
                            @{ Name = "Security"; Value = "Proxy:$($info.proxy) | Host:$($info.hosting) | Mobile:$($info.mobile)" }
                        )
                        
                        foreach ($d in $details) {
                            if ($d.Value) {
                                Write-Host ("      " + $d.Name.PadRight(10)) -NoNewline -ForegroundColor DarkGray
                                Write-Host ": " -NoNewline -ForegroundColor DarkGray
                                Write-Host $d.Value -ForegroundColor Gray
                            }
                        }
                        Write-Host ""
                    } else {
                        Write-Host "  [X] $($info.query): $($info.message)" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "  [Error] Batch failed at index $($i): $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host "  ==========================================" -ForegroundColor Cyan
        Write-Host "  Done.`n" -ForegroundColor Gray
    }
}

try {
    Invoke-CheckHost
} catch {
    Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
