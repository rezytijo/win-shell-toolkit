param(
    [Parameter(Mandatory=$true)]
    [string]$TargetFolder
)

if (!(Test-Path $TargetFolder)) {
    Write-Error "Folder tidak ditemukan: $TargetFolder"
    exit 1
}

$foldersToDelete = @(
    # Python
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".tox",
    ".venv",
    "venv",

    # NodeJS
    "node_modules",
    ".next",
    ".nuxt",
    ".cache",
    ".turbo",
    "dist",
    "build",
    "coverage",

    # Golang
    "bin",
    "pkg"
)

$filesToDelete = @(
    "*.pyc",
    "*.pyo",
    "*.test",
    "coverage.out"
)

Write-Host "Scanning $TargetFolder ..."

# Hapus folder
Get-ChildItem $TargetFolder -Recurse -Directory -Force -ErrorAction SilentlyContinue |
Where-Object { $foldersToDelete -contains $_.Name } |
ForEach-Object {
    Write-Host "Removing folder: $($_.FullName)"
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# Hapus file
foreach ($pattern in $filesToDelete) {
    Get-ChildItem $TargetFolder -Recurse -File -Force -Filter $pattern -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host "Removing file: $($_.FullName)"
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Cleanup completed."