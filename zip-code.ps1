# zip-code.ps1 -- AI-Ready Codebase Packager
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Packs the current codebase into a ZIP file while respecting ignore files.

.DESCRIPTION
    Zips the current directory with a root folder structure.
    Automatically excludes files/folders listed in .gitignore or .dockerignore.
    Useful for sharing code or creating backups without junk files.
    This script is part of the CustomScripts arsenal.

.PARAMETER Name
    Optional name for the output zip file. Defaults to FolderName_Timestamp.zip

.EXAMPLE
    zip-code
#>

param(
    [Parameter(Position=0)]
    [string]$ZipName = ""
)

function Invoke-ZipCode {
    $currentDir = Get-Item .
    $projectName = $currentDir.Name
    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"

    if (-not $ZipName) {
        $ZipName = "$($projectName)_$($timestamp).zip"
    } elseif (-not $ZipName.EndsWith(".zip")) {
        $ZipName += ".zip"
    }

    Write-Host "`n  [*] Packaging Codebase: " -NoNewline; Write-Host $projectName -ForegroundColor Cyan
    Write-Host "  [*] Output File: " -NoNewline; Write-Host $ZipName -ForegroundColor Yellow

    # --- 1. Identify Ignore Patterns ---
    $ignorePatterns = @(
        ".git/", ".svn/", ".hg/", "node_modules/", "venv/", ".venv/", "env/", "bin/", "obj/", "target/", "dist/", "build/", ".agent/brain/", ".agent/logs/"
    )

    if (Test-Path ".gitignore") {
        $ignorePatterns += Get-Content ".gitignore" | Where-Object { $_.Trim() -and -not $_.StartsWith("#") }
    }
    if (Test-Path ".dockerignore") {
        $ignorePatterns += Get-Content ".dockerignore" | Where-Object { $_.Trim() -and -not $_.StartsWith("#") }
    }

    # Clean patterns (convert glob to simple contains or relative path checks)
    $refinedPatterns = $ignorePatterns | ForEach-Object {
        $p = $_.Replace("\", "/").TrimStart("./").TrimEnd("/")
        if ($p) { $p }
    } | Select-Object -Unique

    # --- 2. Filter Files ---
    Write-Host "  [*] Filtering files based on ignore rules..." -ForegroundColor DarkGray
    $filesToZip = Get-ChildItem -Path . -Recurse | Where-Object { -not $_.PSIsContainer }

    $filteredFiles = $filesToZip | Where-Object {
        $relativePath = $_.FullName.Replace($currentDir.FullName, "").TrimStart("\").Replace("\", "/")
        $isIgnored = $false
        
        # Exclude the output zip itself
        if ($_.Name -eq $ZipName) { $isIgnored = $true }
        
        foreach ($pattern in $refinedPatterns) {
            if ($relativePath -like "*$pattern*" -or $relativePath.StartsWith($pattern)) {
                $isIgnored = $true
                break
            }
        }
        -not $isIgnored
    }

    # --- 3. Create Temporary Structure ---
    # To ensure the zip contains "Folder -> Files", we copy to a temp location
    $tempRoot = Join-Path $env:TEMP "zipcode_$timestamp"
    $tempProjectFolder = Join-Path $tempRoot $projectName

    Write-Host "  [*] Preparing archive structure..." -ForegroundColor DarkGray
    if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $tempProjectFolder -Force | Out-Null

    foreach ($file in $filteredFiles) {
        $targetFile = $file.FullName.Replace($currentDir.FullName, $tempProjectFolder)
        $targetDir = Split-Path $targetFile
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        Copy-Item $file.FullName -Destination $targetFile -Force
    }

    # --- 4. Compress ---
    Write-Host "  [*] Compressing..." -ForegroundColor DarkGray
    try {
        # Delete old zip if exists
        if (Test-Path $ZipName) { Remove-Item $ZipName -Force }
        
        Compress-Archive -Path "$tempProjectFolder" -DestinationPath "$ZipName" -Force -ErrorAction Stop
        
        # Cleanup
        Remove-Item $tempRoot -Recurse -Force
        
        Write-Host "`n  ========================================" -ForegroundColor Green
        Write-Host "     ✅ Codebase Packed Successfully!" -ForegroundColor White
        Write-Host "  ========================================" -ForegroundColor Green
        Write-Host "  File: $ZipName"
        Write-Host "  Size: $(( (Get-Item $ZipName).Length / 1KB ).ToString('F2')) KB"
        Write-Host ""
    } catch {
        Write-Host "`n  [Error] Compression failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ZipCode
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
