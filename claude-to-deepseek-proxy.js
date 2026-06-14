const http = require('http');
const https = require('https');

const PORT = 8080;
const DEEPSEEK_URL = 'https://api.deepseek.com/v1/chat/completions';
const API_KEY = process.env.ANTHROPIC_AUTH_TOKEN || 'sk-c838383c178947739b71a54897c0894f';

const server = http.createServer((req, res) => {
    // Handle /v1/models (GET)
    if (req.method === 'GET' && req.url.startsWith('/v1/models')) {
        console.log(`[${new Date().toLocaleString()}] GET ${req.url}`);
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            data: [
                { id: 'claude-3-5-sonnet-latest', type: 'model', display_name: 'Claude 3.5 Sonnet (DeepSeek Proxy)' },
                { id: 'claude-opus-4-6', type: 'model', display_name: 'Claude Opus 4 (DeepSeek Proxy)' },
                { id: 'claude-sonnet-4-6', type: 'model', display_name: 'Claude Sonnet 4 (DeepSeek Proxy)' },
            ]
        }));
        return;
    }

    // Handle OPTIONS (CORS)
    if (req.method === 'OPTIONS') {
        res.writeHead(200, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-key, anthropic-version'
        });
        res.end();
        return;
    }

    let body = '';
    req.setEncoding('utf8');

    req.on('data', (chunk) => {
        body += chunk;
    });

    req.on('end', () => {
        console.log(`[${new Date().toLocaleString()}] Request: ${req.method} ${req.url}`);
        console.log(`[DEBUG] Request body: ${body}`);
        
        try {
            const anthropicRequest = JSON.parse(body);
            const userMessages = anthropicRequest.messages || [];
            
            console.log(`[DEBUG] User messages count: ${userMessages.length}`);
            
            const deepseekMessages = userMessages.map(msg => {
                let content = '';
                if (typeof msg.content === 'string') {
                    content = msg.content;
                } else if (Array.isArray(msg.content) && msg.content[0]) {
                    content = msg.content[0].text || msg.content[0].content || JSON.stringify(msg.content);
                } else if (typeof msg.content === 'object') {
                    content = msg.content.text || msg.content.content || JSON.stringify(msg.content);
                }
                return {
                    role: msg.role,
                    content: content
                };
            });
            
            const deepseekRequest = {
                model: "deepseek-v4-pro",
                messages: deepseekMessages,
                max_tokens: anthropicRequest.max_tokens || 1000,
                temperature: anthropicRequest.temperature || 0.7,
                stream: false
            };
            
            console.log(`[DEBUG] DeepSeek request: ${JSON.stringify(deepseekRequest).substring(0, 500)}`);
            
            const deepseekOptions = {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${API_KEY}`,
                    'Content-Type': 'application/json; charset=utf-8'
                }
            };
            
            const deepseekReq = https.request(DEEPSEEK_URL, deepseekOptions, (deepseekRes) => {
                let deepseekBody = Buffer.from('');
                
                deepseekRes.on('data', (chunk) => {
                    if (Buffer.isBuffer(chunk)) {
                        deepseekBody = Buffer.concat([deepseekBody, chunk]);
                    } else {
                        deepseekBody = Buffer.concat([deepseekBody, Buffer.from(chunk, 'binary')]);
                    }
                });
                
                deepseekRes.on('end', () => {
                    try {
                        const responseStr = deepseekBody.toString('utf8');
                        const deepseekResponse = JSON.parse(responseStr);
                        
                        if (deepseekResponse.error) {
                            console.error(`[ERROR] DeepSeek API error: ${JSON.stringify(deepseekResponse.error)}`);
                            res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
                            res.end(JSON.stringify({ error: deepseekResponse.error.message }));
                            return;
                        }
                        
                        const choice = deepseekResponse.choices?.[0];
                        let assistantReply = '';
                        
                        if (choice) {
                            assistantReply = choice.message?.content || 
                                            choice.message?.reasoning_content || 
                                            choice.text || 
                                            choice.reasoning_content || '';
                        }
                        
                        console.log(`[DEBUG] Assistant reply: "${assistantReply.substring(0, 200)}..."`);
                        
                        const anthropicResponse = {
                            id: `msg_${Date.now()}`,
                            type: 'message',
                            role: 'assistant',
                            content: [{
                                type: 'text',
                                text: assistantReply
                            }],
                            model: 'claude-3-5-sonnet-latest',
                            stop_reason: choice?.finish_reason || 'end_turn',
                            usage: {
                                input_tokens: deepseekResponse.usage?.prompt_tokens || 0,
                                output_tokens: deepseekResponse.usage?.completion_tokens || 0
                            }
                        };
                        
                        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
                        res.end(JSON.stringify(anthropicResponse));
                        
                    } catch (error) {
                        console.error('Error parsing DeepSeek response:', error.message);
                        console.error('Raw response:', deepseekBody.toString('utf8').substring(0, 200));
                        res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
                        res.end(JSON.stringify({ error: 'Failed to parse response' }));
                    }
                });
            });
            
            deepseekReq.on('error', (error) => {
                console.error('Error calling DeepSeek API:', error);
                res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
                res.end(JSON.stringify({ error: 'Failed to call DeepSeek API' }));
            });
            
            const requestBody = JSON.stringify(deepseekRequest);
            deepseekReq.write(requestBody, 'utf8');
            deepseekReq.end();
            
        } catch (error) {
            console.error('Error parsing request:', error.message);
            console.error('Raw request:', body);
            res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
            res.end(JSON.stringify({ error: `Invalid request: ${error.message}` }));
        }
    });
});

server.listen(PORT, () => {
    console.log('='.repeat(60));
    console.log(`Claude to DeepSeek Proxy Server`);
    console.log(`Running on: http://localhost:${PORT}`);
    console.log(`DeepSeek API Key: ${API_KEY.substring(0, 10)}...`);
    console.log(`Model: deepseek-v4-pro (联网版)`);
    console.log('='.repeat(60));
});
