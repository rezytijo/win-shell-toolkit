# CustomScripts Arsenal

PowerShell and Batch utilities that make Windows terminals feel faster, cleaner, and much closer to a Linux-style CLI workflow.

This repository packages daily-use commands for system maintenance, networking, file operations, project bootstrapping, and terminal convenience. Every tool is designed to work from PowerShell, and most are also exposed to Command Prompt through generated `.bat` shims.

## Highlights

- Linux-like commands for Windows such as `ll`, `grep`, `tail`, `df`, `free`, `watch`, `nc`, and `sudo`
- One-step setup via `setup.ps1` to register aliases, create CMD shims, and prepare dependencies
- Built-in maintenance tools for networking, cleanup, hardware info, and service/process management
- Productivity helpers for QR generation, password generation, clipboard workflows, and quick file operations
- Project and developer utilities such as `mkproj`, `serve`, `zip-code`, and `cmds`
- Automatic detection of required dependencies, including Windows features and `Sudo for Windows` when available

## Why This Project Exists

Windows already has strong scripting capabilities, but a lot of everyday terminal work still feels verbose compared to Linux. This project closes that gap by wrapping common admin and developer tasks into short, memorable commands with sensible output.

The goal is simple: fewer repetitive keystrokes, less hunting through GUI settings, and a terminal that feels practical for real daily work.

## Installation

1. Clone or download this repository.
2. Open PowerShell as Administrator.
3. Run:

```powershell
.\setup.ps1 -Install
```

4. Restart PowerShell or run:

```powershell
. $PROFILE
```

### What `setup.ps1 -Install` does

- Installs required PowerShell modules
- Checks system dependencies
- Creates `.bat` shims for CMD compatibility
- Registers all scripts as PowerShell functions in your profile
- Enables supported Windows features when possible
- Enables `Sudo for Windows` in `forceNewWindow` mode when `sudo.exe` is available and setup is run as Administrator

## Setup Commands

```powershell
.\setup.ps1 -Install
.\setup.ps1 -Deps
.\setup.ps1 -Update
.\setup.ps1 -List
.\setup.ps1 -Uninstall
```

### Command meanings

- `-Install`: full install, dependency check, CMD shims, and PowerShell profile integration
- `-Deps`: dependency check only
- `-Update`: update required PowerShell modules
- `-List`: show detected scripts
- `-Uninstall`: remove profile integration and uninstall managed modules

## Command Categories

### System and Admin

| Command | Description |
| :--- | :--- |
| `update` | System update with `winget` and Windows Update integration |
| `clean-system` | Cleans temp folders, Recycle Bin, and Windows Update cache |
| `sysinfo` | Quick hardware, OS, and resource summary |
| `top-proc` | Top CPU and RAM consumers in the terminal |
| `systemctl` | Start, stop, and inspect Windows services |
| `restart-explorer` | Restarts the Windows shell safely |
| `reboot-bios` | Reboot directly into UEFI or BIOS settings |
| `sys-lock` | Lock the current Windows session |
| `sys-sleep` | Put the system into sleep mode |
| `sudo` | Run commands with Administrator privileges |
| `nano` | Open protected files as Administrator in Notepad |
| `hosts` | Open the Windows hosts file with elevation |

### Network and Connectivity

| Command | Description |
| :--- | :--- |
| `check-host` | IP and domain intelligence lookup |
| `myip` | Public and private network information |
| `reset-net` | Flush DNS, renew IP, and clear ARP cache |
| `list-ports` | List listening TCP and UDP ports with process mapping |
| `kill-port` | Kill the process occupying a TCP port |
| `kill-app` | Kill processes by application name |
| `nc` | Check whether a TCP port is reachable |
| `weather` | Terminal weather lookup using Windows location when available |
| `wifi-pass` | View saved Wi-Fi passwords |
| `wifi-qr` | Generate offline Wi-Fi QR codes |
| `clean-wifi` | Remove old or unused Wi-Fi profiles |

### Files and Storage

| Command | Description |
| :--- | :--- |
| `ll` | Detailed directory listing |
| `df` | Disk usage summary |
| `free` | RAM and swap usage summary |
| `find-large` | Find large files in a directory tree |
| `clean-empty` | Remove empty directories |
| `touch` | Create files or update timestamps |
| `copy-path` | Copy absolute file or folder paths |
| `pwdc` | Print and copy the current directory |
| `checksum` | Generate MD5, SHA1, SHA256, and SHA512 hashes |
| `zip` | Compress folders into `.zip` archives |
| `unzip` | Extract `.zip` archives |
| `trash` | Send files to Recycle Bin instead of permanently deleting |
| `ExportToPdf` | Convert Office documents using Microsoft Print to PDF |

### Terminal and Productivity

| Command | Description |
| :--- | :--- |
| `grep` | Search and highlight matching text |
| `tail` | Read the end of a file, including follow mode |
| `watch` | Re-run a command on an interval |
| `time` | Measure command execution time |
| `uptime` | Show system uptime |
| `whereis` | Show where a command resolves from |
| `b64` | Encode or decode Base64 |
| `gen-pass` | Generate strong passwords and copy them |
| `qr` | Generate offline QR code PNG files |
| `cmds` | Interactive cheat sheet built from `Context.md` |

### Developer Utilities

| Command | Description |
| :--- | :--- |
| `mkcd` | Create a directory and move into it |
| `mkproj` | Bootstrap new projects for multiple stacks |
| `serve` | Start a quick local static server |
| `zip-code` | Package a codebase while respecting `.gitignore` |

## How It Works

- `.ps1` files contain the main logic
- `.bat` files act as CMD launchers for the same tools
- `setup.ps1` manages dependency checks, profile registration, and shim generation
- `Context.md` acts as the internal command reference used by `cmds`

## Linux-to-Windows Mental Model

| Linux Command | CustomScripts Command |
| :--- | :--- |
| `ls -la` | `ll` |
| `grep` | `grep` |
| `tail -f` | `tail -f` |
| `df -h` | `df` |
| `free -m` | `free` |
| `uptime` | `uptime` |
| `time` | `time` |
| `watch` | `watch` |
| `nc` | `nc` |
| `sudo` | `sudo` |
| `killall app` | `kill-app app` |
| `fuser -k 3000` | `kill-port 3000` |
| `systemctl` | `systemctl` |
| `mkdir dir && cd dir` | `mkcd dir` |
| `touch file.txt` | `touch file.txt` |
| `which` | `whereis` |
| `rm` with safety | `trash` |

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or PowerShell 7+
- Administrator shell for best setup experience
- Internet access for dependency installation

### Notes

- `Sudo for Windows` support depends on Windows builds that ship with `sudo.exe` such as Windows 11 24H2+
- If `winget` is unavailable, `setup.ps1` skips those checks and continues
- Some commands require Administrator privileges by design

## Project Structure

```text
CustomScripts/
|- *.ps1        # Main PowerShell commands
|- *.bat        # CMD shims or wrappers
|- setup.ps1    # Setup, dependency checks, alias registration
|- Context.md   # Internal command dictionary
|- README.md    # Public project documentation
```

## Typical Workflow

```powershell
.\setup.ps1 -Install
cmds
ll
mkproj my-app
serve
```

## License

Use and adapt freely for your own workflow. Add a license file if you want to publish the repository publicly on GitHub with explicit licensing terms.
