# df.ps1 -- Linux `df -h` equivalent for Windows
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Linux `df -h`, neatly prints Hard Drive disk space & usage

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    df
#>

function Invoke-Df {
    $separator = "========================================================================"
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   DISK SPACE USAGE (Linux 'df -h' style)" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    
    $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -or $_.DriveType -eq 4 }
    
    $table = @()
    foreach ($d in $disks) {
        if ($d.Size -gt 0) {
            $sizeGB = [math]::Round($d.Size / 1GB, 1)
            $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
            $usedGB = $sizeGB - $freeGB
            $usePct = [math]::Round(($usedGB / $sizeGB) * 100, 0)
            
            $fsName = if ($d.VolumeName) { "$($d.DeviceID) ($($d.VolumeName))" } else { $d.DeviceID }
            
            $table += [PSCustomObject]@{
                "Filesystem" = $fsName
                "Type"       = $d.FileSystem
                "Size"       = "$sizeGB G"
                "Used"       = "$usedGB G"
                "Avail"      = "$freeGB G"
                "Use%"       = "$usePct %"
                "Mounted on" = "$($d.DeviceID)\"
            }
        }
    }
    
    $table | Format-Table -AutoSize | Out-String | Write-Host
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Df
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
