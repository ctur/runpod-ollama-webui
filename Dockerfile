# =============================================================================
# RunPod Pod Template: Ollama + Open WebUI
# Base: NVIDIA CUDA for GPU inference
# =============================================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

LABEL maintainer="runpod-ollama-webui"
LABEL description="Ollama LLM server + Open WebUI on RunPod GPU pods"

# ── Prevent interactive prompts during build ──
ENV DEBIAN_FRONTEND=noninteractive

# ── System dependencies ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    git \
    lsof \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    libsm6 \
    libxext6 \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# ── Install Ollama ──
RUN curl -fsSL https://ollama.com/install.sh | sh

# ── Install Open WebUI via pip (latest stable) ──
RUN pip3 install --no-cache-dir open-webui

# ── Default environment variables ──────────────────────────────────────────
#
# Ollama
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MODELS=/root/.ollama/models
ENV OLLAMA_NUM_PARALLEL=4
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_KEEP_ALIVE=5m
ENV OLLAMA_FLASH_ATTENTION=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Model to auto-pull on first boot (set to empty to skip)
ENV OLLAMA_MODEL=llama3.2

# Open WebUI
ENV OLLAMA_BASE_URL=http://127.0.0.1:11434
ENV WEBUI_SECRET_KEY=""
ENV PORT=8080
ENV DATA_DIR=/app/backend/data
ENV ENABLE_SIGNUP=True
ENV DEFAULT_USER_ROLE=pending
ENV DEFAULT_MODELS=""
ENV ENABLE_OLLAMA_API=True
ENV ANONYMIZED_TELEMETRY=false
ENV DO_NOT_TRACK=true
ENV WEBUI_AUTH=True

# RunPod specific
ENV RUNPOD=true

# ── Persistent data directories ──
RUN mkdir -p /root/.ollama /app/backend/data

# ── Copy entrypoint ──
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Expose ports ──
# 8080 = Open WebUI (main HTTP port for RunPod proxy)
# 11434 = Ollama API
EXPOSE 8080 11434

ENTRYPOINT ["/entrypoint.sh"]
