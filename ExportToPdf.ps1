<#
.SYNOPSIS
Converts Office docs to PDF via "Microsoft Print to PDF"

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER FileName
    Specifies the FileName parameter.

.PARAMETER AllFiles
    Specifies the AllFiles parameter.

.PARAMETER Help
    Specifies the Help parameter.

.PARAMETER inputFile
    Specifies the inputFile parameter.

.EXAMPLE
    ExportToPdf
#>

param (
    [string]$FileName,
    [switch]$AllFiles,
    [switch]$Help
)

function Show-Help {
    Write-Output "Usage: export-to-pdf <options>"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -FileName <file>   Convert a specific file to PDF"
    Write-Output "  -AllFiles          Convert all files in the current directory to PDF"
    Write-Output "  -Help              Display this help message"
}

function Convert-ToPdf {
    param (
        [string]$inputFile
    )

    $pdfPrinter = "Microsoft Print to PDF"
    $outputFile = [System.IO.Path]::ChangeExtension($inputFile, ".pdf")

    $printProcess = New-Object System.Diagnostics.Process
    $printProcess.StartInfo.FileName = $inputFile
    $printProcess.StartInfo.Verb = "PrintTo"
    $printProcess.StartInfo.Arguments = $pdfPrinter
    $printProcess.StartInfo.UseShellExecute = $true
    $printProcess.Start()

    Start-Sleep -Seconds 5  # Adjust sleep time as needed

    if (Test-Path $outputFile) {
        Write-Output "Converted $inputFile to $outputFile"
    } else {
        Write-Output "Failed to convert $inputFile"
    }
}

if ($Help) {
    Show-Help
} elseif ($AllFiles) {
    Get-ChildItem -Path . -Filter *.docx, *.pptx, *.xlsx | ForEach-Object {
        Convert-ToPdf -inputFile $_.FullName
    }
} else {
    Convert-ToPdf -inputFile $FileName
}
