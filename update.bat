@echo off
SET "scpath=%~dp0update.ps1"
WHERE pwsh >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%scpath%" %*
) ELSE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%scpath%" %*
)
