const readline = require('readline');
const http = require('http');

const API_KEY = 'sk-c838383c178947739b71a54897c0894f';
const PROXY_URL = 'http://localhost:8080/v1/messages';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'You: ',
    terminal: true
});

let messages = [];

console.log('\n' + '='.repeat(50));
console.log('    Claude Code (DeepSeek Proxy)');
console.log('='.repeat(50));
console.log('Proxy: http://localhost:8080');
console.log('Model: deepseek-v4-flash');
console.log('Type "exit" or "quit" to quit');
console.log('='.repeat(50) + '\n');

rl.prompt();

rl.on('line', (input) => {
    const userInput = input.trim();
    
    if (userInput.toLowerCase() === 'exit' || userInput.toLowerCase() === 'quit') {
        console.log('\nGoodbye!');
        rl.close();
        return;
    }
    
    if (!userInput) {
        rl.prompt();
        return;
    }
    
    messages.push({ role: 'user', content: userInput });
    
    console.log('\nClaude:');
    
    const body = JSON.stringify({
        messages: messages,
        max_tokens: 1000,
        temperature: 0.7
    });
    
    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': Buffer.byteLength(body, 'utf8')
        }
    };
    
    const req = http.request(PROXY_URL, options, (res) => {
        let data = '';
        res.setEncoding('utf8');
        
        res.on('data', (chunk) => {
            data += chunk;
        });
        
        res.on('end', () => {
            try {
                const response = JSON.parse(data);
                const reply = response.content?.[0]?.text || '';
                console.log(reply);
                messages.push({ role: 'assistant', content: reply });
            } catch (error) {
                console.log('Error:', error.message);
            }
            console.log();
            rl.prompt();
        });
    });
    
    req.on('error', (error) => {
        console.log('Error:', error.message);
        console.log();
        rl.prompt();
    });
    
    req.write(body, 'utf8');
    req.end();
});

rl.on('close', () => {
    process.exit(0);
});
