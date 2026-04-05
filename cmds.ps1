# cmds.ps1 -- Dynamic Help Menu for CustomScripts
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Interactive cheat-sheet, actively reads this Context.md file

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.EXAMPLE
    cmds
#>

function Invoke-Cmds {
    # Dynamically find Context.md in the same directory as this script
    $contextPath = Join-Path $PSScriptRoot "Context.md"
    
    if (-not (Test-Path $contextPath)) {
        Write-Host "  [Error] Context.md not found. Cannot display help." -ForegroundColor Red
        return
    }

    $content = Get-Content $contextPath -Encoding UTF8
    $inTable = $false
    $commands = @()
    
    # Parse the Markdown table under ## Scripts
    foreach ($line in $content) {
        if ($line -match '^\|\s*Script\s*\|') {
            $inTable = $true
            continue
        }
        if ($inTable -and $line -match '^\|--') {
            continue
        }
        if ($inTable -and $line -match '^\|(.*?)\|(.*?)\|') {
            $rawCmd = $matches[1].Trim().Replace('`', '')
            # Clean off extensions so it looks like the actual alias
            $cmdName = $rawCmd.Replace('.ps1', '').Replace('.bat', '')
            $desc = $matches[2].Trim()
            
            $commands += [PSCustomObject]@{ Command = $cmdName; Description = $desc }
        } elseif ($inTable -and $line.Trim() -eq "") {
            $inTable = $false 
            # Break so we don't accidentally parse the 'Linux in Windows' table or other markdown tables
            break 
        }
    }

    # Sort commands alphabetically by name
    $commands = $commands | Sort-Object Command

    Clear-Host
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "               CUSTOM SCRIPTS : COMMAND CHEATSHEET                " -ForegroundColor White
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($cmd in $commands) {
        Write-Host "  " -NoNewline
        Write-Host $cmd.Command.PadRight(18) -ForegroundColor Green -NoNewline
        Write-Host "->  " -ForegroundColor DarkGray -NoNewline
        Write-Host $cmd.Description -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "  TIPS:" -ForegroundColor Yellow
    Write-Host "  * Type '-Help' after almost any command for specific details" -ForegroundColor DarkGray
    Write-Host "  * Use 'setup.ps1 -Update' to refresh required system dependencies" -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Cmds
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
