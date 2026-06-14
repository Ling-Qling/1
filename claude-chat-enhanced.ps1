[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$ProxyUrl = "http://localhost:8080/v1/messages"
$ExecuteUrl = "http://localhost:8080/v1/execute"
$FilesUrl = "http://localhost:8080/v1/files"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    Claude Code (DeepSeek Proxy) - Enhanced" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Proxy: http://localhost:8080" -ForegroundColor Gray
Write-Host "Model: deepseek-v4-flash" -ForegroundColor Gray
Write-Host "Commands:" -ForegroundColor Gray
Write-Host "  /code [python|js|ps] <code>  - Execute code" -ForegroundColor Gray
Write-Host "  /read <file>                  - Read file content" -ForegroundColor Gray
Write-Host "  /write <file> <content>       - Write to file" -ForegroundColor Gray
Write-Host "  /list                         - List files in current directory" -ForegroundColor Gray
Write-Host "  /exit or /quit                - Exit" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    Write-Host -NoNewline "You: " -ForegroundColor Yellow
    $UserInput = Read-Host

    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        continue
    }

    if ($UserInput.ToLower() -eq "exit" -or $UserInput.ToLower() -eq "quit" -or $UserInput.ToLower() -eq "/exit" -or $UserInput.ToLower() -eq "/quit") {
        Write-Host "`nGoodbye!" -ForegroundColor Cyan
        break
    }

    if ($UserInput.StartsWith("/code ")) {
        $parts = $UserInput.Substring(6).Split(" ", 2)
        $language = $parts[0].ToLower()
        $code = $parts[1]

        Write-Host ""
        Write-Host "Claude: Executing $language code..." -ForegroundColor Green

        $RequestBody = @{
            language = $language
            code = $code
        } | ConvertTo-Json -Depth 10

        try {
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)
            $Response = Invoke-WebRequest -Uri $ExecuteUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $Bytes -UseBasicParsing

            if ($Response.StatusCode -eq 200) {
                $ResponseJson = $Response.Content | ConvertFrom-Json
                if ($ResponseJson.success) {
                    Write-Host "Output:" -ForegroundColor Cyan
                    Write-Host $ResponseJson.output -ForegroundColor White
                } else {
                    Write-Host "Error: $($ResponseJson.error)" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        continue
    }

    if ($UserInput.StartsWith("/read ")) {
        $filePath = $UserInput.Substring(6)

        Write-Host ""
        Write-Host "Claude: Reading file: $filePath" -ForegroundColor Green

        $RequestBody = @{
            action = "read"
            path = $filePath
        } | ConvertTo-Json -Depth 10

        try {
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)
            $Response = Invoke-WebRequest -Uri $FilesUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $Bytes -UseBasicParsing

            if ($Response.StatusCode -eq 200) {
                $ResponseJson = $Response.Content | ConvertFrom-Json
                if ($ResponseJson.success) {
                    Write-Host "Content:" -ForegroundColor Cyan
                    Write-Host $ResponseJson.content -ForegroundColor White
                } else {
                    Write-Host "Error: $($ResponseJson.error)" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        continue
    }

    if ($UserInput.StartsWith("/write ")) {
        $parts = $UserInput.Substring(7).Split(" ", 2)
        $filePath = $parts[0]
        $content = $parts[1]

        Write-Host ""
        Write-Host "Claude: Writing to file: $filePath" -ForegroundColor Green

        $RequestBody = @{
            action = "write"
            path = $filePath
            content = $content
        } | ConvertTo-Json -Depth 10

        try {
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)
            $Response = Invoke-WebRequest -Uri $FilesUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $Bytes -UseBasicParsing

            if ($Response.StatusCode -eq 200) {
                $ResponseJson = $Response.Content | ConvertFrom-Json
                if ($ResponseJson.success) {
                    Write-Host $ResponseJson.message -ForegroundColor Green
                } else {
                    Write-Host "Error: $($ResponseJson.error)" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        continue
    }

    if ($UserInput.ToLower() -eq "/list") {
        Write-Host ""
        Write-Host "Claude: Listing files..." -ForegroundColor Green

        $RequestBody = @{
            action = "list"
        } | ConvertTo-Json -Depth 10

        try {
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)
            $Response = Invoke-WebRequest -Uri $FilesUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $Bytes -UseBasicParsing

            if ($Response.StatusCode -eq 200) {
                $ResponseJson = $Response.Content | ConvertFrom-Json
                if ($ResponseJson.success) {
                    Write-Host "Files:" -ForegroundColor Cyan
                    $ResponseJson.files | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                } else {
                    Write-Host "Error: $($ResponseJson.error)" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        continue
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
