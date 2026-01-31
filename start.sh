#!/bin/bash
set -e

# ================== 核心配置区域 (环境变量优先) ==================

# 0. 加载本地 .env 文件 (兼容 Windows CRLF 换行符)
if [ -f .env ]; then
    set -a
    # 使用 tr 删除回车符 (\r) 后再 source，避免 command not found 错误
    source <(tr -d '\r' < .env)
    set +a
fi


# 1. 订阅路径 (环境变量: SUB_PATH)
SUB_PATH="${SUB_PATH:-sub}"
SUB_PATH="${SUB_PATH#/}"

# 2. Argo Token (环境变量: ARGO_TOKEN)
ARGO_TOKEN="${ARGO_TOKEN:-}"

# 3. Argo 固定域名 (环境变量: ARGO_DOMAIN)
ARGO_DOMAIN_CFG="${ARGO_DOMAIN:-}"

# 4. CF 优选域名 (环境变量: CFIP)
CFIP="${CFIP:-}"

# 5. 协议选择 (环境变量: UDP_TYPE)
# 可选值: hy2 (默认), tuic
UDP_TYPE="${UDP_TYPE:-hy2}"
UDP_TYPE="${UDP_TYPE,,}"
if [[ "$UDP_TYPE" != "tuic" ]]; then UDP_TYPE="hy2"; fi

# ================== 端口自动检测 ==================
# 检查端口是否被占用 (TCP)
is_port_busy() {
    local port=$1
    # 尝试连接本地端口，如果成功(exit 0)说明被占用
    # 优先使用 timeout 防止连接挂起
    if command -v timeout >/dev/null 2>&1; then
        (timeout 0.5 bash -c "</dev/tcp/127.0.0.1/$port") 2>/dev/null
    else
        (bash -c "</dev/tcp/127.0.0.1/$port") 2>/dev/null
    fi
}

# 寻找可用端口
# 参数1: 偏好端口
# 参数2: 排除端口 (可选)
find_available_port() {
    local port=$1
    local exclude=${2:-0}
    
    while true; do
        # 跳过排除端口
        if [ "$port" -eq "$exclude" ]; then
            port=$((port + 1))
            continue
        fi
        
        if is_port_busy "$port"; then
            echo "[端口] $port 被占用，尝试下一个..." >&2
            port=$((port + 1))
        else
            echo "$port"
            return 0
        fi
        
        # 防止死循环（上限 65535）
        if [ "$port" -gt 65535 ]; then
            echo "[错误] 未找到可用端口 (上限 65535)" >&2
            exit 1
        fi
    done
}

# 6. 端口配置
# 优先级: 环境变量 -> 默认值 -> 自动递增寻找可用端口
USE_HY2_PORT="${HY2_PORT:-${UDP_PORT:-3000}}"
USE_ARGO_PORT="${ARGO_PORT:-3001}"

echo "[端口] 检测可用性 (起始端口: Hy2=$USE_HY2_PORT, Argo=$USE_ARGO_PORT)..."
HY2_PORT=$(find_available_port "$USE_HY2_PORT")
echo "[端口] 确认 Hy2/Web 端口: $HY2_PORT"

ARGO_PORT=$(find_available_port "$USE_ARGO_PORT" "$HY2_PORT")
echo "[端口] 确认 Argo Tunnel 端口: $ARGO_PORT"

# ================== CF 优选域名列表 ==================
if [ -n "$CFIP" ]; then
    IFS=', ' read -r -a CF_DOMAINS <<< "$CFIP"
else
    CF_DOMAINS=(
        "cf.090227.xyz"
        "cf.877774.xyz"
        "cf.130519.xyz"
        "cf.008500.xyz"
        "store.ubi.com"
        "saas.sin.fan"
    )
fi

# ================== 切换到脚本目录 ==================
cd "$(dirname "$0")"
export FILE_PATH="${PWD}/.npm"

rm -rf "$FILE_PATH"
mkdir -p "$FILE_PATH"

# ================== 获取公网 IP ==================
echo "[网络] 获取公网 IP..."
PUBLIC_IP=$(curl -s --max-time 5 ipv4.ip.sb || curl -s --max-time 5 api.ipify.org || echo "")
[ -z "$PUBLIC_IP" ] && echo "[错误] 无法获取公网 IP" && exit 1
echo "[网络] 公网 IP: $PUBLIC_IP"

# ================== CF 优选：随机选择可用域名 ==================
select_random_cf_domain() {
    local available=()
    for domain in "${CF_DOMAINS[@]}"; do
        if curl -s --max-time 2 -o /dev/null "https://$domain" 2>/dev/null; then
            available+=("$domain")
        fi
    done
    [ ${#available[@]} -gt 0 ] && echo "${available[$((RANDOM % ${#available[@]}))]}" || echo "${CF_DOMAINS[0]}"
}

echo "[CF优选] 测试中..."
BEST_CF_DOMAIN=$(select_random_cf_domain)
echo "[CF优选] $BEST_CF_DOMAIN"

# ================== UUID ==================
UUID_FILE="${FILE_PATH}/uuid.txt"
if [ -n "$UUID" ]; then
    echo "[UUID] 使用环境变量预设 UUID"
    echo "$UUID" > "$UUID_FILE"
elif [ -f "$UUID_FILE" ]; then
    UUID=$(cat "$UUID_FILE")
else
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "$UUID" > "$UUID_FILE"
fi
echo "[UUID] $UUID"

# ================== 架构检测 & 下载 ==================
ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" ]] && BASE_URL="https://arm64.ssss.nyc.mn" || BASE_URL="https://amd64.ssss.nyc.mn"
[[ "$ARCH" == "aarch64" ]] && ARGO_ARCH="arm64" || ARGO_ARCH="amd64"

SB_FILE="${FILE_PATH}/sb"
ARGO_FILE="${FILE_PATH}/cloudflared"

download_file() {
    local url=$1 output=$2
    [ -x "$output" ] && return 0
    echo "[下载] $output..."
    curl -L -sS --max-time 60 -o "$output" "$url" && chmod +x "$output" && echo "[下载] $output 完成" && return 0
    echo "[下载] $output 失败" && return 1
}

download_file "${BASE_URL}/sb" "$SB_FILE"
download_file "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARGO_ARCH}" "$ARGO_FILE"

# ================== 证书生成 ==================
echo "[证书] 生成中..."
if command -v openssl >/dev/null 2>&1; then
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "${FILE_PATH}/private.key" -out "${FILE_PATH}/cert.pem" -days 3650 -subj "/CN=www.bing.com" >/dev/null 2>&1
else
    printf -- "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIM4792SEtPqIt1ywqTd/0bYidBqpYV/+siNnfBYsdUYsoAoGCCqGSM49\nAwEHoUQDQgAE1kHafPj07rJG+HboH2ekAI4r+e6TL38GWASAnngZreoQDF16ARa/\nTsyLyFoPkhTxSbehH/OBEjHtSZGaDhMqQ==\n-----END EC PRIVATE KEY-----\n" > "${FILE_PATH}/private.key"
    printf -- "-----BEGIN CERTIFICATE-----\nMIIBejCCASGgAwIBAgIUFWeQL3556PNJLp/veCFxGNj9crkwCgYIKoZIzj0EAwIw\nEzERMA8GA1UEAwwIYmluZy5jb20wHhcNMjUwMTAxMDEwMTAwWhcNMzUwMTAxMDEw\nMTAwWjATMREwDwYDVQQDDAhiaW5nLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEH\nA0IABNZB2nz49O6yRvh26B9npACOK/nuky9/BlgEgJ54Ga3qEAxdegEWv07Mi8ha\nD5IU8Um3oR/zgRIx7UmRmg4TKkOjUzBRMB0GA1UdDgQWBBTV1cFID7UISE7PLTBR\nBfGbgrkMNzAfBgNVHSMEGDAWgBTV1cFID7UISE7PLTBRBfGbgrkMNzAPBgNVHRMB\nAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIARDAJvg0vd/ytrQVvEcSm6XTlB+\neQ6OFb9LbLYL9Zi+AiB+foMbi4y/0YUQlTtz7as9S8/lciBF5VCUoVIKS+vX2g==\n-----END CERTIFICATE-----\n" > "${FILE_PATH}/cert.pem"
fi
echo "[证书] 已就绪"

# ================== 生成订阅 ==================
generate_sub() {
    local argo_domain="$1"
    > "${FILE_PATH}/list.txt"
    
    # UDP 节点 (Tuic 或 Hy2)
    if [ "$UDP_TYPE" == "tuic" ]; then
        echo "tuic://${UUID}:admin@${PUBLIC_IP}:${HY2_PORT}?sni=www.bing.com&alpn=h3&congestion_control=bbr&allowInsecure=1#Tuic-Node" >> "${FILE_PATH}/list.txt"
    else
        # 默认 Hy2
        echo "hysteria2://${UUID}@${PUBLIC_IP}:${HY2_PORT}/?sni=www.bing.com&insecure=1#Hysteria2-Node" >> "${FILE_PATH}/list.txt"
    fi
    
    # Argo VLESS (WS) on ARGO_PORT (proxied via Tunnel)
    [ -n "$argo_domain" ] && echo "vless://${UUID}@${BEST_CF_DOMAIN}:443?encryption=none&security=tls&sni=${argo_domain}&type=ws&host=${argo_domain}&path=%2F${UUID}-vless#Argo-Node" >> "${FILE_PATH}/list.txt"

    cat "${FILE_PATH}/list.txt" > "${FILE_PATH}/sub.txt"
}

# ================== HTTP 服务器脚本 ==================
# 监听 HY2_PORT (TCP)，因为 UDP 只占用了 UDP 协议，端口复用
cat > "${FILE_PATH}/server.js" <<JSEOF
const http = require('http');
const fs = require('fs');
const port = process.env.PORT || 8080;
const subPath = '/${SUB_PATH}';
const uuidPath = '/${UUID}';

const server = http.createServer((req, res) => {
    if (req.url.includes(subPath) || req.url.includes(uuidPath)) {
        res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
        try { res.end(fs.readFileSync('${FILE_PATH}/sub.txt', 'utf8')); } catch(e) { res.end('error'); }
    } else { res.writeHead(404); res.end('404'); }
});

server.on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
        console.log('端口 ' + port + ' 被占用 (TCP)? 请检查是否与 sing-box 冲突');
    } else {
        console.error(e);
    }
});

server.listen(port, '0.0.0.0', () => console.log('HTTP Sub running on port ' + port));
JSEOF

# ================== 启动 HTTP 订阅服务 ==================
# 将 HTTP 服务绑定在 HY2_PORT (TCP) 上
echo "[HTTP] 启动订阅服务 (端口 $HY2_PORT)..."
PORT=$HY2_PORT node "${FILE_PATH}/server.js" &
HTTP_PID=$!
sleep 1
# 检查进程是否存活
if kill -0 $HTTP_PID 2>/dev/null; then
  echo "[HTTP] 订阅服务已启动: http://${PUBLIC_IP}:${HY2_PORT}/${SUB_PATH}"
else
  echo "[错误] HTTP 服务启动失败"
fi

# ================== 生成 sing-box 配置 ==================
echo "[CONFIG] 生成配置..."

# 生成 UDP Inbound 配置 (Tuic 或 Hy2)
if [ "$UDP_TYPE" == "tuic" ]; then
    UDP_INBOUND="{
        \"type\": \"tuic\",
        \"tag\": \"tuic-in\",
        \"listen\": \"::\",
        \"listen_port\": ${HY2_PORT},
        \"users\": [{\"uuid\": \"${UUID}\", \"password\": \"admin\"}],
        \"congestion_control\": \"bbr\",
        \"tls\": {
            \"enabled\": true,
            \"alpn\": [\"h3\"],
            \"certificate_path\": \"${FILE_PATH}/cert.pem\",
            \"key_path\": \"${FILE_PATH}/private.key\"
        }
    }"
else
    # Hysteria2
    UDP_INBOUND="{
        \"type\": \"hysteria2\",
        \"tag\": \"hy2-in\",
        \"listen\": \"::\",
        \"listen_port\": ${HY2_PORT},
        \"users\": [{\"password\": \"${UUID}\"}],
        \"tls\": {
            \"enabled\": true,
            \"alpn\": [\"h3\"],
            \"certificate_path\": \"${FILE_PATH}/cert.pem\",
            \"key_path\": \"${FILE_PATH}/private.key\"
        }
    }"
fi

INBOUNDS="
    ${UDP_INBOUND},
    {
        \"type\": \"vless\",
        \"tag\": \"vless-argo-in\",
        \"listen\": \"127.0.0.1\",
        \"listen_port\": ${ARGO_PORT},
        \"users\": [{\"uuid\": \"${UUID}\"}],
        \"transport\": {
            \"type\": \"ws\",
            \"path\": \"/${UUID}-vless\"
        }
    }
"

cat > "${FILE_PATH}/config.json" <<CFGEOF
{
    "log": {"level": "warn"},
    "inbounds": [${INBOUNDS}],
    "outbounds": [{"type": "direct", "tag": "direct"}]
}
CFGEOF
echo "[CONFIG] 配置已生成"

# ================== 启动 sing-box ==================
echo "[SING-BOX] 启动中..."
"$SB_FILE" run -c "${FILE_PATH}/config.json" &
SB_PID=$!
sleep 2

if ! kill -0 $SB_PID 2>/dev/null; then
    echo "[SING-BOX] 启动失败"
    head -n 2 "${FILE_PATH}/private.key"
    "$SB_FILE" run -c "${FILE_PATH}/config.json"
    exit 1
fi
echo "[SING-BOX] 已启动 PID: $SB_PID"

# ================== [修复] Argo 隧道 ==================
ARGO_LOG="${FILE_PATH}/argo.log"
ARGO_DOMAIN=""
echo "[Argo] 启动隧道 (监听 127.0.0.1:${ARGO_PORT})..."

if [ -n "$ARGO_TOKEN" ]; then
    echo "[Argo] 模式: 固定隧道 (Token)"
    if [ -z "$ARGO_DOMAIN_CFG" ]; then
         echo "[提示] 未环境变量指定 ARGO_DOMAIN, 订阅将不包含 Argo 节点"
    else
         ARGO_DOMAIN="$ARGO_DOMAIN_CFG"
    fi
    # Token 模式: 指向本地 WS 端口 (VLESS)
    "$ARGO_FILE" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate run --token "$ARGO_TOKEN" > "$ARGO_LOG" 2>&1 &
    ARGO_PID=$!
else
    echo "[Argo] 未找到 Token，默认使用临时隧道 (Quick Tunnel)"
    # 临时隧道
    "$ARGO_FILE" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://127.0.0.1:${ARGO_PORT} > "$ARGO_LOG" 2>&1 &
    ARGO_PID=$!
    
    for i in {1..30}; do
        sleep 1
        ARGO_DOMAIN=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1 | sed 's|https://||')
        [ -n "$ARGO_DOMAIN" ] && break
    done
    [ -n "$ARGO_DOMAIN" ] && echo "[Argo] 临时域名: $ARGO_DOMAIN" || echo "[Argo] 获取域名失败"
fi

# ================== 生成订阅 ==================
generate_sub "$ARGO_DOMAIN"
SUB_URL="http://${PUBLIC_IP}:${HY2_PORT}/${SUB_PATH}"

# ================== 输出结果 ==================
echo ""
echo "================= 运行状态 ======================"
echo "Http订阅地址    : $SUB_URL"
echo "Http订阅端口    : $HY2_PORT (TCP)"
echo "UDP服务端口     : $HY2_PORT (UDP) [协议: ${UDP_TYPE^^}]"
echo "Ws服务端口      : $ARGO_PORT (TCP, 仅本地)"
echo ""
echo "--- 节点详情 ---"
echo "UUID            : $UUID"
[ -n "$ARGO_DOMAIN" ] && echo "Argo 域名       : $ARGO_DOMAIN"
echo "==================================================="
echo ""

# ================== 保持运行 ==================
wait $SB_PID
