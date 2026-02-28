# NodeJS-Hy2/Tuic All-in-One

> [中文版本](README.md)

A lightweight proxy service deployment script based on Node.js environment, supporting **Hysteria2** (default) or **Tuic V5** protocols, integrated with **Cloudflare Argo Tunnel** for dual connectivity.

Key Features:
- **Port Reuse**: HTTP Subscription Service (TCP) and Hysteria2/Tuic (UDP) share the same external port (default 3000).
- **Dual Mode**: Supports both direct connection (UDP) and Argo Tunnel (WebSocket) links simultaneously.
- **Flexible Configuration**: Supports environment variables and `.env` file.
- **Docker Support**: Ready for Docker deployment.


## Quick Start

### 1. One-Click Installation (Recommended)

Supports Ubuntu / Debian / CentOS / Alpine.

```bash
curl -sL https://raw.githubusercontent.com/XCQ0607/nodejs-hy2/main/install.sh | sudo bash
```

**Custom Parameters**:

```bash
# Example: Custom UUID and Port
curl -sL https://raw.githubusercontent.com/XCQ0607/nodejs-hy2/main/install.sh | sudo bash -s UUID=your-uuid HY2_PORT=12345

# Supports all environment variables, for example:
# curl -sL ... | sudo bash -s \
#   UUID=... \
#   HY2_PORT=3000 \
#   UDP_TYPE=tuic \
#   ARGO_TOKEN=... \
#   ARGO_DOMAIN=... \
#   SUB_PATH=...
#   (See Configuration section for more details)
```

### 2. Deploy with Docker

You can run the service with a single command using our pre-built image:

```bash
docker run -d \
  --name node-hy2 \
  -p 3000:3000/udp \
  -p 3000:3000/tcp \
  -e ARGO_TOKEN="eyJhIjoi..." \
  -e ARGO_DOMAIN="tunnel.example.com" \
  -e UDP_TYPE="hy2" \
  ghcr.io/nodejs-hy2:latest
```

### 3. Deploy via Python Environment (PaaS Platforms Recommended)

For platforms providing a Python runtime (such as Wasmer, Fly.io, or Heroku). The project supports **fully automated Python bootstrapping**. The system will automatically detect and install necessary dependencies like `bash`, `curl`, and `node`.

1. **Entry Point**: `main.py`
2. **Start Command**: `python main.py`
3. **Environment Variables**: Configure them in your platform's dashboard.

```bash
# Test the Python entry locally
python main.py
```

We provide pre-built deployment packages in the [Releases](../../releases) page:
- **`nodejs-deploy.zip`**: Clean Node.js deployment package.
- **`python-deploy.zip`**: Deployment package with Python bootstrap support.

## Configuration

The script loads configuration from a `.env` file in the current directory or from system environment variables.


> **Priority**: OS/Platform environment variables (e.g., set via Wasmer dashboard) **ALWAYS** take precedence over values in the `.env` file.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `SERVER_PORT` | (Empty) | Cloud provider's open port list (space-separated). Usually configured automatically by platforms like Render/Railway. Leave empty unless you know the specific ports. |
| `ARGO_TOKEN` | (Empty) | Cloudflare Tunnel Token. Leave empty specifically for Quick Tunnel mode. |
| `ARGO_DOMAIN` | (Empty) | The domain bound to your fixed tunnel. **Highly recommended** when using Token mode. |
| `UDP_TYPE` | `hy2` | UDP protocol type. Options: `hy2` or `tuic`. |
| `SUB_PATH` | `sub` | Path for the subscription link, e.g., `mysecret` -> `http://IP:3000/mysecret`. |
| `HY2_PORT` | `3000` | Port for UDP protocol and HTTP subscription service. |
| `ARGO_PORT` | `3001` | TCP port for VLESS-WS backend used by Cloudflare Tunnel. |
| `CFIP` | (List) | Custom Cloudflare IP/Domain for Argo nodes. |
| `UUID` | (Random) | Custom fixed UUID. If empty, auto-generated. |

## Port Mapping

| Port/Protocol | Usage | Description |
| :--- | :--- | :--- |
| **3000 (UDP)** | Proxy Traffic | Data channel for Hysteria2 or Tuic. |
| **3000 (TCP)** | Subscription | Access this port to get node configuration links. |
| **3001 (TCP)** | Argo Backend | Local listener for Cloudflare Tunnel connection. |

## Cloudflare Tunnel (Argo) Guide

- **Quick Tunnel** (Default): No Token required. The script will automatically fetch a random `trycloudflare.com` domain.
- **Fixed Tunnel** (Recommended):
    1. Create a Tunnel in Cloudflare Zero Trust dashboard.
    2. Get the Token and set `ARGO_TOKEN`.
    3. Add a **Public Hostname** record in the Tunnel settings:
       - Service: `HTTP`
       - URL: `localhost:3001`
    4. Set `ARGO_DOMAIN` to the domain you bound.

---
**Disclaimer**: This project is for educational purposes only. Please troubleshoot network issues in compliance with local regulations.
