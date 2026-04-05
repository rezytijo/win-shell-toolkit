#Requires -Version 5.1
# ExportToPdf.ps1 -- Automated PDF conversion utility
# 2026-04-05 -- v2.0.2: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Converts documents (Office, Text, Image) to PDF silently using Office COM or PrintTo Verb.

.DESCRIPTION
    This script is part of the CustomScripts arsenal.
    It priorities Microsoft Office COM automation for silent, high-quality PDF exports.
    If Office is not installed or the file type is not supported via COM, it fallbacks to the 'PrintTo' verb.

.PARAMETER Path
    The file(s) or folder to convert. Supports wildcards (e.g., *.docx).

.PARAMETER All
    If specified, converts all supported documents (*.docx, *.pptx, *.xlsx) in the current directory.

.EXAMPLE
    export-to-pdf Report.docx
    export-to-pdf *.pptx
    export-to-pdf -All
#>

param (
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string]$Path,

    [switch]$All,

    [switch]$Help
)

function Show-Usage {
    Write-Host "`nExportToPdf Utility v2.0.2" -ForegroundColor Cyan
    Write-Host "Automated PDF conversion using Office COM or PrintTo fallback.`n" -ForegroundColor DarkGray
    
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host ("  {0,-30} {1}" -f "export-to-pdf <Path>", "Convert specific file or wildcard (e.g. *.docx)") -ForegroundColor White
    Write-Host ("  {0,-30} {1}" -f "export-to-pdf -All", "Convert all Office docs in the current folder") -ForegroundColor White
    Write-Host ("  {0,-30} {1}" -f "export-to-pdf -Help", "Display this help message") -ForegroundColor White
    
    Write-Host "`nNotes:" -ForegroundColor Yellow
    Write-Host "  * Silent conversion requires MS Office (Word/Excel/PowerPoint) installed." -ForegroundColor DarkGray
    Write-Host "  * Non-Office files will trigger the 'Microsoft Print to PDF' dialog." -ForegroundColor DarkGray
    
    Write-Host "`nExamples:" -ForegroundColor Yellow
    Write-Host "  export-to-pdf Report.docx" -ForegroundColor White
    Write-Host "  export-to-pdf *.pptx" -ForegroundColor White
    Write-Host "  dir *.xlsx | export-to-pdf" -ForegroundColor White
}

function Convert-ToPdf {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FullName
    )

    $extension = [System.IO.Path]::GetExtension($FullName).ToLower()
    $outputFile = [System.IO.Path]::ChangeExtension($FullName, ".pdf")
    
    if (Test-Path $outputFile) {
        Write-Host "  [Skip] Existing: $(Split-Path $outputFile -Leaf)" -ForegroundColor DarkGray
        return
    }

    Write-Host "  [Working] $(Split-Path $FullName -Leaf) ... " -NoNewline -ForegroundColor White

    $useFallback = $true

    try {
        # --- Word Automation ---
        if ($extension -match '\.doc|rtf') {
            try {
                $word = New-Object -ComObject Word.Application -ErrorAction Stop
                $doc = $word.Documents.Open($FullName, $false, $true)
                $doc.ExportAsFixedFormat($outputFile, 17) # wdExportFormatPDF
                $doc.Close(0) # wdDoNotSaveChanges
                $word.Quit()
                Write-Host "OK (Word)" -ForegroundColor Green
                $useFallback = $false
            }
            catch {
                Write-Host "Word COM not found, falling back... " -NoNewline -ForegroundColor Yellow
            }
        }

        # --- Excel Automation ---
        elseif ($extension -match '\.xls|csv') {
            try {
                $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
                $wb = $excel.Workbooks.Open($FullName, 0, $true)
                $wb.ExportAsFixedFormat(0, $outputFile) # xlTypePDF
                $wb.Close($false)
                $excel.Quit()
                Write-Host "OK (Excel)" -ForegroundColor Green
                $useFallback = $false
            }
            catch {
                Write-Host "Excel COM not found, falling back... " -NoNewline -ForegroundColor Yellow
            }
        }

        # --- PowerPoint Automation ---
        elseif ($extension -match '\.ppt') {
            try {
                $ppt = New-Object -ComObject PowerPoint.Application -ErrorAction Stop
                $pres = $ppt.Presentations.Open($FullName, 1, 1, 0) # ReadOnly=True, Untitled=False, WithWindow=False
                $pres.SaveAs($outputFile, 32) # ppSaveAsPDF
                $pres.Close()
                $ppt.Quit()
                Write-Host "OK (PowerPoint)" -ForegroundColor Green
                $useFallback = $false
            }
            catch {
                Write-Host "PPT COM not found, falling back... " -NoNewline -ForegroundColor Yellow
            }
        }

        # --- Fallback: PrintTo Verb ---
        if ($useFallback) {
            Write-Host "Printing... " -NoNewline -ForegroundColor Yellow
            $printProcess = Start-Process -FilePath $FullName -Verb PrintTo -ArgumentList "Microsoft Print to PDF" -PassThru -WindowStyle Hidden
            $printProcess.WaitForExit(15000) # Wait up to 15s
            
            if (Test-Path $outputFile) {
                Write-Host "OK (Print)" -ForegroundColor Green
            }
            else {
                Write-Host "FAILED" -ForegroundColor Red
                Write-Warning "Check if 'Microsoft Print to PDF' dialog popped up, Office is missing, or file is locked."
            }
        }
    }
    catch {
        Write-Host "ERROR" -ForegroundColor Red
        Write-Warning "Critical failure during conversion: $($_.Exception.Message)"
    }
    finally {
        # Final cleanup for hanging processes (aggressive but safe for shell utility)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

function Invoke-ExportToPdf {
    if ($Help -or (-not $Path -and -not $All -and -not $InputObject)) {
        Show-Usage
        return
    }

    $targets = @()
    if ($All) {
        $targets = Get-ChildItem -Path . -Include *.docx, *.doc, *.xlsx, *.xls, *.pptx, *.ppt -File
    }
    elseif ($Path) {
        if ($Path -match '\*') {
            $targets = Get-ChildItem -Path . -Filter $Path -File
        }
        else {
            $targets = Resolve-Path $Path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
        }
    }

    if ($targets.Count -eq 0) {
        Write-Warning "No target files found."
        return
    }

    Write-Host "Convert-To-Pdf: Processing $($targets.Count) file(s)..." -ForegroundColor Cyan
    $i = 0
    foreach ($file in $targets) {
        $i++
        $filePath = if ($file.FullName) { $file.FullName } else { $file }
        Write-Progress -Activity "Converting Docs" -Status "Processing: $(Split-Path $filePath -Leaf)" -PercentComplete (($i / $targets.Count) * 100)
        Convert-ToPdf -FullName $filePath
    }
    Write-Host "`nConversion complete." -ForegroundColor Cyan
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ExportToPdf
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
