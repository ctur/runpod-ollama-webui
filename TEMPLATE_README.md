# Ollama + Open WebUI (GPU)

Run open-source LLMs with a ChatGPT-like web interface on RunPod GPU pods.

**Ollama** serves models with GPU acceleration. **Open WebUI** provides the chat interface.

## Quick Access

Once deployed, access your services via RunPod proxy URLs:

- **Open WebUI:** `https://{POD_ID}-8080.proxy.runpod.net`
- **Ollama API:** `https://{POD_ID}-11434.proxy.runpod.net`
- **SSH:** Available if you've added your SSH key in RunPod account settings

On first visit, create an account — the first user becomes admin.

## Key Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | `llama3.2` | Model(s) to auto-pull on boot. Comma-separated. Empty = skip. |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long models stay loaded in VRAM. `-1` = forever. |
| `OLLAMA_NUM_PARALLEL` | `4` | Max concurrent requests per model. |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in VRAM at once. |
| `WEBUI_AUTH` | `True` | Set `False` for no-login single-user mode. |
| `ENABLE_SIGNUP` | `True` | Allow new user registrations. |

## Storage

| Path | Purpose |
|---|---|
| `/root/.ollama` | **Mount your network volume here.** Model weights persist across restarts. |
| `/app/backend/data` | Open WebUI database, chats, uploads (container disk). |

## Pulling More Models

Via web terminal or SSH:
```
ollama pull mistral
ollama pull codellama:13b
```

Or use the Open WebUI Admin Panel → Settings → Models.

## Recommended Setup

| Field | Value |
|---|---|
| Container Disk | 20 GB |
| Volume Disk | 50 GB+ (depends on model sizes) |
| Volume Mount Path | `/root/.ollama` |
| Expose HTTP Ports | `8080, 11434` |
| Expose TCP Ports | `22` |
