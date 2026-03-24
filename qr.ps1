# qr.ps1 -- ASCII QR Code Generator via qrenco.de
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Offline generator creating and opening a high-res QR code PNG

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER InputStrings
    Specifies the InputStrings parameter.

.EXAMPLE
    qr
#>

param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true, HelpMessage="Text or URL to encode")]
    $InputStrings
)

if (-not $InputStrings) {
    Write-Host "  [!] Usage: qr 'https://example.com'" -ForegroundColor Yellow
    return
}

# The user might not quote strings with spaces, so $InputStrings could be an array of arguments
$Text = $InputStrings -join ' '
$encodedText = [uri]::EscapeDataString($Text)

Write-Host "  Generating QR Code for: " -NoNewline -ForegroundColor DarkGray
Write-Host "'$Text'`r" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Generating offline QR Code..." -ForegroundColor DarkGray
Write-Host ""
    
try {
    # Ensure module is available
    if (-not (Get-Module -ListAvailable -Name QRCodeGenerator)) {
        Write-Host "  [*] First time setup: Installing offline QRCodeGenerator module..." -ForegroundColor Yellow
        Install-Module -Name QRCodeGenerator -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    }

    $outPath = Join-Path $env:TEMP "qr_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
    
    # Generate and auto-show
    New-PSOneQRCodeText -Text $Text -Width 400 -OutPath $outPath -Show -ErrorAction Stop
    
    Write-Host "  [Success] High-Res QR Code graphic opened in your image viewer!" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  [Error] Failed to generate offline QR Code: $($_.Exception.Message)" -ForegroundColor Red
}

