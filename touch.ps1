# touch.ps1 -- Instant File Creator
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Creates empty files or updates existing file timestamps

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    touch
#>

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Path of the file to touch")]
    [string]$Path
)

try {
    if (Test-Path -Path $Path) {
        # File exists, update timestamp
        (Get-Item $Path).LastWriteTime = (Get-Date)
        Write-Host "  [OK] Updated timestamp for: $Path" -ForegroundColor Green
    } else {
        # File doesn't exist, create it
        New-Item -ItemType File -Path $Path -Force | Out-Null
        Write-Host "  [OK] Created new file: $Path" -ForegroundColor Green
    }
} catch {
    Write-Host "  [Error] Failed to touch $Path : $($_.Exception.Message)" -ForegroundColor Red
}

