# free.ps1 -- Linux `free -m` equivalent for Windows
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Linux `free -m`, prints RAM & Swap usage

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    free
#>

function Invoke-Free {
    Write-Host ""
    Write-Host "              total        used        free      committed" -ForegroundColor Cyan
    
    $os = Get-CimInstance Win32_OperatingSystem
    
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1KB)
    $usedMB = $totalMB - $freeMB
    
    $totalVirtual = [math]::Round($os.TotalVirtualMemorySize / 1KB)
    $freeVirtual = [math]::Round($os.FreeVirtualMemory / 1KB)
    $usedVirtual = $totalVirtual - $freeVirtual
    $swapTotal = $totalVirtual - $totalMB
    $swapUsed = $usedVirtual - $usedMB
    $swapFree = $swapTotal - $swapUsed

    $memTag = "Mem:".PadRight(12)
    Write-Host "${memTag}$($totalMB.ToString().PadLeft(8))    $($usedMB.ToString().PadLeft(8))    $($freeMB.ToString().PadLeft(8))       - "
    
    if ($swapTotal -gt 0) {
        $swapTag = "Swap/Page:".PadRight(12)
        Write-Host "${swapTag}$($swapTotal.ToString().PadLeft(8))    $($swapUsed.ToString().PadLeft(8))    $($swapFree.ToString().PadLeft(8))"
    }
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Free
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
