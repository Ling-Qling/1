import os
import uuid
import json
import shutil
import threading
import subprocess
import tempfile
from pathlib import Path
from datetime import timedelta

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.requests import Request
from jinja2 import Environment, FileSystemLoader

# ------------------ 配置 ------------------
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB
ALLOWED_EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv"}
UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

# faster-whisper 配置
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")        # tiny / base / small / medium / large-v3
WHISPER_DEVICE = os.getenv("WHISPER_DEVICE", "cpu")       # cpu / cuda
WHISPER_COMPUTE = os.getenv("WHISPER_COMPUTE", "int8")    # int8 / float16 / int8_float16

# HuggingFace 镜像（国内用户加速下载）
_HF_MIRROR = os.getenv("HF_ENDPOINT", "https://hf-mirror.com")
os.environ.setdefault("HF_ENDPOINT", _HF_MIRROR)

# ------------------ 生命周期 ------------------

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时清理旧的临时文件"""
    for item in UPLOAD_DIR.iterdir():
        try:
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
        except Exception:
            pass
    yield

app = FastAPI(title="Video Translator", version="1.0.0", lifespan=lifespan)
app.mount("/static", StaticFiles(directory="static"), name="static")
jinja_env = Environment(loader=FileSystemLoader("templates"))

tasks: dict = {}
tasks_lock = threading.Lock()
_whisper_model = None
_whisper_model_lock = threading.Lock()

# ------------------ 工具函数 ------------------

def seconds_to_srt_time(seconds: float) -> str:
    """将秒数转换为 SRT 时间戳格式 HH:MM:SS,mmm"""
    td = timedelta(seconds=seconds)
    total_seconds = int(td.total_seconds())
    hours = total_seconds // 3600
    minutes = (total_seconds % 3600) // 60
    secs = total_seconds % 60
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def update_task(task_id: str, **kwargs):
    """线程安全地更新任务状态"""
    with tasks_lock:
        if task_id in tasks:
            tasks[task_id].update(kwargs)


def cleanup_temp_files(*paths: Path):
    """清理临时文件"""
    for p in paths:
        try:
            if p.exists():
                if p.is_dir():
                    shutil.rmtree(p)
                else:
                    p.unlink()
        except Exception:
            pass


def find_ffmpeg() -> Path | None:
    """查找系统中的 ffmpeg，返回完整路径或 None"""
    # 1) 优先检查 PATH 中的 ffmpeg
    ffmpeg_name = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"
    for p in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(p) / ffmpeg_name
        if candidate.is_file():
            return candidate

    # 2) 搜索常见安装位置
    common_dirs = [
        Path(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet"),
        Path(os.environ.get("ProgramFiles", "C:\\Program Files"), "FFmpeg"),
        Path(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "FFmpeg"),
        Path("C:\\ffmpeg"),
    ]
    for base in common_dirs:
        if not base.exists():
            continue
        for root, _, files in os.walk(base):
            if ffmpeg_name in files:
                return Path(root) / ffmpeg_name

    # 3) WPS 自带 ffmpeg（常见于 APPDATA）
    wps_base = Path(os.environ.get("APPDATA", "")) / "kingsoft" / "wps" / "addons" / "pool"
    if wps_base.exists():
        for root, _, files in os.walk(wps_base):
            if ffmpeg_name in files:
                return Path(root) / ffmpeg_name

    return None


FFMPEG_PATH = find_ffmpeg()


def check_ffmpeg() -> bool:
    """检查 ffmpeg 是否可用"""
    if FFMPEG_PATH:
        return True
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


# ------------------ 语音识别 ------------------

def get_faster_whisper_model():
    """懒加载 faster-whisper 模型（全局单例）"""
    global _whisper_model
    if _whisper_model is None:
        with _whisper_model_lock:
            if _whisper_model is None:
                from faster_whisper import WhisperModel
                _whisper_model = WhisperModel(
                    WHISPER_MODEL, device=WHISPER_DEVICE, compute_type=WHISPER_COMPUTE
                )
    return _whisper_model


def transcribe_faster_whisper(audio_path: Path, task_id: str) -> list:
    """使用本地 faster-whisper 进行语音识别"""
    update_task(task_id, step="transcribing",
                message=f"正在语音识别 (faster-whisper/{WHISPER_MODEL})...", progress=32)

    model = get_faster_whisper_model()
    segments_out, info = model.transcribe(str(audio_path), beam_size=5)

    # 将 faster-whisper 的 segment 对象转为统一格式 (start, end, text)
    segments = []
    for seg in segments_out:
        segments.append(type("Segment", (), {
            "start": seg.start,
            "end": seg.end,
            "text": seg.text,
        }))

    update_task(task_id, step="transcribing",
                message=f"识别完成 (语言: {info.language}, 概率: {info.language_probability:.0%})",
                progress=48)

    return segments


def transcribe_openai(audio_path: Path, task_id: str) -> list:
    """使用 OpenAI Whisper API 进行语音识别（降级方案）"""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("未设置 OPENAI_API_KEY 环境变量")

    from openai import OpenAI
    client = OpenAI(api_key=api_key)

    update_task(task_id, step="transcribing",
                message="正在语音识别 (OpenAI Whisper API)...", progress=32)

    with open(audio_path, "rb") as f:
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            response_format="verbose_json",
            timestamp_granularities=["segment"],
        )

    segments = []
    for seg in transcript.segments:
        segments.append(type("Segment", (), {
            "start": seg.start,
            "end": seg.end,
            "text": seg.text,
        }))

    return segments


# ------------------ 字幕生成核心流程 ------------------

def process_video(task_id: str, video_path: Path):
    """后台处理视频的完整流程"""
    try:
        # --- 步骤 1: 提取音频 ---
        update_task(task_id, step="extracting", message="正在提取音频...", progress=10)
        audio_path = video_path.with_suffix(".mp3")
        ffmpeg_cmd = str(FFMPEG_PATH) if FFMPEG_PATH else "ffmpeg"
        cmd = [
            ffmpeg_cmd, "-y", "-i", str(video_path),
            "-vn", "-ar", "16000", "-ac", "1", "-b:a", "64k",
            str(audio_path)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            error_msg = result.stderr.strip()[-200:] if result.stderr else "ffmpeg 执行失败"
            update_task(task_id, step="error", message=f"音频提取失败: {error_msg}")
            cleanup_temp_files(video_path, audio_path)
            return

        update_task(task_id, step="extracting", message="音频提取完成", progress=25)

        # --- 步骤 2: 语音识别 (faster-whisper 优先, OpenAI API 备用) ---
        update_task(task_id, step="transcribing", message="正在加载语音识别模型...", progress=30)

        try:
            segments = transcribe_faster_whisper(audio_path, task_id)
        except Exception as e:
            # faster-whisper 失败, 尝试 OpenAI API 降级
            update_task(task_id, step="transcribing",
                        message=f"本地模型失败 ({e})，尝试 OpenAI API...", progress=30)
            try:
                segments = transcribe_openai(audio_path, task_id)
            except Exception as e2:
                update_task(task_id, step="error",
                            message=f"语音识别失败。本地模型: {e} | OpenAI API: {e2}")
                cleanup_temp_files(video_path, audio_path)
                return

        if not segments:
            update_task(task_id, step="error", message="语音识别未返回任何文本段落")
            cleanup_temp_files(video_path, audio_path)
            return

        update_task(task_id, step="transcribing", message=f"语音识别完成，共 {len(segments)} 段", progress=50)

        # --- 步骤 3: 翻译为中文 ---
        update_task(task_id, step="translating", message="正在翻译为中文...", progress=55)

        try:
            from deep_translator import GoogleTranslator
            translator = GoogleTranslator(source="auto", target="zh-CN")
        except ImportError:
            update_task(task_id, step="error", message="翻译库未安装，请运行: pip install deep-translator")
            cleanup_temp_files(video_path, audio_path)
            return

        translated_segments = []
        total_segments = len(segments)

        for i, seg in enumerate(segments):
            text = seg.text.strip()
            if not text:
                translated_segments.append((seg.start, seg.end, ""))
                continue

            try:
                translated = translator.translate(text)
            except Exception:
                # 降级: 保留原文 + [翻译失败]
                translated = f"{text} [翻译失败]"

            translated_segments.append((seg.start, seg.end, translated))

            # 更新进度 (55% ~ 80%)
            pct = 55 + int((i + 1) / total_segments * 25)
            update_task(task_id, step="translating",
                        message=f"正在翻译... ({i + 1}/{total_segments})", progress=pct)

        update_task(task_id, step="translating", message="翻译完成", progress=80)

        # --- 步骤 4: 生成 SRT 文件 ---
        update_task(task_id, step="generating", message="正在生成字幕文件...", progress=85)

        srt_lines = []
        counter = 1
        for start, end, text in translated_segments:
            if not text:
                continue
            srt_lines.append(str(counter))
            srt_lines.append(f"{seconds_to_srt_time(start)} --> {seconds_to_srt_time(end)}")
            srt_lines.append(text)
            srt_lines.append("")  # 空行分隔
            counter += 1

        srt_content = "\n".join(srt_lines)
        output_dir = UPLOAD_DIR / task_id
        output_dir.mkdir(exist_ok=True)
        srt_path = output_dir / "subtitles.srt"
        srt_path.write_text(srt_content, encoding="utf-8")

        # 清理临时文件
        cleanup_temp_files(video_path, audio_path)

        update_task(task_id, step="completed", message="字幕生成完成！",
                    progress=100, srt_path=str(srt_path),
                    filename=video_path.stem + ".srt")

    except Exception as e:
        update_task(task_id, step="error", message=f"处理出错: {str(e)}")
        try:
            cleanup_temp_files(video_path, video_path.with_suffix(".mp3"))
        except Exception:
            pass


# ------------------ API 路由 ------------------

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    template = jinja_env.get_template("index.html")
    return HTMLResponse(template.render(request=request))


@app.post("/api/process")
async def api_process(file: UploadFile = File(...)):
    # 验证文件扩展名
    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            400, f"不支持的文件格式。仅支持: {', '.join(ALLOWED_EXTENSIONS)}"
        )

    # 验证 ffmpeg
    if not check_ffmpeg():
        raise HTTPException(500, "服务器未安装 ffmpeg，请联系管理员")

    # 读取并保存文件
    task_id = str(uuid.uuid4())
    safe_name = f"{task_id}{ext}"
    video_path = UPLOAD_DIR / safe_name

    # 流式读取以支持大文件，并检查大小
    total_size = 0
    with open(video_path, "wb") as buffer:
        while chunk := await file.read(8 * 1024 * 1024):  # 8MB chunks
            total_size += len(chunk)
            if total_size > MAX_FILE_SIZE:
                buffer.close()
                cleanup_temp_files(video_path)
                raise HTTPException(413, f"文件过大，最大支持 {MAX_FILE_SIZE // 1024 // 1024}MB")
            buffer.write(chunk)

    # 初始化任务状态
    with tasks_lock:
        tasks[task_id] = {
            "step": "uploading",
            "message": "文件上传完成，准备处理...",
            "progress": 0,
            "filename": file.filename,
        }

    # 启动后台线程处理
    thread = threading.Thread(target=process_video, args=(task_id, video_path), daemon=True)
    thread.start()

    return {"task_id": task_id, "filename": file.filename}


@app.get("/api/status/{task_id}")
async def api_status(task_id: str):
    with tasks_lock:
        task = tasks.get(task_id)
    if not task:
        raise HTTPException(404, "任务不存在或已过期")

    return {
        "step": task.get("step"),
        "message": task.get("message"),
        "progress": task.get("progress", 0),
        "filename": task.get("filename"),
    }


@app.get("/api/download/{task_id}")
async def api_download(task_id: str):
    with tasks_lock:
        task = tasks.get(task_id)

    if not task or task.get("step") != "completed":
        raise HTTPException(404, "字幕文件不存在或尚未处理完成")

    srt_path = task.get("srt_path")
    fn = task.get("filename", "subtitles.srt")
    if not srt_path or not os.path.exists(srt_path):
        raise HTTPException(404, "字幕文件已被清理")

    return FileResponse(
        srt_path,
        media_type="text/plain; charset=utf-8",
        filename=fn,
        headers={"Content-Disposition": f'attachment; filename="{fn}"'}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
