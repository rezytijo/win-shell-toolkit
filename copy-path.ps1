# copy-path.ps1 -- Quick Path Copier
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Instantly grabs absolute path of any typed file/folder into clipboard

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    copy-path
#>

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="File or directory path to copy")]
    [string]$Path
)

function Invoke-CopyPath {
    $separator = "======================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   INSTANT PATH COPIER" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
    
    # Resolve absolute path (supports relative paths like .\ or ..\)
    try {
        if (Test-Path -Path $Path) {
            $absPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
            Set-Clipboard -Value $absPath
            
            Write-Host "  [Resolving...] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Path
            Write-Host ""
            Write-Host "  Absolute Path : " -NoNewline -ForegroundColor Cyan
            Write-Host $absPath -ForegroundColor Green
            Write-Host ""
            Write-Host "  [Success] Saved to clipboard!" -ForegroundColor Yellow
        } else {
            Write-Host "  [Error] Path does not exist or is inaccessible:" -ForegroundColor Red
            Write-Host "          $Path" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  [Error] Unable to resolve path: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-CopyPath
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
