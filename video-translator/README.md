# Video Translator — 视频翻译为中文 .srt 字幕

上传视频文件，自动提取音频 → Whisper 语音识别 → 中文翻译 → 生成 SRT 字幕。

## 功能

- 支持 `.mp4` `.avi` `.mov` `.mkv` 视频格式，最大 500MB
- 使用 **OpenAI Whisper API** 进行语音识别（带时间戳）
- 使用 **Google Translate**（免费）翻译为中文
- 实时显示处理进度（提取音频 → 识别 → 翻译 → 生成字幕）
- 处理完成后下载 `.srt` 中文字幕文件

## 前置依赖

### 1. Python 3.9+

```bash
python --version  # 确认 >= 3.9
```

### 2. ffmpeg

**Windows:**
```bash
winget install ffmpeg
# 或从 https://ffmpeg.org/download.html 下载，添加到 PATH
```

**macOS:**
```bash
brew install ffmpeg
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install ffmpeg
```

验证安装:
```bash
ffmpeg -version
```

## 安装 & 运行

### 1. 克隆 / 进入项目目录

```bash
cd video-translator
```

### 2. 创建虚拟环境（推荐）

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

### 3. 安装 Python 依赖

```bash
pip install -r requirements.txt
```

### 4. 设置 OpenAI API Key

申请地址: https://platform.openai.com/api-keys

**Windows (PowerShell):**
```powershell
$env:OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxx"
```

**macOS / Linux (bash/zsh):**
```bash
export OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxx"
```

也可写入 `~/.bashrc` 或 `~/.zshrc` 持久化。

### 5. 启动服务

```bash
python app.py
```

浏览器打开: **http://localhost:8000**

## API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/` | 前端页面 |
| `POST` | `/api/process` | 上传视频并开始处理（multipart/form-data, field: file） |
| `GET` | `/api/status/{task_id}` | 查询处理进度 |
| `GET` | `/api/download/{task_id}` | 下载生成的 .srt 字幕文件 |

## 可选：使用本地 Whisper 模型

如果不想使用 OpenAI API，可安装本地 Whisper：

```bash
pip install openai-whisper
```

然后修改 `app.py` 中的转录部分，用 `whisper` 库替代 OpenAI 调用：

```python
import whisper
model = whisper.load_model("base")  # tiny / base / small / medium / large
result = model.transcribe(str(audio_path), word_timestamps=True)
```

## 可选：使用其他翻译后端

`deep-translator` 支持多种免费后端，修改 `app.py` 中的 translator 即可：

```python
# MyMemory（免费，无需 API Key）
from deep_translator import MyMemoryTranslator
translator = MyMemoryTranslator(source="auto", target="zh-CN")

# 也可用 OpenAI 翻译
from openai import OpenAI
client = OpenAI()
response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": f"Translate to Chinese: {text}"}]
)
```

## 文件结构

```
video-translator/
├── app.py               # FastAPI 后端
├── requirements.txt     # Python 依赖
├── README.md           # 说明文档
├── templates/
│   └── index.html      # 前端页面
├── static/
│   ├── style.css       # 样式
│   └── app.js          # 前端逻辑
└── uploads/            # 临时文件目录（自动创建）
```

## 常见问题

**Q: 上传后提示 "ffmpeg 执行失败"？**
A: 确认 ffmpeg 已安装且在 PATH 中，运行 `ffmpeg -version` 检查。

**Q: 翻译时出现 "Too Many Requests"？**
A: Google Translate 有频率限制。可切换到 MyMemory 翻译（修改 app.py）或使用 OpenAI 翻译。

**Q: 语音识别返回空？**
A: 确认音频轨道正常。某些视频可能没有可识别的语音内容。
