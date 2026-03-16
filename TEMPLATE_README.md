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
| `OLLAMA_MODEL` | `qwen3.5:4b` | Model(s) to auto-pull on boot. Comma-separated. Empty = skip. |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long models stay loaded in VRAM. `-1` = forever. |
| `OLLAMA_NUM_PARALLEL` | `4` | Max concurrent requests per model. |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in VRAM at once. |
| `WEBUI_AUTH` | `True` | Set `False` for no-login single-user mode. |
| `ENABLE_SIGNUP` | `True` | Allow new user registrations. |
| `DEFAULT_USER_ROLE` | `pending` | Role for new signups: `pending` (requires admin approval), `user`, or `admin`. |
| `WEBUI_SECRET_KEY` | *(unset)* | Session signing key. Set via RunPod Secret for persistence across restarts: `{{ RUNPOD_SECRET_webui_secret }}` |

> **Secrets:** For sensitive values, create a secret in **RunPod Console → Secrets** and reference it as `{{ RUNPOD_SECRET_your_secret_name }}` in the environment variable value field.

## Storage (all on network volume)

| Path | Purpose |
|---|---|
| `/workspace/ollama/models` | Model weights — persists across restarts and pod deletions. |
| `/workspace/open-webui` | Open WebUI database, chats, uploads — persists across restarts and pod deletions. |

## Pulling More Models

Via web terminal or SSH:

```
ollama pull mistral
ollama pull codellama:13b
```

Or use the Open WebUI Admin Panel → Settings → Models.

## Recommended Template Settings

| Field | Value |
|---|---|
| Compute Type | NVIDIA GPU |
| Container Disk | 5 GB |
| Volume Disk | 5 GB+ (depends on model sizes) |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `8080`, `11434` |
| Expose TCP Ports | `22` |
| Start Command | *(leave blank)* |
