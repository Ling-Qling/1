# Claude Code (DeepSeek) Launcher

$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       Claude Code (DeepSeek) Launcher" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Checking proxy server status..." -ForegroundColor Yellow
$proxyRunning = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

if ($proxyRunning) {
    Write-Host "      Proxy server is running (port 8080)" -ForegroundColor Green
} else {
    Write-Host "[2/3] Starting proxy server..." -ForegroundColor Yellow
    Start-Process -FilePath "node" -ArgumentList "E:\AAA\Claude\claude-to-deepseek-proxy-enhanced.js" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    Write-Host "      Proxy server started" -ForegroundColor Green
}

Write-Host "[3/3] Starting chat window..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500

$chatProcess = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "chcp 65001; powershell.exe -ExecutionPolicy Bypass -File 'E:\AAA\Claude\claude-chat-enhanced.ps1'" -PassThru

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       Claude Code is ready!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tips:" -ForegroundColor Gray
Write-Host "  - Type your message after 'You:' prompt" -ForegroundColor Gray
Write-Host "  - Use /code python <code> to execute code" -ForegroundColor Gray
Write-Host "  - Use /list to list files in current directory" -ForegroundColor Gray
Write-Host "  - Use /read <filename> to read file content" -ForegroundColor Gray
Write-Host "  - Type exit or quit to exit" -ForegroundColor Gray
Write-Host ""
