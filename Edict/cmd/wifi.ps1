
# Ensure proper path resolution
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$wifiPath = Join-Path $PSScriptRoot "..\cfg\wifi"

if (-not (Test-Path $wifiPath)) {
    Write-Warning "WiFi profiles directory not found: $wifiPath"
    exit 0
}

$wifiFiles = Get-ChildItem $wifiPath -Filter *.xml -ErrorAction SilentlyContinue

if ($wifiFiles.Count -eq 0) {
    Write-Warning "No WiFi profile XML files found in $wifiPath"
    exit 0
}

foreach ($wifiFile in $wifiFiles) {
    try {
        $xmlContent = [xml](Get-Content $wifiFile.FullName -ErrorAction Stop)
        $networkName = $xmlContent.WLANProfile.Name

        if ($networkName) {
            $profilePath = $wifiFile.FullName
            $result = netsh wlan add profile filename="$profilePath" user=all 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "Added network: $networkName"
            } else {
                $resultStr = if ($result -is [array]) { $result -join ' ' } else { $result.ToString() }
                Write-Warning "Failed to add network profile $networkName`: $resultStr"
            }
        }
    } catch {
        Write-Error "Error processing WiFi profile $($wifiFile.FullName): $_"
    }
}