# RunPod Ollama + Open WebUI Pod Template

A self-contained Docker image that runs **Ollama** (LLM backend) and **Open WebUI** (chat frontend) on RunPod GPU pods. Deploy once, get a full ChatGPT-like interface powered by open-source models.

## Architecture

```
┌───────────────────────────────────────────────────┐
│                RunPod GPU Pod                     │
│                                                   │
│  ┌──────────────┐       ┌───────────────┐        │
│  │   Ollama      │◄──────│  Open WebUI   │        │
│  │  :11434       │       │  :8080        │        │
│  │  (GPU LLM)    │       │  (Web Chat)   │        │
│  └──────┬───────┘       └───────┬───────┘        │
│         │                       │                 │
│  ┌──────┴───────────────────────┴───────┐        │
│  │       /workspace  (network volume)    │        │
│  │  /workspace/ollama/models  ← models   │        │
│  │  /workspace/open-webui     ← chats/db │        │
│  └──────────────────────────────────────┘        │
└───────────────────────────────────────────────────┘
```

## Quick Start

### 1. Build & Push the Image

```bash
# IMPORTANT: Always build for linux/amd64 (required by RunPod)
docker build --platform linux/amd64 -t your-registry/runpod-ollama-webui:latest .
docker push your-registry/runpod-ollama-webui:latest
```

> **Apple Silicon / ARM users:** The `--platform linux/amd64` flag is mandatory. RunPod only supports `linux/amd64` architecture.

> **Base image:** `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` — RunPod's official PyTorch base which already includes CUDA, Python 3.11, pip, SSH, JupyterLab, curl, wget, and git. The Dockerfile only installs a few extra packages on top.

### 2. Create RunPod Pod Template

Go to **RunPod Console → Templates → New Template** and fill in:

| Field                  | Value                                              |
|------------------------|----------------------------------------------------|
| **Template Name**      | `Ollama + Open WebUI`                              |
| **Compute Type**       | `NVIDIA GPU`                                       |
| **Container Image**    | `your-registry/runpod-ollama-webui:latest`         |
| **Container Disk**     | `20 GB` (for OS + installed packages)              |
| **Volume Disk**        | `50 GB+` (for models — adjust per model size)      |
| **Volume Mount Path**  | `/workspace`                                       |
| **Expose HTTP Ports**  | `8080` (Open WebUI), `11434` (Ollama API)          |
| **Expose TCP Ports**   | `22` (SSH)                                         |
| **Start Command**      | *(leave blank — Dockerfile ENTRYPOINT handles it)* |
| **Template Readme**    | *(paste contents of `TEMPLATE_README.md`)*         |

### 3. Set Environment Variables

In the **Environment Variables** section of the template, add the variables you need (see reference below).

### 4. Deploy

Choose your GPU (A40, A100, H100, etc.), click **Deploy On-Demand**, and wait for the pod to start. Open WebUI will be available on the HTTP port `8080` proxy URL.

---

## Environment Variables Reference

### Ollama – Core

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | `llama3.2` | Model(s) to auto-pull on startup. Comma-separated for multiple (e.g. `llama3.2,mistral,codellama`). Set to empty string to skip auto-pull. |
| `OLLAMA_HOST` | `0.0.0.0:11434` | Address Ollama listens on. **Do not change** unless you know what you're doing. |
| `OLLAMA_MODELS` | `/workspace/ollama/models` | Directory where Ollama stores downloaded models. Lives on the network volume by default. |
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
| `PORT` | `8080` | Port Open WebUI listens on. Must match the exposed HTTP port. |
| `ENABLE_OLLAMA_API` | `True` | Enable Ollama API integration in WebUI. |

### Open WebUI – Authentication

| Variable | Default | Description |
|---|---|---|
| `WEBUI_AUTH` | `True` | Enable/disable authentication entirely. Set `False` for no-login single-user mode. |
| `ENABLE_SIGNUP` | `True` | Allow new users to create accounts. First user becomes admin. |
| `DEFAULT_USER_ROLE` | `pending` | Role for new signups: `pending`, `user`, or `admin`. |
| `WEBUI_ADMIN_EMAIL` | *(unset)* | Auto-create admin with this email on first boot (headless setup). |
| `WEBUI_ADMIN_PASSWORD` | *(unset)* | Password for the auto-created admin account. Use RunPod Secrets for this. |
| `WEBUI_ADMIN_NAME` | `Admin` | Display name for auto-created admin. |

### Open WebUI – General

| Variable | Default | Description |
|---|---|---|
| `WEBUI_SECRET_KEY` | *(unset)* | Secret key for session signing. Auto-generated if unset. Set explicitly for persistence across restarts. Use RunPod Secrets for this. |
| `DEFAULT_MODELS` | *(auto)* | Comma-separated default model(s) in the chat selector. Auto-set to `OLLAMA_MODEL` if not specified. |
| `DEFAULT_LOCALE` | `en` | Default UI language. |
| `DATA_DIR` | `/workspace/open-webui` | Where Open WebUI stores its SQLite DB, uploads, and cache. Lives on the network volume by default. |
| `ENABLE_PERSISTENT_CONFIG` | `True` | When `True`, settings changed in Admin UI persist in the DB. Set `False` to always use env vars. |
| `ANONYMIZED_TELEMETRY` | `false` | Disable anonymous usage telemetry. |
| `DO_NOT_TRACK` | `true` | Additional telemetry opt-out. |

---

## RunPod Template Variables (Copy-Paste)

For quick setup, copy these into the **Environment Variables** field in your RunPod template. Adjust values as needed:

```
OLLAMA_MODEL=llama3.2
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=/workspace/ollama/models
OLLAMA_KEEP_ALIVE=5m
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_FLASH_ATTENTION=1
NVIDIA_VISIBLE_DEVICES=all
OLLAMA_BASE_URL=http://127.0.0.1:11434
PORT=8080
DATA_DIR=/workspace/open-webui
WEBUI_AUTH=True
ENABLE_SIGNUP=True
DEFAULT_USER_ROLE=pending
ENABLE_OLLAMA_API=True
ANONYMIZED_TELEMETRY=false
DO_NOT_TRACK=true
```

---

## Volume & Persistence

RunPod network volumes mount at `/workspace`. This template stores **everything** there so all data survives pod restarts and even pod deletions (as long as you keep the network volume):

| Path | What's Stored |
|---|---|
| `/workspace/ollama/models` | Downloaded model weights |
| `/workspace/open-webui` | Open WebUI database, chat history, user accounts, uploads |

The entrypoint also creates a symlink `/root/.ollama → /workspace/ollama` so Ollama's default home directory points to the persistent volume.

> **Without a network volume:** If you deploy without a network volume, `/workspace` falls back to the pod's regular volume disk (persists across restarts but not pod deletions). Models and WebUI data will still work, they just won't survive a pod termination.

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

**Option 2 — Web Terminal or SSH:**
```bash
ollama pull codellama:13b
ollama pull mixtral:8x7b
```

**Option 3 — API:**
```bash
curl -X POST https://{POD_ID}-11434.proxy.runpod.net/api/pull \
  -d '{"name": "mistral"}'
```

## SSH Access

This template includes a pre-configured SSH daemon. To use it:

1. Add your SSH public key in **RunPod Account Settings → SSH Public Keys**
2. RunPod injects it via the `PUBLIC_KEY` env var automatically
3. Once the pod is running, find the SSH command under **Connect → SSH over exposed TCP**

You can also set `SSH_PUBLIC_KEY` manually in the template environment variables as an override.

## RunPod System Environment Variables

RunPod automatically injects these into every pod — no need to set them yourself:

| Variable | Description |
|---|---|
| `RUNPOD_POD_ID` | Unique pod identifier (used in proxy URLs) |
| `RUNPOD_API_KEY` | API key for RunPod API calls from within the pod |
| `RUNPOD_POD_HOSTNAME` | Hostname of the server running your pod |
| `RUNPOD_GPU_COUNT` | Number of GPUs allocated |
| `RUNPOD_PUBLIC_IP` | Public IP (if available) |
| `RUNPOD_TCP_PORT_22` | External mapped port for SSH |
| `RUNPOD_DC_ID` | Data center ID |
| `PUBLIC_KEY` | Your SSH public key (from account settings) |

## Sensitive Variables & Secrets

For API keys or passwords, use **RunPod Secrets** instead of plain env vars. Create a secret in **RunPod Console → Secrets**, then reference it in your template with:

```
WEBUI_SECRET_KEY={{ RUNPOD_SECRET_webui_secret }}
WEBUI_ADMIN_PASSWORD={{ RUNPOD_SECRET_admin_password }}
```

Secret values are encrypted and not visible after creation.

## Troubleshooting

### Docker Build: "Temporary failure resolving" (Apple Container App / Docker Desktop)

If `docker build` fails with DNS errors like `Temporary failure resolving 'archive.ubuntu.com'`, the build container has no internet. This is a host-side DNS issue, not a Dockerfile problem.

**Apple Container App** — there's a known bug where local DNS services (dnsmasq, pihole, etc.) conflict with the container's resolver. Fixes:
1. Stop any local DNS service running on port 53, then retry the build
2. Switch to Docker Desktop for Mac which handles DNS differently
3. Build on a Linux machine or CI pipeline (GitHub Actions, etc.)

**Docker Desktop** — try adding DNS servers in Docker Desktop → Settings → Docker Engine:
```json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

### Runtime Issues

| Issue | Solution |
|---|---|
| WebUI shows "Ollama connection error" | Wait 1-2 min for Ollama to finish starting. Check pod logs. |
| Model pull fails | Check disk space with `df -h /workspace`. Increase Volume Disk size. |
| Out of VRAM | Use a smaller model or a GPU with more VRAM. Reduce `OLLAMA_NUM_PARALLEL`. |
| Slow first response | Normal — model loads into VRAM on first request. Subsequent requests are fast. |
| Models gone after pod restart | Verify your network volume is attached and mounted at `/workspace`. Check with `ls /workspace/ollama/models`. |
| SSH: "Permission denied" | Verify your public key is correctly added in RunPod account settings. Each key must be on its own line. |
| Env vars missing in SSH | This template exports env vars to `/etc/profile.d/`. If still missing, run `source /etc/profile.d/runpod-envs.sh`. |
| Settings not updating from env vars | Open WebUI uses `PersistentConfig` — after first boot, env vars are ignored for some settings. Set `ENABLE_PERSISTENT_CONFIG=False` to force env var usage, or change settings in the Admin Panel. |

## Create Template via REST API

You can also create the template programmatically:

```bash
curl --request POST \
  --url https://rest.runpod.io/v1/templates \
  --header 'Authorization: Bearer YOUR_RUNPOD_API_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "name": "Ollama + Open WebUI",
    "category": "NVIDIA",
    "imageName": "your-registry/runpod-ollama-webui:latest",
    "containerDiskInGb": 20,
    "volumeInGb": 50,
    "volumeMountPath": "/workspace",
    "ports": ["8080/http", "11434/http", "22/tcp"],
    "env": {
      "OLLAMA_MODEL": "llama3.2",
      "OLLAMA_HOST": "0.0.0.0:11434",
      "OLLAMA_MODELS": "/workspace/ollama/models",
      "OLLAMA_KEEP_ALIVE": "5m",
      "OLLAMA_NUM_PARALLEL": "4",
      "OLLAMA_MAX_LOADED_MODELS": "1",
      "OLLAMA_FLASH_ATTENTION": "1",
      "NVIDIA_VISIBLE_DEVICES": "all",
      "OLLAMA_BASE_URL": "http://127.0.0.1:11434",
      "PORT": "8080",
      "DATA_DIR": "/workspace/open-webui",
      "WEBUI_AUTH": "True",
      "ENABLE_SIGNUP": "True",
      "ENABLE_OLLAMA_API": "True",
      "ANONYMIZED_TELEMETRY": "false",
      "DO_NOT_TRACK": "true"
    },
    "isPublic": false,
    "isServerless": false
  }'
```

## License

MIT
