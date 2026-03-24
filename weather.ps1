# weather.ps1 -- Terminal Weather via wttr.in
# 2026-03-11 -- v1.2.0: Integrated Windows Geolocation API for pinpoint accuracy

<#
.SYNOPSIS
Terminal weather using Windows Location Services (or IP/Manual fallback)

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Location
    Specifies the Location parameter.

.PARAMETER Update
    Specifies the Update parameter.

.EXAMPLE
    weather
#>

param(
    [Parameter(Position=0, HelpMessage="Optional specific location (e.g., 'Jakarta' or 'Tokyo')")]
    [string]$Location = "",
    
    [switch]$Update
)

$configFile = "$env:USERPROFILE\.weather_location"

if ($Update) {
    if (Test-Path $configFile) { Remove-Item $configFile -Force }
    $Location = ""
}

Write-Host "  Gathering atmospheric & satellite data...`r" -NoNewline -ForegroundColor DarkGray

# Function to attempt fetching coords via Windows Location Platform
function Get-WindowsLocation {
    try {
        Add-Type -AssemblyName System.Device
        # Use High Accuracy to trigger Wi-Fi/GPS positioning
        $watcher = New-Object System.Device.Location.GeoCoordinateWatcher([System.Device.Location.GeoPositionAccuracy]::High)
        
        $watcher.Start()
        
        # Poll up to ~5 seconds (10 x 500ms) until a location is found
        $retries = 10
        while ($watcher.Status -ne 'Ready' -and $retries -gt 0) {
            Start-Sleep -Milliseconds 500
            $retries--
        }

        # Sometimes Status is Ready but Position is still resolving
        $extraRetries = 4
        while ($watcher.Position.Location.IsUnknown -and $extraRetries -gt 0) {
            Start-Sleep -Milliseconds 500
            $extraRetries--
        }

        $loc = $watcher.Position.Location
        $watcher.Stop()

        if (-not $loc.IsUnknown) {
            return "$($loc.Latitude),$($loc.Longitude)"
        }
    } catch {
        return $null
    }
    return $null
}

# 1. Location Resolution Logic
if ($Location -eq "") {
    
    # Attempt Windows API first
    $winLoc = Get-WindowsLocation
    
    if ($winLoc) {
        $Location = $winLoc
        Write-Host "  [Windows API] Exact Coordinates: $Location   " -ForegroundColor Cyan
    } else {
        # Fallback to Saved Default
        if (Test-Path $configFile) {
            $Location = (Get-Content $configFile -Raw).Trim()
            Write-Host "  [Target] $Location (from Saved Default)   " -ForegroundColor Yellow
            Write-Host "  Note: Enable 'Location Services' in Windows Settings for higher accuracy." -ForegroundColor DarkGray
        } else {
            Write-Host "  [Setup] Windows Location Service is disabled or inaccessible." -ForegroundColor Cyan
            $customLoc = Read-Host "          Type your default City (e.g., 'Yogyakarta') or press [Enter] to use ISP location"
            
            if ($customLoc.Trim() -ne "") {
                $Location = $customLoc.Trim()
                Set-Content -Path $configFile -Value $Location -Encoding UTF8
            } else {
                # Fallback to ISP IP
                try {
                     $ipInfo = Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=status,city,lat,lon'
                     if ($ipInfo.status -eq 'success') {
                         $Location = "$($ipInfo.lat),$($ipInfo.lon)"
                         Write-Host "  [ISP Fallback] $($ipInfo.city) (Lat: $($ipInfo.lat), Lon: $($ipInfo.lon))" -ForegroundColor Magenta
                     }
                } catch {}
            }
        }
    }
} else {
    Write-Host "  [Target] $Location                                             " -ForegroundColor Yellow
}

# 2. Fetch Weather Data via Open-Meteo
try {
    $lat = $null
    $lon = $null

    if ($Location -match "^(-?\d+(\.\d+)?)\s*,\s*(-?\d+(\.\d+)?)$") {
        $lat = $matches[1]
        $lon = $matches[3]
    } else {
        $encodedLocation = [uri]::EscapeDataString($Location)
        $geoUrl = "https://geocoding-api.open-meteo.com/v1/search?name=$encodedLocation&count=1&language=en&format=json"
        $geoInfo = Invoke-RestMethod -Uri $geoUrl
        
        if ($geoInfo.results -and $geoInfo.results.Count -gt 0) {
            $lat = $geoInfo.results[0].latitude
            $lon = $geoInfo.results[0].longitude
        } else {
            Write-Host "  [Error] Could not resolve coordinates for location: $Location" -ForegroundColor Red
            exit
        }
    }

    $weatherUrl = "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,wind_speed_10m,precipitation,uv_index,visibility,surface_pressure,cloud_cover&hourly=temperature_2m,weather_code&daily=sunrise,sunset&timezone=auto&forecast_days=1"
    $weather = Invoke-RestMethod -Uri $weatherUrl

    # 2.5 Reverse Geocode for Precise Address
    $Address = $Location
    $GMapUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon"
    try {
        if ($Location -match "^-?\d+") {
            # Attempt Nominatim (Free)
            $revUrl = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1"
            $revInfo = Invoke-RestMethod -Uri $revUrl -UserAgent "WeatherScriptPS/1.2"
            if ($revInfo.display_name) {
                # Format address: Street/Building, Area, City
                $addr = $revInfo.address
                $components = @()
                if ($addr.building) { $components += $addr.building }
                elseif ($addr.road) { $components += $addr.road }
                
                if ($addr.suburb) { $components += $addr.suburb }
                elseif ($addr.village) { $components += $addr.village }
                
                if ($addr.city) { $components += $addr.city }
                elseif ($addr.town) { $components += $addr.town }
                
                if ($components.Count -gt 0) {
                    $Address = $components -join ", "
                } else {
                    $Address = $revInfo.display_name
                }
            }
        }
    } catch {}
    
    if ($weather.current) {
        $deg = [char]176
        
        # Function to get emoji/logo from code without literal emojis in script
        function Get-WeatherEmoji ($code) {
            switch ($code) {
                0 { return [char]::ConvertFromUtf32(0x2600) } # Sun
                { $_ -in 1,2,3 } { return [char]::ConvertFromUtf32(0x26C5) } # Clouds
                { $_ -in 45,48 } { return [char]::ConvertFromUtf32(0x1F32B) } # Fog
                { $_ -in 51,53,55,61,63,65,80,81,82 } { return [char]::ConvertFromUtf32(0x1F327) } # Rain
                { $_ -in 71,73,75,77,85,86 } { return [char]::ConvertFromUtf32(0x1F328) } # Snow
                { $_ -in 95,96,99 } { return [char]::ConvertFromUtf32(0x26C8) } # Thunder
                Default { return "?" }
            }
        }

        # Function to get human-readable description from code
        function Get-WeatherDescription ($code) {
            switch ($code) {
                0 { return "Clear Sky" }
                { $_ -in 1,2,3 } { return "Cloudy" }
                { $_ -in 45,48 } { return "Foggy" }
                { $_ -in 51,53,55 } { return "Drizzle" }
                { $_ -in 61,63,65 } { return "Rainy" }
                { $_ -in 71,73,75 } { return "Snowy" }
                { $_ -in 80,81,82 } { return "Showers" }
                { $_ -in 95,96,99 } { return "Thunderstorm" }
                Default { return "Conditions Unknown" }
            }
        }

        # --- SECTION: DETAILED CURRENT WEATHER ---
        $c = $weather.current
        $d = $weather.daily
        $cEmoji = Get-WeatherEmoji $c.weather_code
        $cDesc = Get-WeatherDescription $c.weather_code
        
        $sunrise = if ($d.sunrise) { ([datetime]$d.sunrise[0]).ToString("HH:mm") } else { "--:--" }
        $sunset = if ($d.sunset) { ([datetime]$d.sunset[0]).ToString("HH:mm") } else { "--:--" }
        
        Write-Host "`n  [ WEATHER NOW ]" -ForegroundColor Cyan
        Write-Host "  Location    : $Address" -ForegroundColor Yellow
        Write-Host "  Coordinates : $lat, $lon" -ForegroundColor DarkGray
        Write-Host "  Elevation   : $($weather.elevation) MDPL" -ForegroundColor DarkGray
        Write-Host "  Google Maps : $GMapUrl" -ForegroundColor DarkGray
        Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  Condition   : $cEmoji $cDesc" -ForegroundColor White
        Write-Host "  Temperature : $($c.temperature_2m)$deg C (Feels like $($c.apparent_temperature)$deg C)" -ForegroundColor Green
        Write-Host "  Sun Cycle   : $($sunrise) [Sunrise] / $($sunset) [Sunset]" -ForegroundColor Yellow
        Write-Host "  UV Index    : $($c.uv_index) (Max risk)" -ForegroundColor White
        Write-Host "  Humidity    : $($c.relative_humidity_2m)%" -ForegroundColor White
        Write-Host "  Wind Speed  : $($c.wind_speed_10m) km/h" -ForegroundColor White
        Write-Host "  Visibility  : $($c.visibility / 1000) km" -ForegroundColor White
        Write-Host "  Pressure    : $($c.surface_pressure) hPa" -ForegroundColor White
        Write-Host "  Precip      : $($c.precipitation) mm" -ForegroundColor White
        Write-Host "  Cloud Cover : $($c.cloud_cover)%" -ForegroundColor White
        Write-Host "  -------------------------------------------------`n" -ForegroundColor DarkGray

        # --- SECTION: HOURLY FORECAST (Horizontal Table) ---
        if ($weather.hourly) {
            $nowH = (Get-Date).Hour
            # Show 4 hours back and 4 hours forward
            $start = [Math]::Max(0, $nowH - 4)
            $end = [Math]::Min($weather.hourly.time.Count - 1, $nowH + 4)
            
            # Row 1: Time
            Write-Host "  " -NoNewline
            for ($i = $start; $i -le $end; $i++) {
                $hTime = [datetime]$weather.hourly.time[$i]
                $tStr = $hTime.ToString("HH:mm")
                $fg = "White"
                if ($hTime.Hour -lt $nowH) { $fg = "DarkGray" }
                elseif ($hTime.Hour -eq $nowH) { $fg = "Green" }
                
                $cell = " $tStr  "
                if ($hTime.Hour -eq $nowH) { $cell = "[$tStr] " }
                Write-Host $cell -NoNewline -ForegroundColor $fg
            }
            Write-Host ""

            # Row 2: Logo/Emoji
            Write-Host "  " -NoNewline
            for ($i = $start; $i -le $end; $i++) {
                $hTime = [datetime]$weather.hourly.time[$i]
                $hCode = [int]$weather.hourly.weather_code[$i]
                $hEmoji = Get-WeatherEmoji $hCode
                $fg = "White"
                if ($hTime.Hour -lt $nowH) { $fg = "DarkGray" }
                elseif ($hTime.Hour -eq $nowH) { $fg = "Green" }

                $cell = "   $hEmoji   "
                if ($hTime.Hour -eq $nowH) { $cell = " [ $hEmoji ] " }
                Write-Host $cell -NoNewline -ForegroundColor $fg
            }
            Write-Host ""

            # Row 3: Temperature
            Write-Host "  " -NoNewline
            for ($i = $start; $i -le $end; $i++) {
                $hTime = [datetime]$weather.hourly.time[$i]
                $hT = [Math]::Round($weather.hourly.temperature_2m[$i])
                $fg = "White"
                if ($hTime.Hour -lt $nowH) { $fg = "DarkGray" }
                elseif ($hTime.Hour -eq $nowH) { $fg = "Green" }

                $tOut = "{0,3}" -f $hT
                $tOut = $tOut + $deg + "C"
                $cell = " $tOut  "
                if ($hTime.Hour -eq $nowH) { $cell = "[$tOut] " }
                Write-Host $cell -NoNewline -ForegroundColor $fg
            }
            Write-Host "`n"
        }
    } else {
        Write-Host "  [Error] Unrecognized weather response format." -ForegroundColor Red
    }
} catch {
    Write-Host "  [Error] Could not fetch weather data. Details: $_" -ForegroundColor Red
}

