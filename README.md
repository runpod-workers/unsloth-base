# Unsloth Studio — Runpod Pod Template

Fine-tune LLMs up to 2x faster with 70% less VRAM. Web UI for training
(LoRA, full fine-tune), inference, data recipes, and model export.
OpenAI-compatible API included.

## Services

| Port | Service | URL Pattern |
|------|---------|-------------|
| 8000 | Unsloth Studio | `https://<POD_ID>-8000.proxy.runpod.net` |
| 8888 | JupyterLab | `https://<POD_ID>-8888.proxy.runpod.net` |
| 22 | SSH | Via Runpod SSH connection |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `UNSLOTH_ADMIN_PASSWORD` | Yes | Admin password for Unsloth Studio |
| `JUPYTER_PASSWORD` | No | Token for JupyterLab access (empty = no auth) |
| `EXIT_ON_CRASH` | No | Set to `true` to exit container on Studio crash (default: `false`, keeps container alive for debugging) |

## Storage

All persistent data is stored under `/workspace/unsloth/`:

- `cache/huggingface/` — Downloaded model weights
- `outputs/` — Training checkpoints
- `exports/` — Exported models (GGUF, safetensors)
- `assets/datasets/` — Uploaded and generated datasets
- `auth/` — User authentication database
- `logs/` — Service logs (Jupyter)

With a network volume attached, all data persists across pod restarts.

## Template Configuration

| Field | Value |
|-------|-------|
| Exposed HTTP Ports | `8000,8888` |
| Exposed TCP Ports | `22` |
