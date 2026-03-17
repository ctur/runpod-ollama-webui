# =============================================================================
# RunPod Pod Template: Ollama + Open WebUI
# Compute Type: NVIDIA GPU
#
# BUILD (Apple Container App):
#   container build --dns 8.8.8.8 -t your-registry/runpod-ollama-webui:latest .
#
# BUILD (Docker / other):
#   docker build --platform linux/amd64 -t your-registry/runpod-ollama-webui:latest .
#
# PIN VERSIONS (optional):
#   docker build --build-arg OLLAMA_VERSION=0.15.2 --build-arg OPENWEBUI_VERSION=0.8.5 ...
#
# PUSH:
#   docker push your-registry/runpod-ollama-webui:latest
# =============================================================================
FROM --platform=linux/amd64 runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

LABEL maintainer="runpod-ollama-webui"
LABEL description="Ollama LLM server + Open WebUI on RunPod GPU pods"

ENV DEBIAN_FRONTEND=noninteractive

# ── Version pinning (override with --build-arg) ──
# Empty = install latest. Set to specific version for reproducible builds.
# Example: --build-arg OLLAMA_VERSION=0.18.8 --build-arg OPENWEBUI_VERSION=0.8.8
ARG OLLAMA_VERSION="0.18.8"
ARG OPENWEBUI_VERSION="0.8.8"

# ── Install Ollama ──
# If OLLAMA_VERSION is set, download the pinned release directly (like vast.ai does).
# Otherwise, use the install script to get the latest.
RUN apt-get update && apt-get install -y --no-install-recommends zstd && \
    rm -rf /var/lib/apt/lists/* && \
    if [ -n "${OLLAMA_VERSION}" ]; then \
        curl -fsSL "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
            -o /tmp/ollama.tar.zst && \
        tar --use-compress-program=unzstd -xf /tmp/ollama.tar.zst -C /usr && \
        rm /tmp/ollama.tar.zst; \
    else \
        curl -fsSL https://ollama.com/install.sh | sh; \
    fi && \
    ollama --version

# ── Install Open WebUI via pip ──
# pip install is an officially supported method (docs.openwebui.com).
# Requires Python 3.11 or 3.12 (RunPod base has 3.11 ✓).
RUN if [ -n "${OPENWEBUI_VERSION}" ]; then \
        pip install --no-cache-dir "open-webui==${OPENWEBUI_VERSION}"; \
    else \
        pip install --no-cache-dir open-webui; \
    fi

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
# ENV DEFAULT_MODEL_PARAMS='{"temperature": 0.2, "top_p": 0.9, "top_k": 40, "repeat_penalty": 1.18, "repeat_last_n": 64, "context": 4096}'
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
