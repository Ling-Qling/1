param(
    [string]$Model = "deepseek-v4-flash",
    [int]$MaxTokens = 500,
    [string]$ApiKey = $env:ANTHROPIC_AUTH_TOKEN
)

if (-not $ApiKey) {
    Write-Host "请设置 ANTHROPIC_AUTH_TOKEN 环境变量" -ForegroundColor Red
    exit 1
}

$headers = @{
    'Authorization' = "Bearer $ApiKey"
    'Content-Type' = 'application/json'
}

$messages = @()

Write-Host "`n=== DeepSeek Chat ===" -ForegroundColor Cyan
Write-Host "Model: $Model" -ForegroundColor Gray
Write-Host "Type 'exit' or 'quit' to quit`n" -ForegroundColor Gray

while ($true) {
    $userInput = Read-Host "You"
    
    if ($userInput -eq "exit" -or $userInput -eq "quit") {
        Write-Host "`nGoodbye!" -ForegroundColor Cyan
        exit 0
    }
    
    if (-not $userInput.Trim()) {
        continue
    }
    
    $messages += @{
        role = "user"
        content = $userInput
    }
    
    $body = @{
        model = $Model
        messages = $messages
        max_tokens = $MaxTokens
    } | ConvertTo-Json -Depth 10
    
    try {
        Write-Host "`nDeepSeek:" -ForegroundColor Green -NoNewline
        
        $response = Invoke-WebRequest -Uri "https://api.deepseek.com/v1/chat/completions" -Headers $headers -Body $body -Method Post -UseBasicParsing
        $result = $response.Content | ConvertFrom-Json
        
        $assistantReply = $result.choices[0].message.content
        Write-Host $assistantReply -ForegroundColor White
        
        $messages += @{
            role = "assistant"
            content = $assistantReply
        }
    }
    catch {
        Write-Host "`nError: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}
