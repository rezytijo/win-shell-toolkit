# wifi-pass.ps1 -- Extract saved Wi-Fi passwords
# 2026-03-11 -- v2.0.0: Added interactive TUI menu

<#
.SYNOPSIS
Interactive TUI to select and extract saved Wi-Fi passwords

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Options
    Specifies the Options parameter.

.PARAMETER Title
    Specifies the Title parameter.

.EXAMPLE
    wifi-pass
#>

function Show-Menu {
    param([array]$Options, [string]$Title)
    
    $maxDraw = [math]::Min($Options.Count, 15)
    
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor DarkGray
    Write-Host "   [UP/DOWN] Select   [ENTER] Confirm   [ESC] Cancel`n" -ForegroundColor DarkGray
    
    # Pre-allocate lines to force screen scroll if at bottom
    for ($i = 0; $i -lt $maxDraw; $i++) { Write-Host "" }
    $startPos = [console]::CursorTop - $maxDraw
    
    $selectedIndex = 0
    $topIndex = 0
    [console]::CursorVisible = $false

    try {
        while ($true) {
            # Pagination Logic
            if ($selectedIndex -ge $topIndex + $maxDraw) { $topIndex = $selectedIndex - $maxDraw + 1 }
            if ($selectedIndex -lt $topIndex) { $topIndex = $selectedIndex }

            for ($i = 0; $i -lt $maxDraw; $i++) {
                $optIndex = $topIndex + $i
                [console]::SetCursorPosition(0, $startPos + $i)
                [console]::Write("".PadRight([console]::WindowWidth - 1))
                [console]::SetCursorPosition(0, $startPos + $i)
                
                if ($optIndex -lt $Options.Count) {
                    $text = $Options[$optIndex]
                    if ($text.Length -gt ([console]::WindowWidth - 10)) {
                        $text = $text.Substring(0, [console]::WindowWidth - 13) + "..."
                    }
                    if ($optIndex -eq $selectedIndex) {
                        Write-Host "  > $text " -BackgroundColor Gray -ForegroundColor Black
                    } else {
                        Write-Host "    $text " -ForegroundColor White
                    }
                }
            }
            
            $key = [console]::ReadKey($true).Key
            if ($key -eq 'UpArrow') {
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            } elseif ($key -eq 'DownArrow') {
                if ($selectedIndex -lt ($Options.Count - 1)) { $selectedIndex++ }
            } elseif ($key -eq 'Enter') {
                [console]::SetCursorPosition(0, $startPos + $maxDraw)
                Write-Host ""
                return $Options[$selectedIndex]
            } elseif ($key -eq 'Escape') {
                [console]::SetCursorPosition(0, $startPos + $maxDraw)
                Write-Host ""
                return $null
            }
        }
    } finally {
        [console]::CursorVisible = $true
    }
}

function Invoke-WiFiPass {
    Write-Host "  [*] Scanning secured Wi-Fi networks...`r" -NoNewline -ForegroundColor DarkGray
    
    $tempDir = Join-Path $env:TEMP "WifiDump_$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Export profiles as XML to rapidly read their authentication flags (ignores OS language)
    netsh wlan export profile folder=$tempDir | Out-Null
    $xmlFiles = Get-ChildItem -Path $tempDir -Filter "*.xml"
    
    $profiles = @()
    foreach ($f in $xmlFiles) {
        try {
            [xml]$xml = Get-Content $f.FullName -ErrorAction SilentlyContinue
            $name = $xml.WLANProfile.name
            $auth = $xml.WLANProfile.MSM.security.authEncryption.authentication
            
            # Filter out open (no password) networks
            if ($name -and $auth -and $auth -ne 'open') {
                $profiles += $name
            }
        } catch {}
    }
    
    Remove-Item -Path $tempDir -Recurse -Force
    
    # Sort Ascending A-Z
    $profiles = $profiles | Sort-Object

    Write-Host "                                        `r" -NoNewline

    if ($profiles.Count -eq 0) {
        Write-Host "  [!] No Wi-Fi profiles found on this system." -ForegroundColor Red
        return
    }

    $selected = Show-Menu -Options $profiles -Title "SAVED WI-FI PASSWORDS"
    
    if (-not $selected) {
        Write-Host "  [Canceled] No profile selected." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $profileInfo = netsh wlan show profile name="$selected" key=clear
    $password = "[No Password / Open]"
    
    foreach ($line in $profileInfo) {
        if ($line -match 'Key Content\s+:\s+(.+)$') {
            $password = $matches[1].Trim()
            break
        }
    }

    Write-Host "  Wi-Fi Name : " -NoNewline; Write-Host $selected -ForegroundColor Cyan
    Write-Host "  Password   : " -NoNewline; Write-Host $password -ForegroundColor Green
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WiFiPass
}

