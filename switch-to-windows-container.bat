@echo off
chcp 65001 >nul
title 切换到 Windows Container 模式

echo ==================================================
echo          切换到 Windows Container 模式
echo ==================================================
echo.

:CHECK_ADMIN
    fsutil dirty query %systemdrive% >nul 2>&1
    if %errorlevel% neq 0 (
        echo ERROR: 请以管理员身份运行此脚本！
        echo.
        echo 操作步骤：
        echo 1. 右键点击此脚本
        echo 2. 选择 "以管理员身份运行"
        echo.
        pause
        exit /b 1
    )

echo [1/3] 检查 Docker 状态...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker 未安装或未启动！
    echo 请先安装并启动 Docker Desktop
    pause
    exit /b 1
)

echo Docker 版本:
docker --version
echo.

echo [2/3] 检查当前容器模式...
for /f "tokens=*" %%i in ('docker info 2^>nul ^| findstr /i "OSType"') do (
    set "OSTYPE=%%i"
)
echo 当前模式: %OSTYPE%
echo.

echo [3/3] 尝试自动切换到 Windows Container...
echo 正在切换到 Windows Container 模式...
echo.

REM 尝试使用 Docker CLI 切换模式
docker context use default >nul 2>&1

REM 检查是否成功切换
for /f "tokens=*" %%i in ('docker info 2^>nul ^| findstr /i "OSType"') do (
    set "NEW_OSTYPE=%%i"
)

echo.
echo ==================================================
echo 切换结果:
echo ==================================================
echo 之前: %OSTYPE%
echo 之后: %NEW_OSTYPE%
echo.

if "%NEW_OSTYPE%"==" OSType: windows" (
    echo SUCCESS: 已成功切换到 Windows Container 模式！
) else (
    echo WARNING: 自动切换可能未成功，请手动切换：
    echo 1. 右键点击任务栏中的 Docker 图标
    echo 2. 选择 "Switch to Windows containers..."
    echo 3. 等待切换完成
)

echo.
echo 验证命令: docker info ^| findstr OSType
echo 应显示: OSType: windows
echo.
pause
