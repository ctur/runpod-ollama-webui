# =============================================================================
# RunPod Pod Template: Ollama + Open WebUI
# Compute Type: NVIDIA GPU
#
# BUILD:
#   docker build --platform linux/amd64 -t your-registry/runpod-ollama-webui:latest .
#
#   Apple Container App DNS fix (if build fails with "Temporary failure resolving"):
#     1. Stop any local DNS service (dnsmasq, pihole, etc.)
#     2. Or switch to Docker Desktop which handles DNS differently
#     3. Or build on a Linux machine / CI pipeline
#
# PUSH:
#   docker push your-registry/runpod-ollama-webui:latest
# =============================================================================
FROM --platform=linux/amd64 runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

LABEL maintainer="runpod-ollama-webui"
LABEL description="Ollama LLM server + Open WebUI on RunPod GPU pods"

ENV DEBIAN_FRONTEND=noninteractive

# ── Extra packages (RunPod base already has curl, wget, git, python3, pip, ssh) ──
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        libsm6 \
        libxext6 \
        lsof \
    && rm -rf /var/lib/apt/lists/*

# ── Install Ollama ──
RUN curl -fsSL https://ollama.com/install.sh | sh

# ── Install Open WebUI via pip ──
RUN pip install --no-cache-dir open-webui

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

# Ollama — storage (persists on RunPod network volume at /workspace)
ENV OLLAMA_MODELS=/workspace/ollama/models

# Model to auto-pull on first boot (comma-separated, empty to skip)
ENV OLLAMA_MODEL=llama3.2

# Open WebUI — connection
ENV OLLAMA_BASE_URL=http://127.0.0.1:11434
ENV PORT=8080
ENV ENABLE_OLLAMA_API=True

# Open WebUI — storage (persists on RunPod network volume at /workspace)
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
# 22    = SSH (RunPod base image already configures sshd)
EXPOSE 8080 11434 22

# Override the base image's default CMD with our entrypoint.
# The entrypoint starts SSH itself (via the base's /start.sh pattern),
# then launches Ollama + Open WebUI.
ENTRYPOINT ["/entrypoint.sh"]
