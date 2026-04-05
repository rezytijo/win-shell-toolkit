# CustomScripts - Context

## Overview
Collection of PowerShell and Batch utility scripts for system administration tasks.
Scripts are registered as PowerShell profile functions via `setup.ps1` for quick access.

## Architecture
- **Entry Point**: `setup.ps1` -- manages dependency installation + profile alias registration
- **Invocation Pattern**: `.bat` wrappers call `.ps1` scripts via `powershell -NoProfile -ExecutionPolicy Bypass`
- **Profile Integration**: Scripts registered as functions in `$PROFILE` using invoke operator (`&`) with `@args` forwarding

## Scripts

| Script | Purpose | Dependencies |
|---|---|---|
| `setup.ps1` | Installs deps + registers all scripts as PowerShell profile commands | None |
| `update.ps1` | System update (winget default, Windows Update optional, NPM/Python support) | `winget`, `PSWindowsUpdate` module, `npm`, `python` |
| `update.bat` | Batch wrapper for `update.ps1` | PowerShell 5.1+ |
| `ExportToPdf.ps1` | Converts documents to PDF via Office COM (silent) or PrintTo fallback | MS Office (Optional, for silent export) |
| `export-to-pdf.bat` | Batch wrapper for `ExportToPdf.ps1` | PowerShell 5.1+ |
| `check-host.ps1` | IP/Domain intelligence lookup via ip-api.com JSON API | PowerShell (Invoke-RestMethod) |
| `myip.ps1` | Shows public IP + private network info (interface, SSID, signal, tunnel detection) | PowerShell (Invoke-RestMethod, Get-NetAdapter) |
| `clean-system.ps1` | Cleans Temp folders, empty Recycle Bin, clears Win Update cache | Admin privileges |
| `reset-net.ps1` | Flushes DNS, releases/renews IP, clears ARP. Support `-Hard` reset | Admin privileges |
| `mkproj.ps1` | Multi-language project initializer (Node, Python, Go, Rust, React, Web) | Git, (npm/python/go/cargo) |
| `kill-port.ps1` | Finds and terminates process occupying a specific TCP port | PowerShell (Get-Process, netstat) |
| `sysinfo.ps1` | Displays quick hardware, OS, and resource usage overview | PowerShell WMI/CIM |
| `find-large.ps1` | Storage analyzer to locate largest files in a directory | PowerShell (Get-ChildItem) |
| `gen-pass.ps1` | Generates secure random passwords and copies to clipboard | PowerShell (`Set-Clipboard`) |
| `checksum.ps1` | Calculates MD5, SHA1, SHA256, SHA512 hashes for any given file | PowerShell (`Get-FileHash`) |
| `wifi-pass.ps1` | Extracts all saved Wi-Fi Profiles and displays their clear-text passwords | `netsh wlan show profile` |
| `restart-explorer.ps1` | Force-kills and restarts Taskbar/Desktop safely | PowerShell (`Stop-Process`) |
| `list-ports.ps1` | Port scanner mapping listening TCP/UDP endpoints to absolute process names | `Get-NetTCPConnection` |
| `b64.ps1` | Safely encode or decode strings to Base64 in terminal (copies result) | `[Convert]::ToBase64String` |
| `copy-path.ps1` | Instantly grabs absolute path of any typed file/folder into clipboard | `Resolve-Path`, `Set-Clipboard` |
| `pwdc.ps1` | Prints current working directory and copies it to clipboard | `Set-Clipboard` |
| `clean-empty.ps1` | Bottom-up empty directory scanner and sweeper | `Get-ChildItem -Directory` |
| `touch.ps1` | Creates empty files or updates existing file timestamps | `New-Item`, `LastWriteTime` |
| `mkcd.ps1` | Creates a new directory and instantly CDs into it | `New-Item`, `Set-Location` |
| `hosts.ps1` | Quickly opens the Windows `hosts` file securely as Administrator | `Start-Process -Verb RunAs` |
| `weather.ps1` | Terminal weather using Windows Location Services (or IP/Manual fallback) | `System.Device.Location`, `wttr.in` |
| `sudo.ps1` | Like Linux `sudo`, quickly runs commands as Admin inside UAC window | `Start-Process powershell -Verb RunAs`|
| `qr.ps1` | Offline generator creating and opening a high-res QR code PNG | `QRCodeGenerator` Module |
| `reboot-bios.ps1` | Restarts the computer directly into UEFI/BIOS settings | Admin privileges, `shutdown /fw` |
| `top-proc.ps1` | A terminal task manager sorting the Top 15 RAM/CPU apps | `Get-Process`, `Sort-Object` |
| `wifi-pass.ps1` | Interactive TUI to select and extract saved Wi-Fi passwords | `netsh wlan`, `[console]::ReadKey()` |
| `wifi-qr.ps1` | Interactive TUI generating an offline Wi-Fi QR code graphic | `netsh`, `QRCodeGenerator` Module |
| `zip-code.ps1` | Codebase packager (respects .gitignore, adds root folder) | `Compress-Archive`, .gitignore parsing |
| `clean-wifi.ps1` | Multi-select TUI to batch delete useless/old Wi-Fi profiles | `netsh wlan delete profile` |
| `sys-lock.ps1` | Instantly lock the Windows session from the terminal | `rundll32.exe user32.dll` |
| `sys-sleep.ps1` | Immediately enters ACPI Sleep mode (Standby) | `rundll32.exe powrprof.dll` |
| `kill-app.ps1` | Force-kills apps by name (akin to Linux `killall`) | `Get-Process`, `Stop-Process` |
| `systemctl.ps1` | Manages background Windows Services (start/stop/status) | `Get-Service`, `Start-Service` |
| `watch.ps1` | Linux `watch`, repeatedly runs a command every N secs | `Invoke-Expression` |
| `zip.ps1` | Lightning fast directory to `.zip` file compressor | `Compress-Archive` |
| `unzip.ps1` | Extracts `.zip` files seamlessly in the terminal | `Expand-Archive` |
| `df.ps1` | Linux `df -h`, neatly prints Hard Drive disk space & usage | `Win32_LogicalDisk` |
| `free.ps1` | Linux `free -m`, prints RAM & Swap usage | `Win32_OperatingSystem` |
| `uptime.ps1` | Linux `uptime`, outputs the active system alive time | `Win32_OperatingSystem` |
| `nc.ps1` | Rapid Netcat (`nc`), checks if a TCP port on an IP is open | `System.Net.Sockets.TcpClient` |
| `time.ps1` | Linux `time`, measures exact elapsed execution length | `Stopwatch` |
| `ll.ps1` | Linux `ls -la`, cleanly displays directory items with sizes | `Get-ChildItem` |
| `trash.ps1` | Native safe `rm`, moves items to Recycle Bin directly | `Microsoft.VisualBasic.FileIO` |
| `whereis.ps1` | Linux `which`, outputs execution path of any command/alias | `Get-Command` |
| `grep.ps1` | Linux `grep`, highlights exact matching pattern in string pipes | Regex replace |
| `tail.ps1` | Linux `tail`, monitors end of a file cleanly (`-f` auto-updates) | `Get-Content -Tail -Wait` |
| `nano.ps1` | Linux `nano`, securely edits protected files as Administrator | `Start-Process -Verb RunAs` |
| `cmds.ps1` | Interactive cheat-sheet, actively reads this Context.md file | `Get-Content` regex parsing |

## The "Linux in Windows" Dictionary
*A comparison guide showing how our terminal Arsenal perfectly mimics daily Linux operations.*

| Linux Native Command | Our Windows PowerShell Magic | Built-In PS Equivalent (Slow/Clunky) |
| --- | --- | --- |
| `sudo` | `sudo` | None natively |
| `killall [name]` | `kill-app [name]` | `Stop-Process -Name` |
| `systemctl` | `systemctl` | `Get-Service` / `Start-Service` |
| `watch -n 1` | `watch -n 1` | None natively |
| `top` / `htop` | `top-proc CPU` | `Get-Process` |
| `df -h` | `df` | `Get-Volume` |
| `free -m` | `free` | `Get-CimInstance` (Complex query) |
| `uptime` | `uptime` | `Get-CimInstance` (Math query) |
| `time [cmd]` | `time [cmd]` | `Measure-Command` |
| `nc -vz [ip] [port]` | `nc [ip] [port]` | `Test-NetConnection` |
| `netstat -tulpn` | `list-ports` | `Get-NetTCPConnection` |
| `fuser -k [port]` | `kill-port [port]` | None natively |
| `ifconfig` / `curl ifconfig.me` | `myip` | `Get-NetIPAddress` |
| `md5sum` / `sha256sum` | `checksum` | `Get-FileHash` |
| `python3 -m http.server` | `serve` | None natively |
| `nano` / `vim` | `nano` | Open Notepad as Admin |
| `mkdir -p X && cd X` | `mkcd X` | None natively |
| `zip` (codebase) | `zip-code` | `Compress-Archive` |
| `zip` / `unzip` | `zip` / `unzip` | `Compress-Archive` |
| `touch` | `touch` | `New-Item` |
| `ls -la` / `ll` | `ll` | `Get-ChildItem` |
| `project init` | `mkproj` | None natively |
| `pwd` (and copy) | `pwdc` | `(Get-Location).Path` |
| `rm` / safe delete | `trash` | `Remove-Item` (Permadeletes) |
| `which` / `whereis`| `whereis` | `Get-Command` |
| `grep` | `grep` | `Select-String` |
| `tail -f` | `tail -f` | `Get-Content -Tail -Wait` |
| `neofetch` | `sysinfo` | None natively |
| `reboot to bios` | `reboot-bios` | `shutdown /r /fw` |

## Dependencies (managed by `setup.ps1 -Deps`)
- **PSWindowsUpdate** (PS Module) -- for `update.ps1` Windows Update integration
- **QRCodeGenerator** (PS Module) -- natively creates offline QR codes in `qr.ps1` and `wifi-qr.ps1`
- **Ookla.Speedtest.CLI** (winget/manual fallback) -- managed by `setup.ps1`
- **Microsoft Print to PDF** (Windows Feature) -- for `ExportToPdf.ps1`

## Pinned Packages (excluded from winget upgrade)
- `Parsec.Parsec`
- `Spotify.Spotify`
- `Tonec.InternetDownloadManager`

## Changelog
- **05 April 2026 10:15** -- Mass Standardization of Error Handling: Applied `$ErrorActionPreference = 'Stop'` and global `try/catch` wrappers across all 49+ scripts in the arsenal (Batches 1-4). This ensures that failures are caught gracefully, providing color-coded feedback and proper exit codes (`exit 1`) for pipeline stability. Every script now follows a unified, robust execution pattern.
- **05 April 2026 09:02** -- `ExportToPdf.ps1` v2.0.1: Added graceful error handling for missing Office COM automation (MS Office not installed). The script now automatically detects if Word/Excel/PPT is missing and switches to the 'PrintTo' fallback instead of failing, accompanied by clear user warnings.
- **2026-04-05 08:52** -- `ExportToPdf.ps1` v2.0.0: Complete overhaul. Switched to Microsoft Office COM Automation for silent, reliable exports. Added support for wildcards (e.g. `*.docx`), pipeline input, and a `PrintTo` fallback for non-Office files. Total overhaul of the UI with colored status and progress tracking.
- **2026-04-05 08:35** -- `update.ps1` v2.0.4: Integrated Dev environment updates. Added support for NPM (self-update + global packages) and Python (pip upgrade). New targets: `npm`, `python`, and `dev` (both). `update all` now includes development runtimes.
- **2026-04-05 08:30** -- `update.ps1` v2.0.3: Made Windows Updates optional. By default, only Winget applications are updated. Use `update windows` to trigger OS updates or `update all` for both. This prevents unexpected reboots during standard maintenance.
- **2026-03-11 08:15** -- Added `cmds.ps1` to act as an active dictionary. It parses the `Context.md` file dynamically and projects the definitions neatly directly in the terminal so users don't need to manually read documents to remember their tools. Total Alias Commands: 49.
- **2026-03-11 08:10** -- Added `nano.ps1` as a pseudo-Linux editor wrapper. It immediately calculates absolute paths and opens the targeted file inside a UAC-elevated Notepad instance, making root/admin edits in `Program Files` or `System32` entirely seamless directly from a standard user terminal. Total Alias Commands: 48.
- **2026-03-11 08:05** -- Ultimate UI/UX Core utilities: `ll`, `trash`, `whereis`, `grep`, and `tail` have been created to replace verbose Windows typing standards and bring true Linux productivity directly to standard PS arrays. The alias count sits perfectly at 47 robust commands.
- **2026-03-11 07:55** -- Final Linux Conversion Phase: Added `df`, `free`, `uptime`, `time`, and `nc`, bringing the most iconic Linux systemic introspection commands into PowerShell. Also drafted the 'Linux in Windows' Context guide. Total scripts: 41.
- **2026-03-11 07:45** -- Added 5 Linux-Hybrid powers tools: `watch` (looping executions), `zip` & `unzip` (CLI fast archives), `kill-app` (`killall` equivalent for mass force-stopping processes), and `systemctl` (Ubuntu native syntax wrapper for managing Windows Services). Total managed scripts: 36 commands.
- **2026-03-11 07:33** -- `qr.ps1` and `wifi-qr.ps1` v2.1.0: Converted both QR code scipts to use the `QRCodeGenerator` PowerShell module strictly offline. They now build high-res PNGs and instantly open them in the native Windows photo viewer rather than relying on internet APIs (`qrenco.de`), which eliminates latency and avoids terminal ANSI decoding failures.
- **2026-03-11 07:25** -- `clean-wifi.ps1` v1.0.0: Added a multi-select interactive TUI menu to clean up unused Wi-Fi network profiles. It automatically scans all xml-exported metadata and pre-checks `[X]` all open/passwordless Wi-Fi networks by default for immediate deletion, allowing the user to toggle other targets via the spacebar.
- **2026-03-11 07:15** -- `wifi-pass.ps1` and `wifi-qr.ps1` v2.0.0: Both scripts overhauled to utilize a native PowerShell TUI rendering engine. They now present an interactive list of all saved Wi-Fi profiles instead of relying only on the active one, allowing users to scroll and select using UP/DOWN arrow keys.
- **2026-03-11 07:12** -- Added `top-proc`, `wifi-qr`, `serve`, `sys-lock`, and `sys-sleep`. Total alias commands now managed by profile: 31. This completes the native PowerShell transition.
- **2026-03-11 07:01** -- `weather.ps1` v1.2.0: Integrated Windows Geolocation API (`System.Device.Location.GeoCoordinateWatcher`) instead of IP Auto-Detect for pinpoint accuracy. Will fallback to saved default (`~/.weather_location`) or ISP IP if Windows Location service is disabled.
- **2026-03-11 06:55** -- Terminal Overhaul v1.0.0: Added `touch`, `mkcd`, `hosts`, `weather`, `sudo`, and `qr`. `setup.ps1` profile builder was updated to dot-source (`.`) `mkcd` to accurately change the parent shell's location. Total scripts managed: 26 aliases.
- **2026-03-11 06:50** -- Power-User Tools v1.0.0: Added `wifi-pass`, `restart-explorer`, `list-ports`, `b64`, `copy-path`, and `clean-empty`. Total scripts managed: 20 command aliases.
- **2026-03-11 06:48** -- `checksum.ps1` v1.0.0: Added file hash calculator. Calculates MD5, SHA1, SHA256, and SHA512 simultaneously using Get-FileHash. Shows file metadata and elapsed processing time.
- **2026-03-11 06:42** -- Utilities Collection v1.0.0: Added 6 new daily use admin scripts: `clean-system`, `reset-net`, `kill-port`, `sysinfo`, `find-large`, and `gen-pass`.
- **2026-03-11 06:31** -- `myip.ps1` v2.0.0: Converted from .bat to .ps1. Added private network info (interface, MAC, link speed, private IP, gateway, DNS). Tunnel/VPN detection with underlying physical adapter resolution. WiFi details: SSID, signal, auth, band, channel, radio type.
- **2026-03-11 06:25** -- `check-host.bat` v2.0.0: Switched from check-host.net (was returning HTML, not JSON) to ip-api.com real JSON API. Added fields: Reverse DNS, Mobile, Proxy/VPN, Hosting/DC.
- **2026-03-11 06:25** -- `setup.ps1` v2.1.0: Fixed profile functions not forwarding arguments (`@args`). This caused `.bat` scripts like `check-host` to fail when called from profile.
- **2026-03-11 06:18** -- `setup.ps1` v2.0.0: Added `Install-Dependencies` function with 3-tier dependency management (PS modules, winget tools, Windows features). Added `-Deps` flag. Fixed `export-to-pdf.bat` hardcoded path (was pointing to user `primall`).
- **2026-03-10 01:28** -- `update.ps1` v2.0.2: Refactored from manual parsing to `winget pin` exclusion mechanism. Added `--disable-interactivity`, `--force` pin, graceful not-installed handling. Fixed UTF-8 BOM encoding for PS 5.1 compatibility.
- **2026-03-10 01:28** -- `setup.ps1`: Changed profile function generation from dot-source (`.`) to invoke operator (`&`) for correct `$MyInvocation` guard behavior.
