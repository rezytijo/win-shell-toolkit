# checksum.ps1 -- File Hash Calculator
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Calculates MD5, SHA1, SHA256, SHA512 hashes for any given file

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    checksum
#>

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Path to the file to calculate hashes for")]
    [string]$Path
)

function Invoke-Checksum {
    # Validate file exists
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Host ""
        Write-Host "  [Error] File not found or is a directory: $Path" -ForegroundColor Red
        Write-Host ""
        return
    }

    $file = Get-Item -Path $Path
    $separator = "========================================================================="
    
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   FILE CHECKSUM CALCULATOR" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  File   : $($file.Name)" -ForegroundColor Yellow
    
    # Format size gracefully
    $sizeGB = [math]::Round($file.Length / 1GB, 2)
    $sizeMB = [math]::Round($file.Length / 1MB, 2)
    $sizeKB = [math]::Round($file.Length / 1KB, 2)
    $displaySize = if ($sizeGB -ge 1) { "$sizeGB GB" } elseif ($sizeMB -ge 1) { "$sizeMB MB" } else { "$sizeKB KB" }
    
    Write-Host "  Size   : $displaySize" -ForegroundColor DarkGray
    Write-Host "  Path   : $($file.FullName)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Measuring time so the user knows if it's taking long for big files
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $algorithms = @('MD5', 'SHA1', 'SHA256', 'SHA512')
    
    foreach ($algo in $algorithms) {
        try {
            # Get-FileHash is standard in modern PowerShell
            $hash = (Get-FileHash -Path $file.FullName -Algorithm $algo -ErrorAction Stop).Hash
            $padAlgo = $algo.PadRight(8)
            Write-Host "  $padAlgo : " -NoNewline -ForegroundColor Cyan
            Write-Host $hash -ForegroundColor Green
        } catch {
            $padAlgo = $algo.PadRight(8)
            Write-Host "  $padAlgo : [Error] $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $sw.Stop()
    
    Write-Host ""
    Write-Host "  Calculation finished in $([math]::Round($sw.Elapsed.TotalSeconds, 2)) seconds." -ForegroundColor DarkGray
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Checksum
}

