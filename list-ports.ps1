# list-ports.ps1 -- Local Port Scanner
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Port scanner mapping listening TCP/UDP endpoints to absolute process names

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    list-ports
#>

function Invoke-ListPorts {
    $separator = "========================================================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   LISTENING PORTS & ACTIVE SERVICES" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Scanning active TCP/UDP listeners...`r" -NoNewline
    
    try {
        # Get all listening TCP connections
        $tcp = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
        # Get UDP endpoints
        $udp = Get-NetUDPEndpoint -ErrorAction SilentlyContinue
        
        $connections = @($tcp) + @($udp)
        
        if (-not $connections) {
            Write-Host "  [!] No active ports or requires Administrator privileges." -ForegroundColor Yellow
            return
        }

        $tableData = @()
        
        # Cache process info for speed
        $processCache = @{}
        $allProcs = Get-Process -ErrorAction SilentlyContinue | Select-Object Id, ProcessName
        foreach ($p in $allProcs) {
            $processCache[$p.Id] = $p.ProcessName
        }

        foreach ($conn in $connections) {
            $proto = if ($conn.GetType().Name -match "TCP") { "TCP" } else { "UDP" }
            $port = $conn.LocalPort
            $pidNum = $conn.OwningProcess
            
            $procName = if ($processCache.ContainsKey($pidNum)) { $processCache[$pidNum] } else { "Unknown/System" }
            if ($pidNum -eq 4) { $procName = "System" }
            if ($pidNum -eq 0) { $procName = "System Idle" }

            $tableData += [PSCustomObject]@{
                "Protocol"    = $proto
                "Port"        = $port
                "Process PID" = $pidNum
                "App Name"    = $procName
                "Bound IP"    = $conn.LocalAddress
            }
        }

        # Clear scanning text
        Write-Host "                                        `r" -NoNewline

        # Group by port to remove duplicates (e.g., listening on both IPv4/v6)
        $unique = $tableData | Group-Object Port | ForEach-Object { $_.Group | Select-Object -First 1 } | Sort-Object Port

        $unique | Format-Table -AutoSize | Out-String | Write-Host
        
    } catch {
        Write-Host "  [Error] Process failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ListPorts
}

