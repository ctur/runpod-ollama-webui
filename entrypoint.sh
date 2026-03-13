#!/bin/bash
set -e

# =============================================================================
# RunPod Ollama + Open WebUI Entrypoint
# =============================================================================

echo "============================================="
echo "  RunPod Ollama + Open WebUI Template"
echo "============================================="
echo ""
echo "  Pod ID:       ${RUNPOD_POD_ID:-unknown}"
echo "  GPU:          ${NVIDIA_VISIBLE_DEVICES:-all}"
echo "  Ollama Host:  ${OLLAMA_HOST:-0.0.0.0:11434}"
echo "  WebUI Port:   ${PORT:-8080}"
echo "  Model:        ${OLLAMA_MODEL:-none}"
echo ""
echo "============================================="

# ── 0. Export env vars for true SSH sessions ──
# RunPod's "true SSH" over TCP doesn't inherit container env vars.
# Write them to /etc/profile.d/ so they're available in SSH shells.
if [ -f /root/export-env.sh ]; then
    /root/export-env.sh
    echo "[INFO] Environment variables exported for SSH sessions."
fi

# ── 0b. Start SSH daemon if PUBLIC_KEY is available ──
if [ -n "${PUBLIC_KEY}" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "${PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    service ssh start
    echo "[INFO] SSH daemon started (public key injected)."
elif [ -n "${SSH_PUBLIC_KEY}" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    service ssh start
    echo "[INFO] SSH daemon started (SSH_PUBLIC_KEY injected)."
else
    echo "[INFO] No PUBLIC_KEY or SSH_PUBLIC_KEY found. SSH daemon not started."
    echo "[INFO] Add your public key in RunPod account settings to enable SSH."
fi

# ── Helper: wait for Ollama to become ready ──
wait_for_ollama() {
    local max_attempts=60
    local attempt=0
    echo "[INFO] Waiting for Ollama server to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
            echo "[INFO] Ollama server is ready."
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    echo "[WARN] Ollama server did not become ready in time."
    return 1
}

# ── 1. Start Ollama server in background ──
echo "[INFO] Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# ── 2. Wait for Ollama to be responsive ──
wait_for_ollama

# ── 3. Auto-pull model(s) if OLLAMA_MODEL is set ──
if [ -n "${OLLAMA_MODEL}" ]; then
    # Support comma-separated list of models
    IFS=',' read -ra MODELS <<< "${OLLAMA_MODEL}"
    for model in "${MODELS[@]}"; do
        model=$(echo "$model" | xargs)  # trim whitespace
        if [ -n "$model" ]; then
            echo "[INFO] Pulling model: ${model} ..."
            ollama pull "${model}" || echo "[WARN] Failed to pull model: ${model}"
        fi
    done

    # Set the first model as default if DEFAULT_MODELS is not set
    first_model=$(echo "${MODELS[0]}" | xargs)
    if [ -z "${DEFAULT_MODELS}" ] && [ -n "${first_model}" ]; then
        export DEFAULT_MODELS="${first_model}"
        echo "[INFO] Default model set to: ${first_model}"
    fi
fi

# ── 4. List available models ──
echo "[INFO] Available Ollama models:"
ollama list 2>/dev/null || echo "  (none yet)"
echo ""

# ── 5. Start Open WebUI ──
echo "[INFO] Starting Open WebUI on port ${PORT:-8080}..."
open-webui serve &
WEBUI_PID=$!

echo ""
echo "============================================="
echo "  All services running!"
echo "  Open WebUI: http://localhost:${PORT:-8080}"
echo "  Ollama API: http://localhost:11434"
if [ -n "${RUNPOD_POD_ID}" ]; then
echo ""
echo "  RunPod Proxy URLs:"
echo "  WebUI:  https://${RUNPOD_POD_ID}-${PORT:-8080}.proxy.runpod.net"
echo "  Ollama: https://${RUNPOD_POD_ID}-11434.proxy.runpod.net"
fi
echo "============================================="
echo ""

# ── 6. Handle shutdown gracefully ──
shutdown() {
    echo "[INFO] Shutting down..."
    kill $WEBUI_PID 2>/dev/null
    kill $OLLAMA_PID 2>/dev/null
    wait
    echo "[INFO] All services stopped."
    exit 0
}

trap shutdown SIGTERM SIGINT SIGQUIT

# ── 7. Keep container alive, restart services if they crash ──
while true; do
    # Check if Ollama is still running
    if ! kill -0 $OLLAMA_PID 2>/dev/null; then
        echo "[WARN] Ollama process died. Restarting..."
        ollama serve &
        OLLAMA_PID=$!
        sleep 5
    fi

    # Check if Open WebUI is still running
    if ! kill -0 $WEBUI_PID 2>/dev/null; then
        echo "[WARN] Open WebUI process died. Restarting..."
        open-webui serve &
        WEBUI_PID=$!
        sleep 5
    fi

    sleep 10
done
