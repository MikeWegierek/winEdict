# Ensure proper path resolution - works when called directly or via Start-Process
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$srcDir = Join-Path $PSScriptRoot "..\gui\cursor"
$infFiles = Get-ChildItem -Path $srcDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue

if (-not (Test-Path $srcDir)) {
    Write-Error "Cursor directory not found: $srcDir"
    exit 1
}

if ($infFiles.Count -eq 0) {
    Write-Warning "No .inf files found in $srcDir"
    exit 0
}

foreach ($infFile in $infFiles) {
    try {
        $infPath = $infFile.FullName
        Write-Host "Installing cursor scheme from $infPath" -ForegroundColor Cyan
        $process = Start-Process -FilePath "rundll32.exe" -ArgumentList "setupapi,InstallHinfSection DefaultInstall 132 `"$infPath`"" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {Write-Warning "Failed to install cursor scheme from $infPath (Exit code: $($process.ExitCode))"}
    } catch {Write-Error "Error installing cursor scheme from $($infFile.FullName): $_"}
}