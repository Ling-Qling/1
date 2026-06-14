[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-Host "Testing proxy..."

$msg = @(@{role="user";content="Hello"})
$body = @{
    messages = $msg
    max_tokens = 50
    temperature = 0.7
} | ConvertTo-Json -Compress -Depth 10

Write-Host "Request body: $body"

try {
    $Response = Invoke-WebRequest -Uri "http://localhost:8080/v1/messages" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
    
    Write-Host "Status: $($Response.StatusCode)"
    
    $JsonResponse = [System.Text.Encoding]::UTF8.GetString($Response.Content) | ConvertFrom-Json
    Write-Host "Reply: $($JsonResponse.content[0].text)"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
