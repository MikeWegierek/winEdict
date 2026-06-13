

### 26.01.24

### AdminCheck
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw "Run elevated you twat"}

### FuckDefender
if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {try { Set-MpPreference -DisableRealtimeMonitoring $true } catch {}}

Set-Location $PSScriptRoot

# =========================
# VAR
# =========================
$live      = $false
$wimMounted = $false

$oscdimg   = Join-Path $PSScriptRoot 'oscdimg.exe'
$parentDir = Split-Path $PSScriptRoot -Parent
$srcIsoDir = Join-Path $PSScriptRoot 'clean'
$isoOut    = Join-Path $PSScriptRoot 'clean-injected.iso'
$etf       = Join-Path $srcIsoDir 'boot\etfsboot.com'
$efi       = Join-Path $srcIsoDir 'efi\boot\bootx64.efi'
$edictDir  = Join-Path $parentDir 'Edict'
$srcDir    = Join-Path $PSScriptRoot 'src'
$ppkgSrc   = Join-Path $srcDir 'prov.ppkg'
$unaDst    = Join-Path $srcIsoDir 'autounattend.xml'
$ppkgDst   = Join-Path $edictDir 'prov.ppkg'
$wim       = Join-Path $srcIsoDir 'sources\install.wim'
$mnt       = Join-Path $PSScriptRoot 'mnt'
$scratch   = Join-Path $env:SystemDrive 'DISM_SCRATCH'
$wimcpy    = Join-Path $srcDir 'ccpy.wim'
$oemLoad   = Join-Path $PSScriptRoot 'OEM_PAYLOAD'
$esd       = Join-Path $srcIsoDir 'sources\install.esd'
$esdIndex  = "6"
$wimIndex  = "1"

function Remove-MountDirectory {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    try {
        dism /Unmount-Wim /MountDir:"$Path" /Discard 2>&1 | Out-Null
    } catch {}
    # Try repeated removal attempts to handle transient locks
    $maxRetries = 6
    $delayMs = 500
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            takeown /f $Path /r /d y 2>&1 | Out-Null
            icacls $Path /grant Administrators:F /t 2>&1 | Out-Null
        } catch {}

        # Clear read-only / hidden attributes
        try { Get-ChildItem -Path $Path -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Set-ItemProperty -LiteralPath $_.FullName -Name Attributes -Value ([System.IO.FileAttributes]::Normal) } } catch {}
        try { cmd /c "rmdir /s /q `"$Path`"" 2>&1 | Out-Null } catch {}
        Start-Sleep -Milliseconds $delayMs
        if (-not (Test-Path $Path)) { break }
        try { Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        if (-not (Test-Path $Path)) { break }
    } try { dism /Cleanup-Wim 2>&1 | Out-Null } catch {}
}

try {
# Verify sources
if (-not (Test-Path $edictDir))     { throw "Source not found - $edictDir" }
if (-not (Test-Path $ppkgSrc))      { throw "PPKG missing - $ppkgSrc" }
if (-not (Test-Path $oscdimg))      { throw "oscdimg.exe not found - $oscdimg" }
if (-not (Test-Path $srcIsoDir))    { throw "Source ISO directory not found - $srcIsoDir" }


# =========================
# ISO staging
# =========================
if ($live) {
    $unaSrc = Join-Path $srcDir 'autounattend-lm.xml'
} else {
    $unaSrc = Join-Path $srcDir 'autounattend-vm.xml'
}
Copy-Item $unaSrc $unaDst -Force
Copy-Item $ppkgSrc $ppkgDst -Force

if (Test-Path $oemLoad) { Remove-Item $oemLoad -Recurse -Force }
New-Item -ItemType Directory -Path $oemLoad -Force | Out-Null
Get-ChildItem -Path $srcDir -Filter '*.cmd' -File | Copy-Item -Destination $oemLoad -Force
Copy-Item $edictDir $oemLoad -Recurse -Force
Write-Host "ISO staging complete." -ForegroundColor Cyan


# =========================
# WIM injection
# =========================
Remove-MountDirectory -Path $mnt
Remove-MountDirectory -Path $scratch
try {
    New-Item -ItemType Directory -Path $mnt -Force -ErrorAction Stop | Out-Null
    New-Item -ItemType Directory -Path $scratch -Force -ErrorAction Stop | Out-Null
} catch {
    throw "Failed to create mount directories - $_"
}

try {
    $hasWimCpy = Test-Path $wimcpy
    $hasEsd    = Test-Path $esd

    ### WIM Reset
    if (-not $hasWimCpy -and -not $hasEsd) { throw "Neither prebuilt WIM nor install.esd found." }
    if (Test-Path $wim) {
        Write-Host "Removing existing install.wim." -ForegroundColor Gray
        Remove-Item $wim -Force -ErrorAction Stop
    }

    if ($hasWimCpy) {
        try { Copy-Item -Path $wimcpy -Destination $wim -Force -ErrorAction Stop } catch { throw }
    } else {
        Write-Host "Converting ESD > WIM." -ForegroundColor Gray
            dism /Export-Image /SourceImageFile:"$esd" /SourceIndex:$esdIndex /DestinationImageFile:"$wim" /Compress:max /CheckIntegrity /ScratchDir:"$scratch"
        if ($LASTEXITCODE -ne 0) { throw "ESD→WIM conversion failed (exit $LASTEXITCODE)" }
        Write-Host "ESD converted." -ForegroundColor Gray
    }
    Write-Host "Using existing WIM." -ForegroundColor Gray

    ### WIM Mount
    Write-Host "Mounting WIM." -ForegroundColor Magenta
        dism /Mount-Wim /WimFile:"$wim" /Index:$wimIndex /MountDir:"$mnt" /ScratchDir:"$scratch" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "DISM mount failed (exit $LASTEXITCODE)" }
    $wimMounted = $true
    $mounted = $false
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $mounted = (dism /Get-MountedWimInfo 2>&1 | Select-String -Quiet ([regex]::Escape($mnt)))
        } catch { $mounted = $false }
        if ($mounted) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $mounted) { throw "WIM mount not registered with DISM (timeout)" }
    Write-Host "WIM mounted." -ForegroundColor Gray

    ### Edict Inject
    $destOem = Join-Path $mnt 'Windows\Setup\Scripts'

    if (Test-Path $oemLoad) {
        Write-Host "Injecting Edict." -ForegroundColor Gray
        robocopy "$oemLoad" "$destOem" /E /R:0 /W:0 /NFL /NDL /NJH /NJS
        if ($LASTEXITCODE -ge 8) { throw "ROBOCOPY failed (exit $LASTEXITCODE)" }
    } else {
        Write-Host "Warning - OEM payload not found - $oemLoad" -ForegroundColor Yellow
    }

    Write-Host "Committing WIM." -ForegroundColor Gray

    dism /Unmount-Wim /MountDir:"$mnt" /Commit /ScratchDir:"$scratch"

    if ($LASTEXITCODE -ne 0) { throw "DISM unmount/commit failed (exit $LASTEXITCODE)" }
    $wimMounted = $false

    Write-Host "WIM injected." -ForegroundColor Cyan

} catch {  Write-Host "Error during WIM injection - $_" -ForegroundColor Red
    throw
} finally {
    if ($wimMounted) {
        Write-Host "Cleaning WIM." -ForegroundColor Gray
        try { dism /Unmount-Wim /MountDir:"$mnt" /Discard 2>&1 | Out-Null } catch {}
        try { dism /Cleanup-Wim 2>&1 | Out-Null } catch {}
    }

    Remove-MountDirectory -Path $mnt
    Remove-MountDirectory -Path $scratch

    if (Test-Path $mnt) { Write-Host "Mount directory still exists." -ForegroundColor Yellow }
    dism /Cleanup-Wim 2>&1 | Out-Null
}

# =========================
# ISO build
# =========================
try {
    if (Test-Path $isoOut) {
        Write-Host "Removing ISO." -ForegroundColor Gray
        Remove-Item $isoOut -Force -ErrorAction Stop
    }

    if (-not (Test-Path $etf)) { throw "Boot file not found - $etf" }
    if (-not (Test-Path $efi)) { throw "EFI boot file not found - $efi" }

    Write-Host "Building ISO." -ForegroundColor Gray

    $bootArg = "2#p0,e,b$etf#pEF,e,b$efi"
    & $oscdimg "-bootdata:$bootArg" -u2 -udfver102 -h -m -lOSX "$srcIsoDir" "$isoOut"
    if ($LASTEXITCODE -ne 0) { throw "oscdimg failed (exit $LASTEXITCODE)" }
    if (-not (Test-Path $isoOut)) { throw "ISO file was not created - $isoOut" }

    Write-Host "Build complete." -ForegroundColor Cyan

} catch {
    Write-Host "Error during ISO build - $_" -ForegroundColor Red
    throw
} finally {
    dism /Cleanup-Wim 2>&1 | Out-Null
    Write-Host "Cleanup complete." -ForegroundColor Gray
}
} finally {
    ### RestoreDefender
    if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
        try { Set-MpPreference -DisableRealtimeMonitoring $false } catch {}
    }
    Write-Host "Windows Defender Restored." -ForegroundColor Gray
}

Write-Host "Script complete." -BackgroundColor Cyan -ForegroundColor DarkGray