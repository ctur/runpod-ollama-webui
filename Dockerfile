# =============================================================================
# RunPod Pod Template: Ollama + Open WebUI
# Compute Type: NVIDIA GPU
#
# BUILD: docker build --platform linux/amd64 -t your-registry/runpod-ollama-webui:latest .
# PUSH:  docker push your-registry/runpod-ollama-webui:latest
#
# BASE IMAGE OPTIONS (uncomment ONE):
#
# Option A (recommended): RunPod's official PyTorch base image.
#   Includes CUDA 12.8.1, Python 3, pip, SSH, JupyterLab, common tools.
#   Much smaller Dockerfile, fewer things to configure.
#
# Option B: Raw NVIDIA CUDA image (lighter, but needs manual setup).
#   You must restore Ubuntu repos since NVIDIA strips them.
#   Uncomment the "Option B" block below and comment out Option A.
# =============================================================================

# ── Option A: RunPod base image (recommended) ──
FROM --platform=linux/amd64 runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

# ── Option B: Raw NVIDIA CUDA image (uncomment if you prefer minimal) ──
# FROM --platform=linux/amd64 nvidia/cuda:12.4.1-runtime-ubuntu22.04
# # Restore Ubuntu repos (NVIDIA images strip them)
# RUN echo "deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" > /etc/apt/sources.list && \
#     echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
#     echo "deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse" >> /etc/apt/sources.list
# # If using Option B, also add to the apt-get install below:
# #   python3 python3-pip python3-venv

LABEL maintainer="runpod-ollama-webui"
LABEL description="Ollama LLM server + Open WebUI on RunPod GPU pods"

# ── Prevent interactive prompts during build ──
ENV DEBIAN_FRONTEND=noninteractive

# ── System dependencies ──
# The RunPod base already has most tools; this adds anything missing.
# If using Option B (raw CUDA), this installs everything from scratch.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    git \
    lsof \
    procps \
    ffmpeg \
    libsm6 \
    libxext6 \
    netcat-openbsd \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# ── Configure SSH for RunPod (skip if using RunPod base — already configured) ──
# RunPod base image has SSH pre-configured via /start.sh.
# This block is a safety net and also needed for Option B.
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A 2>/dev/null || true

# ── Install Ollama ──
RUN curl -fsSL https://ollama.com/install.sh | sh

# ── Install Open WebUI via pip (latest stable) ──
RUN pip install --no-cache-dir --break-system-packages open-webui || \
    pip3 install --no-cache-dir open-webui

# ── Default environment variables ──────────────────────────────────────────
#
# Ollama — server
ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_NUM_PARALLEL=4
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_KEEP_ALIVE=5m
ENV OLLAMA_FLASH_ATTENTION=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Ollama — storage
# Points into /workspace so models persist on RunPod network volume.
# The entrypoint creates these dirs and symlinks /root/.ollama → /workspace/ollama
ENV OLLAMA_MODELS=/workspace/ollama/models

# Model to auto-pull on first boot (comma-separated, empty to skip)
ENV OLLAMA_MODEL=llama3.2

# Open WebUI — connection
ENV OLLAMA_BASE_URL=http://127.0.0.1:11434
ENV PORT=8080
ENV ENABLE_OLLAMA_API=True

# Open WebUI — storage
# Points into /workspace so chats/users/uploads persist on network volume.
ENV DATA_DIR=/workspace/open-webui

# Open WebUI — auth & general
ENV WEBUI_SECRET_KEY=""
ENV ENABLE_SIGNUP=True
ENV DEFAULT_USER_ROLE=pending
ENV DEFAULT_MODELS=""
ENV WEBUI_AUTH=True
ENV ANONYMIZED_TELEMETRY=false
ENV DO_NOT_TRACK=true

# RunPod specific
ENV RUNPOD=true

# ── Copy entrypoint ──
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Expose ports ──
# 8080  = Open WebUI (main HTTP port for RunPod proxy)
# 11434 = Ollama API
# 22    = SSH (for RunPod SSH/SCP/IDE access)
EXPOSE 8080 11434 22

ENTRYPOINT ["/entrypoint.sh"]
