# mkproj.ps1 -- Modern Project Initializer
# 2026-03-16 -- v1.0.0: Initial version

<#
.SYNOPSIS
    Initializes a new project codebase with common language templates.

.DESCRIPTION
    Supports Node.js, Python, Go, Rust, React (Vite), and Vanilla Web.
    Automates directory creation, git initialization, and basic boilerplate.
    This script is part of the CustomScripts arsenal.

.EXAMPLE
    mkproj "MyNewApp"
#>

# Note: This script MUST be dot-sourced (.) to change the parent shell's location

param(
    [Parameter(Position=0, HelpMessage="Name of the project folder")]
    [string]$ProjectName = "",

    [Parameter(HelpMessage="Show help information")]
    [switch]$Help
)

function Show-Header {
    Write-Host "`n  ========================================" -ForegroundColor Cyan
    Write-Host "     ✨ MODERN PROJECT INITIALIZER ✨" -ForegroundColor White
    Write-Host "  ========================================`n" -ForegroundColor Cyan
}

function Show-Help {
    Show-Header
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    mkproj                - Starts interactive mode"
    Write-Host "    mkproj 'Name'         - Initializes project with directory 'Name'"
    Write-Host "    mkproj -Help          - Shows this help menu"
    Write-Host ""
    Write-Host "  Supported Templates:" -ForegroundColor Yellow
    Write-Host "    1. Node.js            - npm init, src/, index.js"
    Write-Host "    2. Python             - venv, lib structure, main.py"
    Write-Host "    3. Go                 - go mod init, main.go"
    Write-Host "    4. Rust               - cargo init or manual src/main.rs"
    Write-Host "    5. React (Vite)       - Vite + TS boilerplate"
    Write-Host "    6. Web Vanilla        - HTML/CSS/JS boilerplate"
    Write-Host "    7. AI Agent           - Universal AI ecosystem (.agent, .cursor, .claude, etc.)"
    Write-Host ""
    Write-Host "  Features:" -ForegroundColor Yellow
    Write-Host "    * Automatic .gitignore & .dockerignore with smart patterns"
    Write-Host "    * Auto-initializes Git repository"
    Write-Host "    * Multi-Agent ready config files"
    Write-Host ""
    exit
}

if ($Help) { Show-Help }

if (-not $ProjectName) {
    Show-Header
    $ProjectName = Read-Host "  [?] Project Name"
}

if (-not $ProjectName) { Write-Host "  [!] Project name is required." -ForegroundColor Red; exit }

$targetPath = Join-Path (Get-Location) $ProjectName

if (Test-Path $targetPath) {
    Write-Host "  [!] Directory '$ProjectName' already exists." -ForegroundColor Red
    exit
}

# --- TEMPLATE SELECTION ---
$templates = @(
    "Node.js (npm)",
    "Python (venv)",
    "Go (mod)",
    "Rust (cargo)",
    "React (Vite + TS)",
    "Web (HTML/CSS/JS)",
    "AI Agent (.agent framework)",
    "Empty (Git only)"
)

Write-Host "  Available Templates:" -ForegroundColor Yellow
for ($i=0; $i -lt $templates.Count; $i++) {
    Write-Host "  [$($i+1)] $($templates[$i])"
}

$choice = Read-Host "`n  [?] Select Template (1-$($templates.Count))"
$template = $templates[[int]$choice - 1]

if (-not $template) { Write-Host "  [!] Invalid selection." -ForegroundColor Red; exit }

# --- INITIALIZATION ---
Write-Host "`n  [1/3] Creating directory structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
Set-Location -Path $targetPath

# Function to create standardized ignore files
function Create-IgnoreFiles ($type) {
    $commonPatterns = @(
        "# System Files",
        ".DS_Store", "Thumbs.db", "desktop.ini",
        "",
        "# IDEs",
        ".vscode/", ".idea/", "*.swp", "*.swo",
        "",
        "# Temporary & Cache",
        "*debug*", "*test*", "*.log", "*.tmp", "*.bak", "*.db", "*.json", "*.csv",
        "",
        "# Environment",
        ".env", ".env.local", ".env.*.local",
        "",
        "# AI Agent System",
        ".agent/brain/", ".agent/logs/", ".agent/temp/", ".codex/sessions/", ".codex/history.jsonl"
    )

    $langPatterns = switch ($type) {
        "Node"   { @("# Dependencies", "node_modules/", "dist/", "build/", "npm-debug.log*") }
        "Python" { @("# Python", "__pycache__/", "*.py[cod]", "venv/", ".venv/", "env/", "build/", "dist/") }
        "Go"     { @("# Go binaries", "bin/", "*.exe", "*.test", "*.prof") }
        "Rust"   { @("# Rust", "target/", "**/*.rs.bk") }
        "AI"     { @("# AI Specific", "brain/", "memory/", "*.index", ".google/") }
        Default  { @() }
    }

    $finalContent = ($commonPatterns + $langPatterns) -join "`n"
    $finalContent | Out-File -FilePath ".gitignore" -Encoding utf8
    $finalContent | Out-File -FilePath ".dockerignore" -Encoding utf8
}

# Base files
$readme = "# $ProjectName`n`nGenerated using CustomScripts `mkproj` on $(Get-Date -Format 'yyyy-MM-dd')."
$readme | Out-File -FilePath "README.md" -Encoding utf8

Write-Host "  [2/3] Setting up $template boilerplate..." -ForegroundColor Cyan

switch ($choice) {
    "1" { # Node.js
        npm init -y | Out-Null
        New-Item -ItemType Directory -Path "src" | Out-Null
        "'use strict';`n`nconsole.log('Hello from $ProjectName!');" | Out-File -FilePath "src/index.js" -Encoding utf8
        Create-IgnoreFiles "Node"
    }
    "2" { # Python
        python -m venv venv
        New-Item -ItemType Directory -Path "src" | Out-Null
        "def main():`n    print('Hello from $ProjectName!')`n`nif __name__ == '__main__':`n    main()" | Out-File -FilePath "src/main.py" -Encoding utf8
        Create-IgnoreFiles "Python"
    }
    "3" { # Go
        go mod init $ProjectName.ToLower() | Out-Null
        "package main`n`nimport `"fmt`"`n`nfunc main() {`n    fmt.Println(`"Hello from $ProjectName!`")`n}" | Out-File -FilePath "main.go" -Encoding utf8
        Create-IgnoreFiles "Go"
    }
    "4" { # Rust
        if (Get-Command cargo -ErrorAction SilentlyContinue) {
            cargo init . | Out-Null
        } else {
            New-Item -ItemType Directory -Path "src" | Out-Null
            "fn main() {`n    println!(`"Hello from $ProjectName!`");`n}" | Out-File -FilePath "src/main.rs" -Encoding utf8
        }
        Create-IgnoreFiles "Rust"
    }
    "5" { # React (Vite)
        npm create vite@latest . -- --template react-ts
        Create-IgnoreFiles "Node"
    }
    "6" { # Web Vanilla
        New-Item -ItemType Directory -Path "css", "js", "assets" | Out-Null
        "<!DOCTYPE html>`n<html>`n<head>`n    <title>$ProjectName</title>`n    <link rel='stylesheet' href='css/style.css'>`n</head>`n<body>`n    <h1>Welcome to $ProjectName</h1>`n    <script src='js/main.js'></script>`n</body>`n</html>" | Out-File -FilePath "index.html" -Encoding utf8
        "body { font-family: sans-serif; }" | Out-File -FilePath "css/style.css" -Encoding utf8
        "console.log('Web project loaded');" | Out-File -FilePath "js/main.js" -Encoding utf8
        Create-IgnoreFiles "Empty"
    }
    "7" { # AI Agent & Ecosystem
        Write-Host "  [+] Creating Multi-Agent ecosystem structure..." -ForegroundColor Yellow
        
        # 1. General .agent structure (Memory, Knowledge)
        New-Item -ItemType Directory -Path ".agent/skills", ".agent/workflows", ".agent/rules", ".agent/brain", ".agent/logs" | Out-Null
        "# AI Agent Logic`n`n- Focus: Project Automation`n- Style: Professional" | Out-File -FilePath ".agent/rules/global.md" -Encoding utf8
        
        # 2. Cursor AI (.cursor/rules)
        New-Item -ItemType Directory -Path ".cursor/rules" | Out-Null
        "# Project Rules`n`n- Use TypeScript`n- Follow Clean Architecture" | Out-File -FilePath ".cursor/rules/project.mdc" -Encoding utf8
        
        # 3. Windsurf (instructions.md)
        "# Windsurf Instructions`n`nDescribe your feature roadmap and tech stack here." | Out-File -FilePath "instructions.md" -Encoding utf8
        
        # 4. Claude/Anthropic (CLAUDE.md)
        "# CLAUDE.md`n`n- Build: npm run build`n- Test: npm test`n- Style: Functional" | Out-File -FilePath "CLAUDE.md" -Encoding utf8
        
        # 5. GitHub Copilot (.github/copilot-instructions.md)
        New-Item -ItemType Directory -Path ".github" | Out-Null
        "# Copilot Instructions`n`n- Preferred Library: React/Query`n- Documentation: JSDoc" | Out-File -FilePath ".github/copilot-instructions.md" -Encoding utf8
        
        # 6. Gemini AI (GEMINI.md)
        "# GEMINI.md`n`nProvide project goals and architectural guidelines for Gemini here." | Out-File -FilePath "GEMINI.md" -Encoding utf8
        
        # 7. Codex (.codex/)
        New-Item -ItemType Directory -Path ".codex" | Out-Null
        "[project]`nname = `"$ProjectName`"`ndescription = `"AI-First Project`"" | Out-File -FilePath ".codex/config.toml" -Encoding utf8
        
        # 8. General Agentic Files
        "# AGENTS.md`n`nOverview of all AI agents in this project." | Out-File -FilePath "AGENTS.md" -Encoding utf8
        
        Create-IgnoreFiles "AI"
    }
    Default {
        Create-IgnoreFiles "Empty"
    }
}

Write-Host "  [3/3] Initializing Git repository..." -ForegroundColor Cyan
git init -q

Write-Host "`n  ========================================" -ForegroundColor Green
Write-Host "     ✅ Project '$ProjectName' Ready!" -ForegroundColor White
Write-Host "  ========================================" -ForegroundColor Green
Write-Host "  Location: $(Get-Location)" -ForegroundColor DarkGray
Write-Host "  Template: $template" -ForegroundColor DarkGray
Write-Host ""
