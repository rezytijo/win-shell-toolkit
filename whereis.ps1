# whereis.ps1 -- Find the full path of executable files (Linux `which`/`whereis` equivalent)
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Linux `which`, outputs execution path of any command/alias

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER CommandName
    Specifies the CommandName parameter.

.EXAMPLE
    whereis
#>

function Invoke-WhereIs {
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Name of the executable or command (e.g. 'python', 'docker')")]
        [string]$CommandName
    )
    
    Write-Host ""
    $results = Get-Command $CommandName -ErrorAction SilentlyContinue
    
    if (-not $results) {
        Write-Host "  [!] Command '$CommandName' not found in system Path." -ForegroundColor Red
        Write-Host ""
        return
    }
    
    foreach ($r in $results) {
        if ($r.CommandType -eq 'Application') {
            Write-Host "  $($r.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host " -> " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($r.Source)" -ForegroundColor Green
        } elseif ($r.CommandType -eq 'Alias' -or $r.CommandType -eq 'Function') {
            Write-Host "  $($r.Name)" -ForegroundColor Yellow -NoNewline
            Write-Host " -> " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($r.CommandType) ($($r.Definition))" -ForegroundColor White
        }
    }
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WhereIs @args
}

