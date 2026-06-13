

$DisableIndexingPolicy = 0 #1 to disable
$AdjustForBestPerformance = 2
$AnimateControlsAndElementsInsideWindows = 0
$EnableDesktopComposition = 1
$EnableAeroPeek = 0
$FadeOrSlideTooltipsIntoView = 0
$FadeOutMenuItemsAfterClicking = 0
$ShowThumbnailsInsteadOfIcons = 1
$SlideOpenComboBoxes = 0
$SmoothScrollListBoxes = 0
$AnimateWindowsWhenMinimizingAndMaximizing = 1
$FadeOrSlideMenusIntoView = 1
$ShowShadowsUnderWindows = 0
$ShowTranslucentSelectionRectangle = 1
$SmoothEdgesOfScreenFonts = 1
$UseDropShadowsForIconLabelsOnTheDesktop = 0
$UseVisualStylesOnWindowsAndButtons = 0

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$regSysPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$regAdvancedPath = "HKCU:\Control Panel\Desktop"
$regIndexingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

# Set-ItemProperty $regIndexingPath -Name NtfsDisableLastAccessUpdate -Value $DisableIndexingPolicy
Set-ItemProperty $regAdvancedPath -Name AnimateWindowsWhenMinimizingAndMaximizing -Value $AnimateWindowsWhenMinimizingAndMaximizing
Set-ItemProperty $regAdvancedPath -Name FadeOrSlideMenusIntoView -Value $FadeOrSlideMenusIntoView
Set-ItemProperty $regAdvancedPath -Name ShowShadowsUnderWindows -Value $ShowShadowsUnderWindows
Set-ItemProperty $regAdvancedPath -Name ShowTranslucentSelectionRectangle -Value $ShowTranslucentSelectionRectangle
Set-ItemProperty $regAdvancedPath -Name SmoothEdgesOfScreenFonts -Value $SmoothEdgesOfScreenFonts
Set-ItemProperty $regAdvancedPath -Name UseDropShadowsForIconLabelsOnTheDesktop -Value $UseDropShadowsForIconLabelsOnTheDesktop
Set-ItemProperty $regAdvancedPath -Name UseVisualStylesOnWindowsAndButtons -Value $UseVisualStylesOnWindowsAndButtons
Set-ItemProperty $regAdvancedPath -Name DesktopComposition -Value $EnableDesktopComposition
Set-ItemProperty $regAdvancedPath -Name EnableAeroPeek -Value $EnableAeroPeek
Set-ItemProperty $regAdvancedPath -Name IconShow -Value $ShowThumbnailsInsteadOfIcons
Set-ItemProperty $regAdvancedPath -Name ListBoxSmoothScrolling -Value $SmoothScrollListBoxes
Set-ItemProperty $regAdvancedPath -Name ComboBoxAnimation -Value $SlideOpenComboBoxes
Set-ItemProperty $regAdvancedPath -Name MenuAnimation -Value $AnimateControlsAndElementsInsideWindows
Set-ItemProperty $regAdvancedPath -Name TooltipAnimation -Value $FadeOrSlideTooltipsIntoView
Set-ItemProperty $regAdvancedPath -Name TooltipFade -Value $FadeOutMenuItemsAfterClicking
Set-ItemProperty $regSysPath -Name PagingFiles -Value "$PagingFilePath $PagingFileSizeMB $PagingFileSizeMB"
Set-ItemProperty $regPath -Name VisualFXSetting -Value $AdjustForBestPerformance

Write-Output "Performance set." "Indexing Disabled" -ForegroundColor Green


<# #Switch, what the fuck windows
if ($AllowIndexingPagefile -eq 0) {
    Set-ItemProperty -Path $regIndexingPath -Name "NtfsDisableLastAccessUpdate" -Value 1
} elseif ($AllowIndexingPagefile -eq 1) {
    Set-ItemProperty -Path $regIndexingPath -Name "NtfsDisableLastAccessUpdate" -Value 0
} #>