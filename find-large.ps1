# find-large.ps1 -- Find large files taking up disk space
# 2026-04-14 -- v1.0.2: Fixed param block positioning
<#
.SYNOPSIS
Storage analyzer to locate largest files in a directory

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.PARAMETER Top
    Specifies the Top parameter.

.PARAMETER MinSize
    Specifies the MinSize parameter.

.EXAMPLE
    find-large
#>

param(
    [string]$Path = "C:\Users\$env:USERNAME",
    [int]$Top = 15,
    [string]$MinSize = "500MB"
)

$ErrorActionPreference = 'Stop'

function Invoke-FindLargeFiles {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   STORAGE ANALYZER (Large Files)" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    
    # Parse MinSize to bytes
    $minSizeBytes = 0
    if ($MinSize -match '^(\d+)\s*(MB|GB)$') {
        $val = [int]$matches[1]
        $unit = $matches[2]
        if ($unit -eq 'MB') { $minSizeBytes = $val * 1MB }
        if ($unit -eq 'GB') { $minSizeBytes = $val * 1GB }
    } else {
        Write-Host "[Error] MinSize format invalid. Use e.g. '500MB' or '1GB'." -ForegroundColor Red
        return
    }

    Write-Host "  Path     : $Path" -ForegroundColor DarkGray
    Write-Host "  Min Size : $MinSize" -ForegroundColor DarkGray
    Write-Host "  Top      : $Top results" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [Scanning... This may take a moment depending on the path size]" -ForegroundColor Yellow
    Write-Host ""

    # Measure command execution time
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { $_.Length -ge $minSizeBytes } |
                 Sort-Object -Property Length -Descending |
                 Select-Object -First $Top

        $sw.Stop()

        if (-not $files) {
            Write-Host "  [!] No files found larger than $MinSize in $Path" -ForegroundColor Green
        } else {
            $tableData = @()
            foreach ($file in $files) {
                $sizeGB = [math]::Round($file.Length / 1GB, 2)
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                $displaySize = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }

                $tableData += [PSCustomObject]@{
                    Size = $displaySize
                    Name = $file.Name
                    Location = $file.DirectoryName
                }
            }

            $tableData | Format-Table -Property Size, Name, Location -AutoSize | Out-String | Write-Host
        }
        
    } catch {
        Write-Host "  [Error] Failed to scan path: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "  Scan completed in $([math]::Round($sw.Elapsed.TotalSeconds, 1)) seconds." -ForegroundColor DarkGray
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-FindLargeFiles
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
