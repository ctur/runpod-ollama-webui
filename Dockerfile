# =============================================================================
# RunPod Pod Template: Ollama + Open WebUI
# Base: NVIDIA CUDA for GPU inference
# Compute Type: NVIDIA GPU
#
# BUILD: docker build --platform linux/amd64 -t your-registry/runpod-ollama-webui:latest .
# PUSH:  docker push your-registry/runpod-ollama-webui:latest
# =============================================================================
FROM --platform=linux/amd64 nvidia/cuda:12.4.1-runtime-ubuntu22.04

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
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# ── Configure SSH for RunPod ──
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# ── Install Ollama ──
RUN curl -fsSL https://ollama.com/install.sh | sh

# ── Install Open WebUI via pip (latest stable) ──
RUN pip3 install --no-cache-dir open-webui

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
