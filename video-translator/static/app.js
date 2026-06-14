// ------------------ DOM 元素 ------------------
const uploadZone = document.getElementById("upload-zone");
const fileInput = document.getElementById("file-input");
const fileInfo = document.getElementById("file-info");
const fileName = document.getElementById("file-name");
const fileSize = document.getElementById("file-size");
const btnStart = document.getElementById("btn-start");
const btnReselect = document.getElementById("btn-reselect");
const btnDownload = document.getElementById("btn-download");
const btnRestart = document.getElementById("btn-restart");
const btnRetry = document.getElementById("btn-retry");

const uploadSection = document.getElementById("upload-section");
const statusSection = document.getElementById("status-section");
const resultSection = document.getElementById("result-section");
const errorSection = document.getElementById("error-section");

const progressBar = document.getElementById("progress-bar");
const progressText = document.getElementById("progress-text");
const resultFilename = document.getElementById("result-filename");
const errorText = document.getElementById("error-text");
const stepsContainer = document.getElementById("steps");

let selectedFile = null;
let taskId = null;
let pollTimer = null;

// ------------------ 文件选择 ------------------
uploadZone.addEventListener("click", () => fileInput.click());
uploadZone.addEventListener("dragover", (e) => {
    e.preventDefault();
    uploadZone.classList.add("drag-over");
});
uploadZone.addEventListener("dragleave", () => {
    uploadZone.classList.remove("drag-over");
});
uploadZone.addEventListener("drop", (e) => {
    e.preventDefault();
    uploadZone.classList.remove("drag-over");
    const files = e.dataTransfer.files;
    if (files.length > 0) handleFile(files[0]);
});
fileInput.addEventListener("change", () => {
    if (fileInput.files.length > 0) handleFile(fileInput.files[0]);
});

btnReselect.addEventListener("click", () => {
    selectedFile = null;
    fileInput.value = "";
    fileInfo.classList.add("hidden");
    uploadZone.classList.remove("hidden");
    btnStart.disabled = true;
});

btnRestart.addEventListener("click", resetAll);
btnRetry.addEventListener("click", resetAll);

function handleFile(file) {
    const ext = file.name.split(".").pop().toLowerCase();
    const allowed = ["mp4", "avi", "mov", "mkv"];
    if (!allowed.includes(ext)) {
        alert(`不支持的文件格式。仅支持: ${allowed.join(", ")}`);
        return;
    }
    if (file.size > 500 * 1024 * 1024) {
        alert("文件过大，最大支持 500MB");
        return;
    }

    selectedFile = file;
    fileName.textContent = file.name;
    fileSize.textContent = formatSize(file.size);
    uploadZone.classList.add("hidden");
    fileInfo.classList.remove("hidden");
    btnStart.disabled = false;
}

function formatSize(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB";
    return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
}

// ------------------ 开始处理 ------------------
btnStart.addEventListener("click", startProcess);

async function startProcess() {
    if (!selectedFile) return;

    // 切换到状态界面
    uploadSection.classList.add("hidden");
    statusSection.classList.remove("hidden");
    resultSection.classList.add("hidden");
    errorSection.classList.add("hidden");
    progressBar.style.width = "0%";
    progressText.textContent = "正在上传文件...";
    resetStepIcons();

    try {
        const formData = new FormData();
        formData.append("file", selectedFile);

        const res = await fetch("/api/process", {
            method: "POST",
            body: formData,
        });

        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.detail || `服务器错误 (${res.status})`);
        }

        const data = await res.json();
        taskId = data.task_id;

        // 开始轮询状态
        pollTimer = setInterval(pollStatus, 1000);
    } catch (err) {
        showError(err.message);
    }
}

// ------------------ 轮询状态 ------------------
async function pollStatus() {
    try {
        const res = await fetch(`/api/status/${taskId}`);
        if (!res.ok) throw new Error("获取状态失败");

        const data = await res.json();

        progressBar.style.width = data.progress + "%";
        progressText.textContent = data.message;
        updateStepIcons(data.step);

        if (data.step === "completed") {
            clearInterval(pollTimer);
            pollTimer = null;

            statusSection.classList.add("hidden");
            resultSection.classList.remove("hidden");
            resultFilename.textContent = data.filename || "subtitles.srt";
            btnDownload.href = `/api/download/${taskId}`;
        }

        if (data.step === "error") {
            clearInterval(pollTimer);
            pollTimer = null;
            showError(data.message);
        }
    } catch (err) {
        clearInterval(pollTimer);
        pollTimer = null;
        showError(err.message);
    }
}

// ------------------ 步骤图标更新 ------------------
const stepEls = {
    extracting: stepsContainer.querySelector('[data-step="extracting"]'),
    transcribing: stepsContainer.querySelector('[data-step="transcribing"]'),
    translating: stepsContainer.querySelector('[data-step="translating"]'),
    generating: stepsContainer.querySelector('[data-step="generating"]'),
};

const stepOrder = ["extracting", "transcribing", "translating", "generating"];

function updateStepIcons(currentStep) {
    const currentIdx = stepOrder.indexOf(currentStep);
    stepOrder.forEach((key, idx) => {
        const el = stepEls[key];
        el.classList.remove("active", "done");
        if (idx < currentIdx) el.classList.add("done");
        else if (idx === currentIdx && currentStep !== "completed" && currentStep !== "error") el.classList.add("active");
    });
}

function resetStepIcons() {
    Object.values(stepEls).forEach(el => el.classList.remove("active", "done"));
}

// ------------------ 错误 / 重置 ------------------
function showError(msg) {
    statusSection.classList.add("hidden");
    resultSection.classList.add("hidden");
    errorSection.classList.remove("hidden");
    uploadSection.classList.add("hidden");
    errorText.textContent = msg;
}

function resetAll() {
    clearInterval(pollTimer);
    pollTimer = null;
    taskId = null;
    selectedFile = null;
    fileInput.value = "";

    uploadSection.classList.remove("hidden");
    statusSection.classList.add("hidden");
    resultSection.classList.add("hidden");
    errorSection.classList.add("hidden");
    uploadZone.classList.remove("hidden");
    fileInfo.classList.add("hidden");
    btnStart.disabled = true;
    progressBar.style.width = "0%";
    resetStepIcons();
}
