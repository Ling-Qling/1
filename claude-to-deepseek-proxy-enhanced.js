const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = 8080;
const DEEPSEEK_URL = 'https://api.deepseek.com/v1/chat/completions';
const API_KEY = 'sk-5914212d4d60436ab0e8de1be3f38a0c';

const server = http.createServer((req, res) => {
    let body = '';
    req.setEncoding('utf8');
    
    req.on('data', (chunk) => {
        body += chunk;
    });
    
    req.on('end', () => {
        console.log(`[${new Date().toLocaleString()}] Request: ${req.method} ${req.url}`);
        
        if (req.url === '/v1/messages') {
            handleChatRequest(req, res, body);
        } else if (req.url === '/v1/execute') {
            handleExecuteRequest(req, res, body);
        } else if (req.url === '/v1/files') {
            handleFileRequest(req, res, body);
        } else {
            res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
            res.end(JSON.stringify({ error: 'Not found' }));
        }
    });
});

function handleChatRequest(req, res, body) {
    try {
        const anthropicRequest = JSON.parse(body);
        const userMessages = anthropicRequest.messages || [];
        
        const deepseekMessages = userMessages.map(msg => {
            let content = '';
            if (typeof msg.content === 'string') {
                content = msg.content;
            } else if (Array.isArray(msg.content) && msg.content[0]) {
                content = msg.content[0].text || msg.content[0].content || JSON.stringify(msg.content);
            } else if (typeof msg.content === 'object') {
                content = msg.content.text || msg.content.content || JSON.stringify(msg.content);
            }
            return { role: msg.role, content: content };
        });
        
        const deepseekRequest = {
            model: "deepseek-v4-flash",
            messages: deepseekMessages,
            max_tokens: anthropicRequest.max_tokens || 1000,
            temperature: anthropicRequest.temperature || 0.7,
            stream: false
        };
        
        const options = {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${API_KEY}`
            }
        };
        
        const request = https.request(DEEPSEEK_URL, options, (response) => {
            let data = '';
            response.on('data', (chunk) => { data += chunk; });
            response.on('end', () => {
                try {
                    const result = JSON.parse(data);
                    const assistantReply = result.choices?.[0]?.message?.content || result.reasoning_content || '';
                    console.log(`[DEBUG] Assistant reply (first 200 chars): ${assistantReply.substring(0, 200)}...`);
                    
                    const anthropicResponse = {
                        id: `msg_${Date.now()}`,
                        type: 'message',
                        role: 'assistant',
                        content: [{ type: 'text', text: assistantReply }],
                        model: 'claude-3-5-sonnet-latest',
                        stop_reason: 'stop',
                        usage: { input_tokens: 0, output_tokens: 0 }
                    };
                    
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify(anthropicResponse));
                } catch (error) {
                    console.error('Error parsing DeepSeek response:', error.message);
                    res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ error: 'Failed to parse response' }));
                }
            });
        });
        
        request.on('error', (error) => {
            console.error('Error sending request to DeepSeek:', error.message);
            res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
            res.end(JSON.stringify({ error: `DeepSeek API error: ${error.message}` }));
        });
        
        request.write(JSON.stringify(deepseekRequest));
        request.end();
        
    } catch (error) {
        console.error('Error parsing request:', error.message);
        res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: `Invalid request: ${error.message}` }));
    }
}

function handleExecuteRequest(req, res, body) {
    try {
        const request = JSON.parse(body);
        const code = request.code;
        const language = request.language || 'python';
        
        console.log(`[EXECUTE] ${language}: ${code.substring(0, 100)}...`);
        
        if (language === 'python') {
            exec(`python -c "${code.replace(/"/g, '\\"')}"`, (error, stdout, stderr) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: stderr || error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, output: stdout }));
                }
            });
        } else if (language === 'javascript' || language === 'js') {
            exec(`node -e "${code.replace(/"/g, '\\"')}"`, (error, stdout, stderr) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: stderr || error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, output: stdout }));
                }
            });
        } else if (language === 'powershell' || language === 'ps') {
            exec(`powershell.exe -Command "${code.replace(/"/g, '\\"')}"`, (error, stdout, stderr) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: stderr || error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, output: stdout }));
                }
            });
        } else {
            res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
            res.end(JSON.stringify({ success: false, error: `Unsupported language: ${language}` }));
        }
    } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ success: false, error: error.message }));
    }
}

function handleFileRequest(req, res, body) {
    try {
        const request = JSON.parse(body);
        const action = request.action;
        
        if (action === 'read') {
            const filePath = path.join('./', request.path);
            fs.readFile(filePath, 'utf8', (error, data) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, content: data }));
                }
            });
        } else if (action === 'write') {
            const filePath = path.join('./', request.path);
            fs.writeFile(filePath, request.content, 'utf8', (error) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, message: 'File written successfully' }));
                }
            });
        } else if (action === 'list') {
            fs.readdir('./', (error, files) => {
                if (error) {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: false, error: error.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                    res.end(JSON.stringify({ success: true, files: files }));
                }
            });
        } else {
            res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
            res.end(JSON.stringify({ success: false, error: `Unsupported action: ${action}` }));
        }
    } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ success: false, error: error.message }));
    }
}

server.listen(PORT, () => {
    console.log('='.repeat(60));
    console.log(`Claude to DeepSeek Proxy Server (Enhanced)`);
    console.log(`Running on: http://localhost:${PORT}`);
    console.log(`DeepSeek API Key: ${API_KEY.substring(0, 10)}...`);
    console.log(`Model: deepseek-v4-flash`);
    console.log('='.repeat(60));
    console.log('Available endpoints:');
    console.log('  POST /v1/messages    - Chat with AI');
    console.log('  POST /v1/execute     - Execute code (python/js/powershell)');
    console.log('  POST /v1/files       - File operations (read/write/list)');
    console.log('='.repeat(60));
});
