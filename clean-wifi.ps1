# clean-wifi.ps1 -- Clean up unused Wi-Fi profiles
# 2026-03-11 -- v1.0.0: Initial version with Multi-Select TUI

<#
.SYNOPSIS
Multi-select TUI to batch delete useless/old Wi-Fi profiles

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Options
    Specifies the Options parameter.

.PARAMETER PreSelected
    Specifies the PreSelected parameter.

.PARAMETER Title
    Specifies the Title parameter.

.EXAMPLE
    clean-wifi
#>

function Show-MultiSelectMenu {
    param([array]$Options, [array]$PreSelected, [string]$Title)
    
    $maxDraw = [math]::Min($Options.Count, 15)
    
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor DarkGray
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor DarkGray
    Write-Host "   [UP/DOWN] Move  [SPACE] Toggle  [ENTER] Delete  [ESC] Cancel`n" -ForegroundColor DarkGray
    
    # Pre-allocate lines
    for ($i = 0; $i -lt $maxDraw; $i++) { Write-Host "" }
    $startPos = [console]::CursorTop - $maxDraw
    
    $selectedIndex = 0
    $topIndex = 0
    [console]::CursorVisible = $false
    
    $selections = @{}
    foreach ($opt in $Options) { 
        $selections[$opt] = ($PreSelected -contains $opt)
    }

    try {
        while ($true) {
            if ($selectedIndex -ge $topIndex + $maxDraw) { $topIndex = $selectedIndex - $maxDraw + 1 }
            if ($selectedIndex -lt $topIndex) { $topIndex = $selectedIndex }

            for ($i = 0; $i -lt $maxDraw; $i++) {
                $optIndex = $topIndex + $i
                [console]::SetCursorPosition(0, $startPos + $i)
                [console]::Write("".PadRight([console]::WindowWidth - 1))
                [console]::SetCursorPosition(0, $startPos + $i)
                
                if ($optIndex -lt $Options.Count) {
                    $text = $Options[$optIndex]
                    if ($text.Length -gt ([console]::WindowWidth - 15)) {
                        $text = $text.Substring(0, [console]::WindowWidth - 18) + "..."
                    }
                    
                    $box = if ($selections[$Options[$optIndex]]) { "[X]" } else { "[ ]" }
                    
                    # Highlight colors depending on selections
                    if ($optIndex -eq $selectedIndex) {
                        Write-Host "  > $box $text " -BackgroundColor Gray -ForegroundColor Black
                    } else {
                        if ($selections[$Options[$optIndex]]) {
                            Write-Host "    $box $text " -ForegroundColor Red
                        } else {
                            Write-Host "    $box $text " -ForegroundColor White
                        }
                    }
                }
            }
            
            $key = [console]::ReadKey($true).Key
            if ($key -eq 'UpArrow') {
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            } elseif ($key -eq 'DownArrow') {
                if ($selectedIndex -lt ($Options.Count - 1)) { $selectedIndex++ }
            } elseif ($key -eq 'Spacebar') {
                $opt = $Options[$selectedIndex]
                $selections[$opt] = -not $selections[$opt]
            } elseif ($key -eq 'Enter') {
                [console]::SetCursorPosition(0, $startPos + $maxDraw)
                Write-Host ""
                $result = @()
                foreach ($opt in $Options) { if ($selections[$opt]) { $result += $opt } }
                return $result
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

function Invoke-CleanWiFi {
    Write-Host "  [*] Scanning Wi-Fi networks...`r" -NoNewline -ForegroundColor DarkGray
    
    $tempDir = Join-Path $env:TEMP "WifiDump_$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    netsh wlan export profile folder=$tempDir | Out-Null
    $xmlFiles = Get-ChildItem -Path $tempDir -Filter "*.xml"
    
    $allProfiles = @()
    $openProfiles = @()
    
    foreach ($f in $xmlFiles) {
        try {
            [xml]$xml = Get-Content $f.FullName -ErrorAction SilentlyContinue
            $name = $xml.WLANProfile.name
            $auth = $xml.WLANProfile.MSM.security.authEncryption.authentication
            
            if ($name) {
                $allProfiles += $name
                if ($auth -eq 'open') {
                    $openProfiles += $name
                }
            }
        } catch {}
    }
    
    Remove-Item -Path $tempDir -Recurse -Force
    
    if ($allProfiles.Count -eq 0) {
        Write-Host "  [!] No Wi-Fi profiles found." -ForegroundColor Red
        return
    }

    # Sort Alphabetically A-Z
    $allProfiles = $allProfiles | Sort-Object

    Write-Host "                                  `r" -NoNewline
    
    $toDelete = Show-MultiSelectMenu -Options $allProfiles -PreSelected $openProfiles -Title "CLEAN WI-FI (Open networks are pre-selected to delete)"
    
    if ($toDelete -eq $null) {
        Write-Host "  [Canceled] No profiles deleted." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    
    if ($toDelete.Count -eq 0) {
        Write-Host "  [OK] No profiles selected for deletion." -ForegroundColor Green
        Write-Host ""
        return
    }
    
    Write-Host "  Deleting $($toDelete.Count) profile(s)..." -ForegroundColor Yellow
    foreach ($prof in $toDelete) {
        netsh wlan delete profile name="$prof" | Out-Null
        Write-Host "    [-] Deleted: $prof" -ForegroundColor DarkGray
    }
    
    Write-Host "  [Success] Wipe out complete!" -ForegroundColor Green
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CleanWiFi
}

