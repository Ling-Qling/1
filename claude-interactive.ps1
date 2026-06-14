$env:ANTHROPIC_API_KEY='sk-c838383c178947739b71a54897c0894f'
$env:ANTHROPIC_BASE_URL='http://localhost:8080/v1'
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'

Write-Host "`n=== Claude Code (DeepSeek 代理) ===" -ForegroundColor Cyan
Write-Host "代理服务器: http://localhost:8080" -ForegroundColor Gray
Write-Host "模型: deepseek-v4-flash" -ForegroundColor Gray
Write-Host "输入 'exit' 或 'quit' 退出`n" -ForegroundColor Gray

while ($true) {
    $userInput = Read-Host "You"
    
    if ($userInput -eq "exit" -or $userInput -eq "quit") {
        Write-Host "`n再见！" -ForegroundColor Cyan
        exit 0
    }
    
    if (-not $userInput.Trim()) {
        continue
    }
    
    Write-Host "`nClaude:" -ForegroundColor Green -NoNewline
    
    $result = $userInput | & node "C:\Users\CC\.trae-cn\extensions\anthropic.claude-code-2.1.89-universal\resources\claude-code\cli.js" --bare --model claude-3-5-sonnet-latest
    
    Write-Host $result -ForegroundColor White
    Write-Host ""
}
