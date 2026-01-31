# NodeJS-Hy2/Tuic All-in-One

> [English Version](README_EN.md)

这是一个基于 Node.js 环境的轻量级代理服务部署脚本，支持 **Hysteria2** (默认) 或 **Tuic V5** 协议，并集成了 **Cloudflare Argo Tunnel** 以实现双重连接保障。

主要特点：
- **单端口复用**：HTTP 订阅服务 (TCP) 与 Hysteria2/Tuic (UDP) 共享同一个对外端口 (默认 3000)。
- **双模式运行**：同时支持直连 (UDP) 和 Argo Tunnel (WebSocket) 两种链路。
- **配置灵活**：支持环境变量及 `.env` 文件配置。
- **Docker 支持**：提供 Dockerfile，轻松部署。

## 快速开始

### 1. 使用 Docker 部署

我们提供了预构建的 Docker 镜像，只需一条命令即可运行：

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

### 2. 本地/VPS 直接运行

确保系统已安装 `curl`, `openssl`, `nodejs`。

```bash
# 1. 克隆项目
git clone https://github.com/your-repo/nodejs-hy2.git
cd nodejs-hy2

# 2. 修改配置 (可选)
cp .env.example .env
nano .env

# 3. 运行
chmod +x start.sh
./start.sh
```

## 配置说明

支持加载当前目录下的 `.env` 文件，或直接读取系统环境变量。

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `SERVER_PORT` | (空) | 云厂商开放端口列表（空格分隔）。一般由云平台自动配置，知道开放端口可手动填写，否则留空。 |
| `ARGO_TOKEN` | (空) | Cloudflare Tunnel Token。留空则启用临时隧道模式。 |
| `ARGO_DOMAIN` | (空) | 固定隧道绑定的域名。使用 Token 模式时**强烈建议**填写。 |
| `UDP_TYPE` | `hy2` | UDP 协议类型，可选 `hy2` 或 `tuic`。 |
| `SUB_PATH` | `sub` | 订阅链接的路径，如 `mysecret` -> `http://IP:3000/mysecret`。 |
| `HY2_PORT` | `3000` | UDP 协议监听端口，同时也是 HTTP 订阅服务端口。 |
| `ARGO_PORT` | `3001` | Argo Tunnel 后端使用的 VLESS-WS 端口 (TCP)。 |
| `CFIP` | (内置列表) | 自定义 Argo 节点的 Cloudflare 优选域名/IP。 |
| `UUID` | (随机生成) | 自定义固定 UUID。如留空则自动生成并持久化。 |

## 端口映射

| 端口/协议 | 用途 | 说明 |
| :--- | :--- | :--- |
| **3000 (UDP)** | 代理流量 | Hysteria2 或 Tuic 的数据通道。 |
| **3000 (TCP)** | 订阅服务 | 访问此端口获取节点订阅信息。 |
| **3001 (TCP)** | Argo 后端 | 仅本地监听，用于 Cloudflare Tunnel 连接。 |

## 关于 Cloudflare Tunnel (Argo)

- **临时模式** (默认)：无需配置 Token，脚本启动后会自动获取一个 `trycloudflare.com` 的随机域名。
- **固定模式** (推荐)：
    1. 在 Cloudflare Zero Trust 面板创建一个 Tunnel。
    2. 获取 Token 并设置环境变量 `ARGO_TOKEN`。
    3. 在 Tunnel 的 **Public Hostname** 中添加一条记录：
       - Service: `HTTP`
       - URL: `localhost:3001`
    4. 设置环境变量 `ARGO_DOMAIN` 为你在上一步绑定的域名。

---
**注意**：请遵守当地法律法规，仅供学习研究使用。
