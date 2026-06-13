# install-fonts.ps1
$FontDir = Join-Path $PSScriptRoot "..\gui\font"

Get-ChildItem -Path $FontDir -Filter *.ttf | ForEach-Object {
    $dest = "$env:WINDIR\Fonts\$($_.Name)"
    Copy-Item $_.FullName -Destination $dest -Force
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fontName = $_.BaseName
    $fontEntry = "$fontName (TrueType)"
    New-ItemProperty -Path $regPath -Name $fontEntry -Value $_.Name -PropertyType String -Force
}
