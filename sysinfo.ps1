# sysinfo.ps1 -- System hardware and OS overview
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Displays quick hardware, OS, and resource usage overview

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    sysinfo
#>

function Invoke-SysInfo {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   SYSTEM INFORMATION" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  Gathering telemetry...`r" -NoNewline
    
    # OS Info
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

    # CPU Info
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuLoad = (Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average

    # RAM Info
    $totalRam = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRam = $totalRam - $freeRam
    $ramPercent = [math]::Round(($usedRam / $totalRam) * 100, 1)

    # Disk Info (Drive C:)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $totalDisk = [math]::Round($disk.Size / 1GB, 2)
    $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedDisk = $totalDisk - $freeDisk
    $diskPercent = [math]::Round(($usedDisk / $totalDisk) * 100, 1)

    # Output
    Write-Host "                          `r" -NoNewline # Clear the 'Gathering...' line

    Write-Host "  Hostname : " -NoNewline -ForegroundColor DarkGray; Write-Host $env:COMPUTERNAME
    Write-Host "  OS       : " -NoNewline -ForegroundColor DarkGray; Write-Host "$($os.Caption) ($($os.OSArchitecture))"
    Write-Host "  Uptime   : " -NoNewline -ForegroundColor DarkGray; Write-Host $uptimeStr -ForegroundColor Green
    
    Write-Host ""
    Write-Host "  [ Hardware ]" -ForegroundColor Cyan
    Write-Host "  CPU      : " -NoNewline -ForegroundColor DarkGray; Write-Host $($cpu.Name.Trim())
    Write-Host "  CPU Load : " -NoNewline -ForegroundColor DarkGray; 
    $cpuColor = if ($cpuLoad -gt 80) { "Red" } elseif ($cpuLoad -gt 50) { "Yellow" } else { "Green" }
    Write-Host "$cpuLoad %" -ForegroundColor $cpuColor

    Write-Host "  RAM Used : " -NoNewline -ForegroundColor DarkGray; Write-Host "$usedRam GB / $totalRam GB ($ramPercent %)"
    Write-Host "  System C : " -NoNewline -ForegroundColor DarkGray; 
    $diskColor = if ($diskPercent -gt 85) { "Red" } elseif ($diskPercent -gt 70) { "Yellow" } else { "White" }
    Write-Host "$freeDisk GB free of $totalDisk GB" -ForegroundColor $diskColor

    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SysInfo
}

