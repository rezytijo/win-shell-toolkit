# ll.ps1 -- Modern dir / ls -la with human-readable sizes and hidden tracking
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Linux `ls -la`, cleanly displays directory items with sizes

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    ll
#>

function Invoke-LL {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        [string[]]$Path = "."
    )
    
    $pString = $Path -join ' '
    
    Write-Host ""
    Write-Host " Directory: $(Convert-Path $pString -ErrorAction SilentlyContinue)" -ForegroundColor Cyan
    Write-Host ""
    
    $items = Get-ChildItem -Path $pString -Force -ErrorAction SilentlyContinue | Sort-Object @{Expression={$_.PSIsContainer};Descending=$true}, Name
    
    if (-not $items) {
        Write-Host "  (Empty Directory)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    
    $table = @()
    foreach ($item in $items) {
        # Determine Mode Attributes (like UNIX)
        $mode = $item.Mode
        
        # Calculate Human-readable Size
        $sizeStr = ""
        if (-not $item.PSIsContainer) {
            if ($item.Length -ge 1GB) { $sizeStr = "{0:N2} GB" -f ($item.Length / 1GB) }
            elseif ($item.Length -ge 1MB) { $sizeStr = "{0:N2} MB" -f ($item.Length / 1MB) }
            elseif ($item.Length -ge 1KB) { $sizeStr = "{0:N2} KB" -f ($item.Length / 1KB) }
            else { $sizeStr = "{0} B" -f $item.Length }
        } else {
            $sizeStr = "<DIR>"
        }
        
        # Determine colorization based on hidden/directory status
        $nameDisplay = $item.Name
        # Note: Colored formatting inside PS objects is tricky without breaking table alignment,
        # so we will use a plain string here, but add an indicator if Hidden.
        if ($mode -match 'h') { $nameDisplay = "[H] $nameDisplay" }
        if ($item.PSIsContainer) { $nameDisplay = "$nameDisplay\" }
        
        $table += [PSCustomObject]@{
            "Mode"       = $mode
            "LastWrite"  = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            "Size"       = $sizeStr.PadLeft(10)
            "Name"       = $nameDisplay
        }
    }
    
    $table | Format-Table -AutoSize | Out-String | Write-Host
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-LL @args
}

