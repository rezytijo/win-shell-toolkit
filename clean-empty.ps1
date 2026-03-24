# clean-empty.ps1 -- Empty Directory Sweeper
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Bottom-up empty directory scanner and sweeper

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    clean-empty
#>

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Target path to start scanning for empty folders")]
    [string]$Path
)

function Invoke-CleanEmpty {
    $separator = "================================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   EMPTY DIRECTORY SWEEPER" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Host "  [Error] Path is not a directory or does not exist:" -ForegroundColor Red
        Write-Host "          $Path" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "  Target : " -NoNewline -ForegroundColor DarkGray
    Write-Host $Path -ForegroundColor Yellow
    Write-Host "  Scanning recursively...`r" -NoNewline
    
    $deletedCount = 0
    $deletedItems = @()

    try {
        # Go bottom-up to ensure parent folders become empty and are deleted after children
        $directories = Get-ChildItem -Path $Path -Recurse -Directory -ErrorAction SilentlyContinue | 
                       Sort-Object -Property @{ Expression={$_.FullName.Length}; Descending=$true }

        Write-Host "                                   `r" -NoNewline
        
        foreach ($dir in $directories) {
            $items = Get-ChildItem -Path $dir.FullName -Force -ErrorAction SilentlyContinue
            
            if ($items.Count -eq 0) {
                Write-Host "  [Removing] $($dir.FullName)" -ForegroundColor DarkGray
                Remove-Item -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                $deletedCount++
                $deletedItems += $dir.FullName
            }
        }
        
    } catch {
        Write-Host "  [Warning] Some directories were inaccessible: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    if ($deletedCount -gt 0) {
        Write-Host "  [Success] Swept away $deletedCount empty folders." -ForegroundColor Green
    } else {
        Write-Host "  [Clean] No empty folders found in the target path." -ForegroundColor Green
    }

    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CleanEmpty
}

