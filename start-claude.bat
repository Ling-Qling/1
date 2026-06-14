@echo off
chcp 65001 >nul
echo ==================================================
echo          Claude Code (DeepSeek) 启动器
echo ==================================================
echo.

echo [1/3] 检查代理服务器状态...
netstat -ano | findstr ":8080" >nul
if %errorlevel% equ 0 (
    echo         代理服务器已在运行
) else (
    echo [2/3] 启动代理服务器...
    start "Claude Proxy" cmd /c "node claude-to-deepseek-proxy-enhanced.js"
    timeout /t 2 /nobreak >nul
)

echo [3/3] 启动聊天窗口...
powershell.exe -NoExit -Command "chcp 65001; powershell.exe -ExecutionPolicy Bypass -File '%~dp0claude-chat-enhanced.ps1'"

echo.
echo ==================================================
echo          Claude Code 已准备就绪！
echo ==================================================
pause
