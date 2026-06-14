[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$ProxyUrl = "http://localhost:8080/v1/messages"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    Claude Code (DeepSeek Proxy)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Proxy: http://localhost:8080" -ForegroundColor Gray
Write-Host "Model: deepseek-v4-pro (联网版)" -ForegroundColor Gray
Write-Host "Type 'exit' or 'quit' to quit" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    Write-Host -NoNewline "You: " -ForegroundColor Yellow
    $UserInput = Read-Host

    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        continue
    }

    if ($UserInput.ToLower() -eq "exit" -or $UserInput.ToLower() -eq "quit") {
        Write-Host "`nGoodbye!" -ForegroundColor Cyan
        break
    }

    Write-Host ""
    Write-Host "Claude:" -ForegroundColor Green

    $RequestBody = @{
        messages = @(
            @{
                role = "user"
                content = $UserInput
            }
        )
        max_tokens = 1000
        temperature = 0.7
    } | ConvertTo-Json -Depth 10

    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)
        $Response = Invoke-WebRequest -Uri $ProxyUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $Bytes -UseBasicParsing

        if ($Response.StatusCode -eq 200) {
            $ResponseJson = $Response.Content | ConvertFrom-Json
            $Reply = $ResponseJson.content[0].text
            Write-Host $Reply -ForegroundColor White
        } else {
            Write-Host "HTTP Error: $($Response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}
