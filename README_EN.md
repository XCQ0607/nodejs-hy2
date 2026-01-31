# NodeJS-Hy2/Tuic All-in-One

> [中文版本](README.md)

A lightweight proxy service deployment script based on Node.js environment, supporting **Hysteria2** (default) or **Tuic V5** protocols, integrated with **Cloudflare Argo Tunnel** for dual connectivity.

Key Features:
- **Port Reuse**: HTTP Subscription Service (TCP) and Hysteria2/Tuic (UDP) share the same external port (default 3000).
- **Dual Mode**: Supports both direct connection (UDP) and Argo Tunnel (WebSocket) links simultaneously.
- **Flexible Configuration**: Supports environment variables and `.env` file.
- **Docker Support**: Ready for Docker deployment.

## Quick Start

### 1. Deploy with Docker

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

### 2. Run Locally / on VPS

Ensure `curl`, `openssl`, and `nodejs` are installed.

```bash
# 1. Clone repo
git clone https://github.com/your-repo/nodejs-hy2.git
cd nodejs-hy2

# 2. Configure (Optional)
cp .env.example .env
nano .env

# 3. Run
chmod +x start.sh
./start.sh
```

## Configuration

The script loads configuration from a `.env` file in the current directory or from system environment variables.

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
