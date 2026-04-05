# top-proc.ps1 -- Task Manager in Terminal
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
A terminal task manager sorting the Top 15 RAM/CPU apps

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER SortBy
    Specifies the SortBy parameter.

.PARAMETER Top
    Specifies the Top parameter.

.EXAMPLE
    top-proc
#>

param(
    [Parameter(Position=0, HelpMessage="Sort by 'RAM' or 'CPU'")]
    [ValidateSet('RAM', 'CPU', 'ram', 'cpu')]
    [string]$SortBy = 'RAM',

    [Parameter(Position=1, HelpMessage="Number of processes to show")]
    [int]$Top = 15
)

function Invoke-TopProc {
    $separator = "==========================================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   TOP $Top PROCESSES (Sorted by $($SortBy.ToUpper()))" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
    
    # We clear the console's current line to show loading
    Write-Host "  Gathering metrics...`r" -NoNewline -ForegroundColor DarkGray

    $cores = $env:NUMBER_OF_PROCESSORS
    if (-not $cores -or $cores -eq 0) { $cores = 1 }
    $delaySeconds = 0.5

    # Take first sample
    $p1 = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne '' -or $_.WorkingSet -gt 50MB -or $_.CPU -gt 5 } | Select-Object Id, CPU
    
    Start-Sleep -Seconds $delaySeconds
    
    # Take second sample
    $p2 = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne '' -or $_.WorkingSet -gt 50MB -or $_.CPU -gt 5 }

    $procs = @()
    foreach ($proc in $p2) {
        $cpuPerc = 0
        if ($null -ne $proc.CPU) {
            $match = $p1 | Where-Object { $_.Id -eq $proc.Id } | Select-Object -First 1
            if ($match -and $null -ne $match.CPU) {
                # Calculate the difference in Total Processor Time over the delay interval
                $diff = ($proc.CPU - $match.CPU)
                # Distribute the usage over total processor cores (mimics Task Manager)
                $cpuPerc = ($diff / $delaySeconds) * 100 / $cores
                # Cap anomalies
                $cpuPerc = [math]::Min($cpuPerc, 100)
                $cpuPerc = [math]::Max($cpuPerc, 0)
            }
        }
        
        $proc | Add-Member -NotePropertyName "CpuPercent" -NotePropertyValue $cpuPerc -PassThru | Out-Null
        $procs += $proc
    }
    
    if ($SortBy.ToUpper() -eq 'CPU') {
        $sorted = $procs | Sort-Object -Property CpuPercent -Descending | Select-Object -First $Top
    } else {
        # Sort by RAM (WorkingSet)
        $sorted = $procs | Sort-Object -Property WorkingSet -Descending | Select-Object -First $Top
    }

    Write-Host "                      `r" -NoNewline
    
    $tableData = @()
    foreach ($p in $sorted) {
        $ramMB = [math]::Round($p.WorkingSet / 1MB, 2)
        $cpuStr = [math]::Round($p.CpuPercent, 2).ToString() + " %"
        
        $tableData += [PSCustomObject]@{
            "PID"      = $p.Id
            "Name"     = $p.ProcessName
            "RAM (MB)" = $ramMB
            "CPU"      = $cpuStr
            "Title"    = if ($p.MainWindowTitle.Length -gt 30) { $p.MainWindowTitle.Substring(0, 27) + "..." } else { $p.MainWindowTitle }
        }
    }

    $tableData | Format-Table -AutoSize | Out-String | Write-Host

    Write-Host "  [Hint] Use 'kill-port' or 'Stop-Process -Id <PID>' to kill a task." -ForegroundColor DarkGray
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-TopProc
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
