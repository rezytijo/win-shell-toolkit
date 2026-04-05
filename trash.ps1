# trash.ps1 -- Move items to Windows Recycle Bin instead of permadelete (Linux safe-rm equivalent)
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Native safe `rm`, moves items to Recycle Bin directly

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Path
    Specifies the Path parameter.

.EXAMPLE
    trash
#>

function Invoke-Trash {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, HelpMessage="Files or Folders to move to Recycle Bin")]
        [Alias('FullName')]
        [string[]]$Path
    )
    
    begin {
        Add-Type -AssemblyName "Microsoft.VisualBasic"
    }
    
    process {
        foreach ($p in $Path) {
            # Handle each path, potentially resolving wildcards if they weren't expanded yet
            $resolved = Get-Item -Path $p -ErrorAction SilentlyContinue -Force
            if (-not $resolved) {
                Write-Host "  [Error] Path '$p' not found." -ForegroundColor Red
                continue
            }
            
            foreach ($item in $resolved) {
                $fullPath = $item.FullName
                if ($PSCmdlet.ShouldProcess($fullPath, "Move to Recycle Bin")) {
                    try {
                        if ($item -is [System.IO.DirectoryInfo]) {
                            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($fullPath, 'OnlyErrorDialogs', 'SendToRecycleBin')
                        } else {
                            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($fullPath, 'OnlyErrorDialogs', 'SendToRecycleBin')
                        }
                        Write-Host "  [Trashed] $fullPath -> Recycle Bin" -ForegroundColor DarkGray
                    } catch {
                        Write-Host "  [Error] Failed to trash '$fullPath': $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($args.Count -gt 0) {
            Invoke-Trash -Path $args
        } else {
            Write-Host "Usage: trash <file1> [file2] [*.ext]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
