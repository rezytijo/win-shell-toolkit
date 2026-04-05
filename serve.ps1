# serve.ps1 -- Instant HTTP Server
# 2026-04-05 -- v1.0.1: Added global error handling
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Utility script.

.DESCRIPTION
This script is part of the CustomScripts arsenal.

.PARAMETER Port
    Specifies the Port parameter.

.EXAMPLE
    serve
#>

param(
    [Parameter(Position=0, HelpMessage="Port to bind the server on")]
    [int]$Port = 8080
)

function Invoke-Serve {
    $separator = "=========================================================="
    Write-Host ""
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host "   INSTANT HTTP SERVER (PowerShell)" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor DarkGray
    Write-Host ""

    # Generate an HTML directory listing
    $files = Get-ChildItem | Select-Object Name, Length, LastWriteTime
    $html = "<html><head><title>Directory listing for $($PWD.Path)</title>"
    $html += "<style>body{font-family: monospace; background:#121212; color:#eee;} a{color:#4da6ff; text-decoration:none;} a:hover{text-decoration:underline;}</style></head><body>"
    $html += "<h2>Directory listing for: $($PWD.Path)</h2><hr><ul>"
    $html += "<li><a href='../'>[Parent Directory]</a></li>"
    foreach ($f in $files) {
        $html += "<li><a href='$($f.Name)'>$($f.Name)</a> - $($f.Length) bytes - $($f.LastWriteTime)</li>"
    }
    $html += "</ul><hr></body></html>"

    Write-Host "  [*] Booting HTTPListener on Port: " -NoNewline -ForegroundColor Yellow
    Write-Host $Port -ForegroundColor Green

    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://*:$Port/")
        $listener.Start()

        Write-Host "  [+] Server is running! Access via browser at:" -ForegroundColor Cyan
        Write-Host "      http://localhost:$Port" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Press CTRL+C at any time to stop the server." -ForegroundColor Red
        Write-Host ""
        
        while ($listener.IsListening) {
             $context = $listener.GetContext()
             $request = $context.Request
             $response = $context.Response
             
             $requestedFile = $request.Url.LocalPath.TrimStart('/')
             $fullPath = Join-Path -Path $PWD.Path -ChildPath $requestedFile
             
             Write-Host "  [Req] $($request.RemoteEndPoint.Address) - GET /$requestedFile" -ForegroundColor DarkGray
             
             if ($requestedFile -eq "" -or $requestedFile -eq "/") {
                 # Serve Directory Listing
                 $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                 $response.ContentLength64 = $buffer.Length
                 $response.ContentType = "text/html"
                 $response.OutputStream.Write($buffer, 0, $buffer.Length)
                 $response.StatusCode = 200
             } elseif (Test-Path $fullPath -PathType Leaf) {
                 # Serve the actual file
                 $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                 $response.ContentLength64 = $fileBytes.Length
                 $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
                 $response.StatusCode = 200
             } else {
                 # 404 Not Found
                 $response.StatusCode = 404
                 $buffer = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 Not Found</h1>")
                 $response.ContentLength64 = $buffer.Length
                 $response.OutputStream.Write($buffer, 0, $buffer.Length)
             }
             
             $response.Close()
        }
    } catch {
        Write-Host "  [Error] Port $Port is likely in use. Try `serve 8081`." -ForegroundColor Red
    } finally {
        if ($listener.IsListening) {
            $listener.Stop()
        }
        $listener.Close()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-Serve
    } catch {
        Write-Host "`n[ERROR] A critical error occurred in $($MyInvocation.MyCommand.Name):" -ForegroundColor Red
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
