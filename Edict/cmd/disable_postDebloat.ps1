# disable Memory Compression (requires SysMain (service))
Disable-MMAgent -mc
#Get-MMAgent

# echo "Now you can also disable service SysMain (former Superfetch) in case it's not used."
#Get-Service "SysMain" | Set-Service -StartupType Disabled -PassThru | Stop-Service


Disable-MMAgent -ApplicationPreLaunch
#Get-MMAgent

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d "0" /f


# SSD life improvement
fsutil behavior set DisableLastAccess 1
fsutil behavior set EncryptPagingFile 0
