$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Switch-to-Windows-Container.lnk")
$Shortcut.TargetPath = "E:\AAA\Claude\switch-to-windows-container.bat"
$Shortcut.WorkingDirectory = "E:\AAA\Claude"
$Shortcut.Description = "Switch Docker to Windows Container mode"
$Shortcut.IconLocation = "shell32.dll,15"
$Shortcut.Save()

Write-Host "Shortcut created on desktop!"
