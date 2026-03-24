# 🚀 CustomScripts Arsenal
> A collection of high-performance PowerShell and Batch scripts to bring the power of Linux and advanced system management directly to your Windows terminal.

## ✨ Highlights
- **Universal Accessibility**: Works seamlessly in both **PowerShell** and **Command Prompt (CMD)**.
- **Linux Logic**: Familiar commands like `ll`, `grep`, `tail`, `df`, `free`, and `sudo` for Windows.
- **AI-Ready**: Specialized templates for Cursor, Windsurf, Claude, and Gemini Antigravity.
- **System Hardening**: Quick tools for net-reset, BIOS-reboot, system cleaning, and hardware info.
- **Auto-Setup**: One command to install all dependencies and register aliases.

## 📦 Quick Installation
1. Download or clone this repository to your computer.
2. Open PowerShell as Administrator.
3. Run the setup script:
   ```powershell
   .\setup.ps1 -Install
   ```
4. Restart your terminal (PowerShell/CMD).

## 🛠️ Complete Command Reference
| Command | Description |
| :--- | :--- |
| `setup` | Installs deps + registers all scripts as PowerShell profile commands |
| `update` | System update (winget + Windows Update) with pin-based exclusions |
| `ExportToPdf` | Converts Office docs to PDF via "Microsoft Print to PDF" |
| `check-host` | IP/Domain intelligence lookup via ip-api.com JSON API |
| `myip` | Shows public IP + private network info (interface, SSID, signal, etc.) |
| `clean-system` | Cleans Temp folders, Recycle Bin, and Windows Update cache |
| `reset-net` | Flushes DNS, releases/renews IP, and clears ARP |
| `mkproj` | Multi-language project initializer (Node, Python, Go, AI Agent, etc.) |
| `kill-port` | Finds and terminates process occupying a specific TCP port |
| `sysinfo` | Displays quick hardware, OS, and resource usage overview |
| `find-large` | Storage analyzer to locate largest files in a directory |
| `gen-pass` | Generates secure random passwords and copies to clipboard |
| `checksum` | Calculates MD5, SHA1, SHA256, SHA512 hashes for any file |
| `wifi-pass` | Interactive TUI to select and extract saved Wi-Fi passwords |
| `restart-explorer` | Force-kills and restarts Taskbar/Desktop safely |
| `list-ports` | Port scanner mapping listening TCP/UDP endpoints to processes |
| `b64` | Safely encode or decode strings to Base64 (copies result) |
| `copy-path` | Instantly grabs absolute path of any file/folder into clipboard |
| `pwdc` | Prints current working directory and copies it to clipboard |
| `clean-empty` | Bottom-up empty directory scanner and sweeper |
| `touch` | Creates empty files or updates existing file timestamps |
| `mkcd` | Creates a new directory and instantly CDs into it |
| `hosts` | Quickly opens the Windows hosts file securely as Administrator |
| `weather` | Terminal weather using Windows Location Services |
| `sudo` | Like Linux `sudo`, quickly runs commands as Admin |
| `qr` | Offline generator creating and opening a high-res QR code PNG |
| `reboot-bios` | Restarts the computer directly into UEFI/BIOS settings |
| `top-proc` | A terminal task manager sorting the Top 15 RAM/CPU apps |
| `wifi-qr` | Interactive TUI generating an offline Wi-Fi QR code graphic |
| `zip-code` | Codebase packager (respects .gitignore, adds root folder) |
| `clean-wifi` | Multi-select TUI to batch delete useless/old Wi-Fi profiles |
| `sys-lock` | Instantly lock the Windows session from the terminal |
| `sys-sleep` | Immediately enters ACPI Sleep mode (Standby) |
| `kill-app` | Force-kills apps by name (akin to Linux `killall`) |
| `systemctl` | Manages background Windows Services (start/stop/status) |
| `watch` | Linux `watch`, repeatedly runs a command every N secs |
| `zip/unzip` | Lightning fast directory compression and extraction |
| `df` | Linux `df -h`, neatly prints Hard Drive disk space & usage |
| `free` | Linux `free -m`, prints RAM & Swap usage |
| `uptime` | Linux `uptime`, outputs the active system alive time |
| `nc` | Rapid Netcat (`nc`), checks if a TCP port on an IP is open |
| `time` | Linux `time`, measures exact elapsed execution length |
| `ll` | Linux `ls -la`, cleanly displays directory items with sizes |
| `trash` | Native safe `rm`, moves items to Recycle Bin directly |
| `whereis` | Linux `which`, outputs execution path of any command/alias |
| `grep` | Linux `grep`, highlights exact matching pattern in string pipes |
| `tail` | Linux `tail`, monitors end of a file cleanly (`-f` support) |
| `nano` | Linux `nano`, securely edits protected files as Administrator |
| `cmds` | Interactive cheat-sheet, entries mapped from Context.md |

## ⚙️ Architecture
- **`.ps1`**: Core PowerShell logic for complex tasks.
- **`.bat`**: Automatic shims created by `setup.ps1` to allow CMD access and PATH integration.
- **`Context.md`**: The brain of the project, used by `cmds` to display interactive help.

## 🛡️ Requirements
- Windows 10/11
- PowerShell 5.1 (Built-in) or PowerShell 7+ (Recommended)
- Internet connection (for initial `-Deps` installation)

---
*Created with ❤️ for power users and developers.*
