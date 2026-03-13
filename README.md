# RunPod Ollama + Open WebUI Pod Template

A self-contained Docker image that runs **Ollama** (LLM backend) and **Open WebUI** (chat frontend) on RunPod GPU pods. Deploy once, get a full ChatGPT-like interface powered by open-source models.

## Architecture

```
┌─────────────────────────────────────────┐
│           RunPod GPU Pod                │
│                                         │
│  ┌──────────────┐   ┌───────────────┐  │
│  │   Ollama      │◄──│  Open WebUI   │  │
│  │  :11434       │   │  :8080        │  │
│  │  (GPU LLM)    │   │  (Web Chat)   │  │
│  └──────────────┘   └───────────────┘  │
│         │                    │          │
│    /root/.ollama      /app/backend/data │
│   (network volume)   (container disk)   │
└─────────────────────────────────────────┘
```

## Quick Start

### 1. Build & Push the Image

```bash
docker build -t your-registry/runpod-ollama-webui:latest .
docker push your-registry/runpod-ollama-webui:latest
```

### 2. Create RunPod Pod Template

Go to **RunPod Console → Templates → New Template** and fill in:

| Field                | Value                                          |
|----------------------|------------------------------------------------|
| **Template Name**    | `Ollama + Open WebUI`                          |
| **Container Image**  | `your-registry/runpod-ollama-webui:latest`     |
| **Container Disk**   | `20 GB` (minimum, for OS + WebUI data)         |
| **Volume Disk**      | `50 GB+` (for models — adjust per model size)  |
| **Volume Mount Path**| `/root/.ollama`                                |
| **Expose HTTP Ports**| `8080, 11434`                                  |
| **Expose TCP Ports** | `11434`                                        |

### 3. Set Environment Variables

In the **Environment Variables** section of the template, add the variables you need.

### 4. Deploy

Choose your GPU (A40, A100, H100, etc.), click **Deploy**, and wait for the pod to start. Open WebUI will be available on the HTTP port `8080` proxy URL.

---

## Environment Variables Reference

### Ollama – Core

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | `llama3.2` | Model(s) to auto-pull on startup. Comma-separated for multiple (e.g. `llama3.2,mistral,codellama`). Set to empty string to skip auto-pull. |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Address Ollama listens on. **Do not change** unless you know what you're doing. |
| `OLLAMA_MODELS` | `/root/.ollama/models` | Directory where Ollama stores downloaded models. Maps to the network volume. |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep a model loaded in VRAM after last request. Use `0` to unload immediately, `-1` to keep forever. |
| `OLLAMA_NUM_PARALLEL` | `4` | Max concurrent requests per model. |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models loaded in VRAM simultaneously. Increase if you have enough VRAM for multiple models. |
| `OLLAMA_FLASH_ATTENTION` | `1` | Enable flash attention for better performance. Set to `0` to disable. |

### Ollama – GPU & Performance

| Variable | Default | Description |
|---|---|---|
| `NVIDIA_VISIBLE_DEVICES` | `all` | Which GPUs to expose. Use `0`, `1`, `0,1`, or `all`. |
| `OLLAMA_GPU_OVERHEAD` | *(unset)* | Reserve VRAM (bytes) for other processes. Useful when sharing GPU. |
| `OLLAMA_MAX_VRAM` | *(unset)* | Maximum VRAM Ollama is allowed to use (bytes). |
| `OLLAMA_NUM_GPU` | *(unset)* | Number of GPU layers to offload. `0` = CPU only, leave unset for auto. |
| `CUDA_VISIBLE_DEVICES` | *(unset)* | Alternative to `NVIDIA_VISIBLE_DEVICES` for specific GPU selection. |

### Open WebUI – Connection

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://127.0.0.1:11434` | URL Open WebUI uses to reach Ollama. Since both run in the same container, keep as localhost. |
| `PORT` | `8080` | Port Open WebUI listens on. This should match the exposed HTTP port. |
| `ENABLE_OLLAMA_API` | `True` | Enable Ollama API integration in WebUI. |

### Open WebUI – Authentication

| Variable | Default | Description |
|---|---|---|
| `WEBUI_AUTH` | `True` | Enable/disable authentication entirely. Set `False` for no-login single-user mode. |
| `ENABLE_SIGNUP` | `True` | Allow new users to create accounts. First user becomes admin. |
| `DEFAULT_USER_ROLE` | `pending` | Role for new signups: `pending`, `user`, or `admin`. |
| `WEBUI_ADMIN_EMAIL` | *(unset)* | Auto-create admin with this email on first boot (headless setup). |
| `WEBUI_ADMIN_PASSWORD` | *(unset)* | Password for the auto-created admin account. |
| `WEBUI_ADMIN_NAME` | `Admin` | Display name for auto-created admin. |

### Open WebUI – General

| Variable | Default | Description |
|---|---|---|
| `WEBUI_SECRET_KEY` | *(unset)* | Secret key for session signing. Auto-generated if unset. Set explicitly for persistence across restarts. |
| `DEFAULT_MODELS` | *(auto)* | Comma-separated default model(s) in the chat selector. Auto-set to `OLLAMA_MODEL` if not specified. |
| `DEFAULT_LOCALE` | `en` | Default UI language. |
| `DATA_DIR` | `/app/backend/data` | Where Open WebUI stores its SQLite DB, uploads, and cache. |
| `ENABLE_PERSISTENT_CONFIG` | `True` | When `True`, settings changed in Admin UI persist in the DB. Set `False` to always use env vars. |
| `ANONYMIZED_TELEMETRY` | `false` | Disable anonymous usage telemetry. |
| `DO_NOT_TRACK` | `true` | Additional telemetry opt-out. |

---

## RunPod Template Variables (Copy-Paste)

For quick setup, copy these into the **Environment Variables** field in your RunPod template. Adjust values as needed:

```
OLLAMA_MODEL=llama3.2
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_KEEP_ALIVE=5m
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_FLASH_ATTENTION=1
NVIDIA_VISIBLE_DEVICES=all
OLLAMA_BASE_URL=http://127.0.0.1:11434
PORT=8080
WEBUI_AUTH=True
ENABLE_SIGNUP=True
DEFAULT_USER_ROLE=pending
ENABLE_OLLAMA_API=True
ANONYMIZED_TELEMETRY=false
DO_NOT_TRACK=true
```

---

## Volume & Persistence

| Path | Storage | What's Stored |
|---|---|---|
| `/root/.ollama` | **Network Volume** (RunPod) | Downloaded model weights. Survives pod restarts and GPU changes. |
| `/app/backend/data` | Container Disk | Open WebUI database, chat history, user accounts, uploads. |

> **Tip:** If you also want Open WebUI data to persist across pod deletions, set the Volume Mount Path to a parent directory and adjust `DATA_DIR`, or use a second volume.

## Model Size Guide

| Model | VRAM Needed | Disk Size | Recommended GPU |
|---|---|---|---|
| `llama3.2` (3B) | ~4 GB | ~2 GB | Any |
| `llama3.1:8b` | ~8 GB | ~5 GB | RTX 3090 / A40 |
| `mistral` (7B) | ~8 GB | ~4 GB | RTX 3090 / A40 |
| `llama3.1:70b` | ~48 GB | ~40 GB | A100 80GB |
| `llama3.1:405b-q4` | ~240 GB | ~230 GB | 3× H100 |
| `codellama:34b` | ~24 GB | ~19 GB | A100 40GB |

Set your **Volume Disk** size accordingly.

## Accessing Your Pod

Once deployed, RunPod provides proxy URLs:

- **Open WebUI:** `https://{POD_ID}-8080.proxy.runpod.net`
- **Ollama API:** `https://{POD_ID}-11434.proxy.runpod.net`

On first visit to Open WebUI, you'll see the signup page. The first account created automatically becomes the admin.

## Pulling Additional Models

After deployment, you can pull more models through:

**Option 1 — Open WebUI Admin Panel:**
Go to Admin → Settings → Models → Pull a model

**Option 2 — Web Terminal:**
```bash
ollama pull codellama:13b
ollama pull mixtral:8x7b
```

**Option 3 — API:**
```bash
curl -X POST https://{POD_ID}-11434.proxy.runpod.net/api/pull \
  -d '{"name": "mistral"}'
```

## Troubleshooting

| Issue | Solution |
|---|---|
| WebUI shows "Ollama connection error" | Wait 1-2 min for Ollama to finish starting. Check logs with `journalctl` or pod logs. |
| Model pull fails | Check disk space. Increase Volume Disk size. |
| Out of VRAM | Use a smaller model or a GPU with more VRAM. Reduce `OLLAMA_NUM_PARALLEL`. |
| Slow first response | Normal — model loads into VRAM on first request. Subsequent requests are fast. |
| WebUI data lost on restart | Container disk is ephemeral. Mount `/app/backend/data` to a network volume for full persistence. |

## License

MIT
