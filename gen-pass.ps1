# gen-pass.ps1 -- Password Generator
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Generates secure random passwords and copies to clipboard

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Length
    Specifies the Length parameter.

.PARAMETER NoSymbols
    Specifies the NoSymbols parameter.

.EXAMPLE
    gen-pass
#>

param(
    [int]$Length = 16,
    [switch]$NoSymbols
)

function Invoke-GenPass {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   SECURE PASSWORD GENERATOR" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    $upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower   = "abcdefghijklmnopqrstuvwxyz"
    $numbers = "0123456789"
    $symbols = "!@#$%^&*"

    # Require at least one from each character set
    $charSets = @($upper, $lower, $numbers)
    if (-not $NoSymbols) {
        $charSets += $symbols
    } else {
        Write-Host "  [Info] Symbols excluded." -ForegroundColor DarkGray
    }

    $password = ""
    # Ensure at least one character from required sets
    foreach ($set in $charSets) {
        $password += $set[(Get-Random -Maximum $set.Length)]
    }

    # Generate remaining characters
    $allPool = $charSets -join ''
    while ($password.Length -lt $Length) {
        $password += $allPool[(Get-Random -Maximum $allPool.Length)]
    }

    # Shuffle the characters to randomize positions
    $shuffledBytes = New-Object byte[] $password.Length
    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($shuffledBytes)
    
    $charArray = $password.ToCharArray()
    [Array]::Sort($shuffledBytes, $charArray)

    $finalPassword = -join $charArray
    
    # Copy to clipboard
    Set-Clipboard -Value $finalPassword

    Write-Host "  Length   : $Length characters" -ForegroundColor DarkGray
    Write-Host "  Password : " -NoNewline
    Write-Host $finalPassword -ForegroundColor Green
    
    Write-Host ""
    Write-Host "  [Copied to clipboard!]" -ForegroundColor Yellow
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-GenPass
}

