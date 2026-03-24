# grep.ps1 -- Minimal Linux standard `grep` implementation for PowerShell pipeline 
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Linux `grep`, highlights exact matching pattern in string pipes

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Pattern
    Specifies the Pattern parameter.

.PARAMETER InputObject
    Specifies the InputObject parameter.

.EXAMPLE
    grep
#>

function Invoke-Grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Pattern,
        
        [Parameter(ValueFromPipeline=$true, Position=1)]
        [string[]]$InputObject
    )
    
    process {
        if ($InputObject) {
            foreach ($line in $InputObject) {
                if ($line -match $Pattern) {
                    # Add simple highlight by replacing the matched part with ANSI green
                    # This relies on Windows 10+ ANSI support
                    $highlighted = $line -replace ($Pattern, "`e[32m`$0`e[0m")
                    Write-Host $highlighted
                }
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Grep @args
}

