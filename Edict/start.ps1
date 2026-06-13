

# 26.01.24


# =========================
# Serenity                                     ##### Super-Silent Flags
# =========================
$ErrorActionPreference = 'Continue'            ##### Ignore errors, continue execution
$WarningPreference     = 'SilentlyContinue'    ##### Suppress warnings
$InformationPreference = 'SilentlyContinue'    ##### Suppress informational messages
$VerbosePreference     = 'SilentlyContinue'    ##### Suppress verbose output
$DebugPreference       = 'SilentlyContinue'    ##### Suppress debug messages
$ProgressPreference    = 'SilentlyContinue'    ##### Disable progress bars
$ConfirmPreference     = 'None'                ##### Disable confirmation prompts
# try { $Host.UI.Prompt = { "" } } catch {}    ##### Disable interactive prompts (read-only in PS7, ignore error)
# $Host.UI.ReadLine = { "" }                   ##### Prevent read input interruptions


# =========================
# VAR
# =========================
$mainDir = "C:"
$tmpWinP = "$mainDir\TMP_chocoDeploy"
$tmpWinX = "$mainDir\ProgramData\chocolatey\tmp"
$logDir = "$mainDir\_edictLogs"
$flags = "-r --ignore-checksums --allow-downgrade --skip-virus-check --params=`"/NoDesktopIcon /NoQuicklaunchIcon /NoContextMenuFiles /NoContextMenuFolders /DontAddToPath`""
$jsonData = $null
$jsonPath = Join-Path $PSScriptRoot 'cfg\chocolist.json'
$deploymentCommands = Join-Path $PSScriptRoot ".\cmd"
$deploymentRegistry = Join-Path $PSScriptRoot ".\cfg"
$oldTEMP = [System.Environment]::GetEnvironmentVariable("TEMP", "Process")
$oldTMP  = [System.Environment]::GetEnvironmentVariable("TMP",  "Process")
$logTimestamp = Get-Date -Format "yyMMddHHmm"
$logFile = Join-Path $logDir "edict_$logTimestamp.log"


# =========================
# Prep
# =========================
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HHmmss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=== Edict deployment script started ===" "INFO"
Write-Log "Script root: $PSScriptRoot" "INFO"

try {
    $jsonData = Get-Content $jsonPath | ConvertFrom-Json
    Write-Log "Loaded chocolist.json: $($jsonData.PSObject.Properties.Count) groups" "INFO"
    Write-Log "Loaded lists: $($jsonData.PSObject.Properties.Name)" "INFO"
} catch { Write-Log "Failed to load chocolist.json: $_" "ERROR"}

if (-not (Test-Path $tmpWinP)) { New-Item -ItemType Directory -Path $tmpWinP -Force | Out-Null }

[System.Environment]::SetEnvironmentVariable("TEMP", $tmpWinP, [System.EnvironmentVariableTarget]::Process)
[System.Environment]::SetEnvironmentVariable("TMP", $tmpWinP, [System.EnvironmentVariableTarget]::Process)



# =========================
# Scripts
# =========================
if (Test-Path $deploymentCommands) {
    $scriptFiles = Get-ChildItem -Path $deploymentCommands -Filter *.ps1 -File -ErrorAction SilentlyContinue | Sort-Object FullName
    Write-Log "Found $($scriptFiles.Count) script(s) in cmd directory (including subdirectories)" "INFO"
    foreach ($script in $scriptFiles) {
        $scriptStartTime = Get-Date
        Write-Log "Executing script: $($script.Name)" "INFO"
        try {
            $process = Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$($script.FullName)`"" `
                -NoNewWindow -Wait -PassThru
            $scriptDuration = (Get-Date) - $scriptStartTime

            # Check exit code - PowerShell scripts return 0 on success, non-zero on failure
            if ($process.ExitCode -eq 0) {
                Write-Log "Completed script: $($script.Name) (Exit code: 0, Duration: $($scriptDuration.TotalSeconds)s)" "INFO"
            } else {
                Write-Log "Script completed with errors: $($script.Name) (Exit code: $($process.ExitCode), Duration: $($scriptDuration.TotalSeconds)s)" "ERROR"
            }
        } catch {
            $scriptDuration = (Get-Date) - $scriptStartTime
            Write-Log "Exception executing script $($script.Name): $_ (Duration: $($scriptDuration.TotalSeconds)s)" "ERROR"
        }
    }
} else {
    Write-Log "Deployment commands directory not found: $deploymentCommands" "WARN"
}



# =========================
# Provision
# =========================
$ppkgPath = Join-Path $PSScriptRoot "prov.ppkg"
if (Test-Path $ppkgPath) {
    Write-Log "Found provisioning package: $ppkgPath" "INFO"
    Write-Log "Attempting to install provisioning package..." "INFO"

    try {
        $dismPath = Join-Path $env:SystemRoot "System32\dism.exe"
        $ppkgProcess = Start-Process -FilePath $dismPath `
            -ArgumentList "/online", "/add-provisioningpackage", "/packagepath:`"$ppkgPath`"", "/quiet" `
            -Wait -NoNewWindow -PassThru

        if ($ppkgProcess.ExitCode -eq 0) {
            Write-Log "Provisioning package installed successfully (Exit code: 0)" "INFO"
        } else {
            Write-Log "Provisioning package installation failed (Exit code: $($ppkgProcess.ExitCode))" "ERROR"
            Write-Log "Note: PPKG may have already been installed during OOBE" "INFO"
        }
    } catch {
        Write-Log "Exception installing provisioning package: $_" "ERROR"
    }
} else {
    Write-Log "Provisioning package not found: $ppkgPath" "WARN"
    Write-Log "Skipping provisioning package installation" "INFO"
}

# =========================
# Choco
# =========================
Write-Log "Installing Chocolatey..." "INFO"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    $chocoUrl = 'https://community.chocolatey.org/install.ps1'
    $webClient = New-Object Net.WebClient
    $webClient.Headers.Add('User-Agent', 'Edict-Deployment')
    Invoke-Expression ($webClient.DownloadString($chocoUrl))
    Write-Log "Chocolatey installation script executed" "INFO"
} catch {
    Write-Log "Error downloading Chocolatey installer: $_" "ERROR"
    Write-Log "Note: This may be expected if network connectivity is not available during OOBE" "WARN"
}

Write-Log "Waiting for Chocolatey to be available..." "INFO"
for ($i=0; $i -lt 100 -and -not (Get-Command choco -ErrorAction SilentlyContinue); $i++) {
    Start-Sleep 5
}

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey is available" "INFO"
    $env:PATH += ";$env:ProgramData\chocolatey\bin"

    try {
        choco feature enable -n allowGlobalConfirmation
        choco config set cacheLocation "$tmpWinP"
        Write-Log "Chocolatey configured" "INFO"
    } catch { Write-Log "Error configuring Chocolatey: $_" "ERROR"}} else { Write-Log "Chocolatey not available after 60 seconds" "ERROR"
}



$packages = @()
if ($jsonData) {
    foreach ($group in $jsonData.PSObject.Properties) {
        if ($group.Name -ieq 'ignore') {
            Write-Log "Skipping package group: $($group.Name)" "INFO"
            continue
        }


    }
    $packages = $packages | Sort-Object -Unique

}

# =========================
# Choco PKG
# =========================
if ($packages.Count -gt 0) {
    Write-Log "Installing $($packages.Count) regular package(s) via Chocolatey" "INFO"
    $joined = ($packages | ForEach-Object {
        $p = $_.ToString().Trim()
        if ($p -eq '') { return }
        $p
    }) -join ' '
    try {
        choco upgrade $joined $flags
        Write-Log "Regular package installation completed" "INFO"
    } catch {
        Write-Log "Error during regular package installation: $_" "ERROR"
    }
}


if ($packages.Count -eq 0) {Write-Log "No packages to install" "INFO" }
Start-Sleep -Seconds 5

if (-not (Test-Path $tmpWinX)) { New-Item -ItemType Directory -Path $tmpWinX -Force | Out-Null }
if (Get-Command choco -ErrorAction SilentlyContinue) {
    try {
        choco config set cacheLocation "$tmpWinX"
        Write-Log "Chocolatey cache location updated" "INFO"
    } catch {Write-Log "Error updating Chocolatey cache location: $_" "ERROR"}
}


# =========================
# Cleanup
# =========================
if (Test-Path $tmpWinP) {
    $maxRetries = 3
    $retryDelay = 5
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Remove-Item -Recurse -Force $tmpWinP -ErrorAction Stop
            Write-Log "Temp directory cleaned up successfully" "INFO"
            break
        } catch {
            if ($i -lt ($maxRetries - 1)) {
                Write-Log "Temp directory cleanup attempt $($i + 1) failed, retrying in $retryDelay seconds..." "WARN"
                Start-Sleep -Seconds $retryDelay
            } else {
                Write-Log "Temp directory cleanup failed after $maxRetries attempts: $_" "WARN"
                Write-Log "Directory will be cleaned up on next boot or manually" "INFO"
            }
        }
    }
}



# =========================
# RegEdit
# =========================
if (Test-Path $deploymentRegistry) {
    $regFiles = Get-ChildItem $deploymentRegistry -Filter *.reg -ErrorAction SilentlyContinue | Sort-Object Name
    Write-Log "Found $($regFiles.Count) registry file(s) to apply" "INFO"
    foreach ($regFile in $regFiles) {
        Write-Log "Applying registry file: $($regFile.Name)" "INFO"
        try {
            $process = Start-Process regedit.exe `
                -ArgumentList "/s `"$($regFile.FullName)`"" `
                -Wait -NoNewWindow -PassThru

            if ($process.ExitCode -eq 0) {
                Write-Log "Applied registry file: $($regFile.Name) (Exit code: 0)" "INFO"
            } else {Write-Log "Registry file application failed: $($regFile.Name) (Exit code: $($process.ExitCode))" "ERROR"
            }} catch {Write-Log "Exception applying registry file $($regFile.Name): $_" "ERROR"}}} else {Write-Log "Deployment registry directory not found: $deploymentRegistry" "WARN"}


[System.Environment]::SetEnvironmentVariable("TEMP", $oldTEMP, "Process")
[System.Environment]::SetEnvironmentVariable("TMP",  $oldTMP,  "Process")


Write-Log "Done." -ForegroundColor Cyan

