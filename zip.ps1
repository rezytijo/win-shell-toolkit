# zip.ps1 -- Instant Compression Utility
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Lightning fast directory to `.zip` file compressor

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER DestinationPath
    Specifies the DestinationPath parameter.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    zip
#>

function Invoke-Zip {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Target Zip File Name")]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true, HelpMessage="Files or Folders to Zip")]
        [string[]]$Path
    )
    
    if (-not $DestinationPath.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
        $DestinationPath += ".zip"
    }
    
    Write-Host "  [*] Compressing into $DestinationPath ..." -ForegroundColor DarkGray
    
    try {
        Compress-Archive -Path $Path -DestinationPath $DestinationPath -Update -Force -ErrorAction Stop
        Write-Host "  [OK] Zipped successfully." -ForegroundColor Green
    } catch {
        Write-Host "  [Error] Compression failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Zip @args
}

