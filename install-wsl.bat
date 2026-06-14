@echo off
chcp 65001 >nul
echo ==================================================
echo          WSL 安装脚本
echo ==================================================
echo.
echo 此脚本需要以管理员身份运行！
echo 如果没有管理员权限，请右键选择"以管理员身份运行"
echo.

:CHECK_ADMIN
    fsutil dirty query %systemdrive% >nul
    if %errorlevel% neq 0 (
        echo ERROR: 请以管理员身份运行此脚本！
        pause
        exit /b 1
    )

echo [1/3] 启用 WSL 功能...
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

echo.
echo [2/3] 启用虚拟机平台...
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

echo.
echo [3/3] 设置 WSL 2 为默认版本...
wsl --set-default-version 2

echo.
echo ==================================================
echo          WSL 安装完成！
echo ==================================================
echo.
echo 请重新启动电脑，然后运行：
echo   wsl --install -d Ubuntu
echo.
echo 或直接运行 wsl 启动默认分发版
echo.
pause
