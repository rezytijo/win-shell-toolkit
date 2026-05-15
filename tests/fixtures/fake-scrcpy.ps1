param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

$outputRoot = $env:SCRCPY_WRAPPER_TEST_OUTPUT
if (-not $outputRoot) {
    throw 'SCRCPY_WRAPPER_TEST_OUTPUT is required for fake-scrcpy.'
}

$ArgsList | Set-Content -Path (Join-Path $outputRoot 'scrcpy-args.txt')
Write-Output 'fake scrcpy invoked'
