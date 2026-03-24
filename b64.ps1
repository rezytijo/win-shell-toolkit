# b64.ps1 -- Base64 Encoder/Decoder
# 2026-03-11 -- v1.0.0: Initial version

<#
.SYNOPSIS
Safely encode or decode strings to Base64 in terminal (copies result)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Action
    Specifies the Action parameter.

.PARAMETER Text
    Specifies the Text parameter.

.EXAMPLE
    b64
#>

param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Action: 'encode' or 'decode'")]
    [ValidateSet("encode", "decode")]
    [string]$Action,

    [Parameter(Mandatory=$true, Position=1, HelpMessage="The string to encode/decode")]
    [string]$Text
)

function Invoke-Base64 {
    $separator = "=========================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   BASE64 TOOL" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    try {
        if ($Action -eq "encode") {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
            $result = [Convert]::ToBase64String($bytes)
            
            Write-Host "  Input  : " -NoNewline -ForegroundColor DarkGray
            Write-Host $Text
            Write-Host "  Result : " -NoNewline -ForegroundColor DarkGray
            Write-Host $result -ForegroundColor Green
            
            Set-Clipboard -Value $result
            Write-Host "  [Copied to clipboard!]" -ForegroundColor Yellow
        }
        else {
            $bytes = [Convert]::FromBase64String($Text)
            $result = [System.Text.Encoding]::UTF8.GetString($bytes)
            
            Write-Host "  Input  : " -NoNewline -ForegroundColor DarkGray
            Write-Host $Text
            Write-Host "  Result : " -NoNewline -ForegroundColor DarkGray
            Write-Host $result -ForegroundColor Green
            
            Set-Clipboard -Value $result
            Write-Host "  [Copied to clipboard!]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [Error] Invalid input for base64 $Action." -ForegroundColor Red
        if ($Action -eq "decode") {
            Write-Host "          Make sure the string is a valid Base64 format." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Base64
}

