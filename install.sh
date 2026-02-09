#!/bin/bash

# ==========================================
# Node-Hy2 一键安装脚本
# ==========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}"
   echo -e "${YELLOW}请使用: sudo bash install.sh${PLAIN}"
   exit 1
fi

echo -e "${GREEN}==========================================${PLAIN}"
echo -e "${GREEN}      Node-Hy2 一键安装脚本${PLAIN}"
echo -e "${GREEN}==========================================${PLAIN}"

# 1. 检测系统并安装基础依赖
install_dependencies() {
    echo -e "${YELLOW}[1/5] 正在检查并安装系统依赖...${PLAIN}"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y curl wget unzip tar openssl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget unzip tar openssl
    elif command -v apk >/dev/null 2>&1; then
        apk update
        apk add curl wget unzip tar openssl bash
    else
        echo -e "${RED}错误: 未知的包管理器，请手动安装 curl, wget, unzip, tar, openssl${PLAIN}"
        exit 1
    fi
}

# 2. 安装 Node.js (如果不存在)
install_node() {
    echo -e "${YELLOW}[2/5] 正在检查 Node.js 环境...${PLAIN}"
    
    if command -v node >/dev/null 2>&1; then
        echo -e "${GREEN}Node.js 已安装: $(node -v)${PLAIN}"
        return
    fi
    
    echo -e "${YELLOW}正在安装 Node.js...${PLAIN}"
    
    if command -v apk >/dev/null 2>&1; then
        apk add nodejs npm
    elif command -v apt-get >/dev/null 2>&1; then
        # Debian/Ubuntu 使用 NodeSource (LTS)
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y nodejs
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL 使用 NodeSource (LTS)
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
        yum install -y nodejs
    else
        echo -e "${RED}错误: 无法自动安装 Node.js，请手动安装后重试。${PLAIN}"
        exit 1
    fi
}

# 3. 下载并解压代码
download_code() {
    local WORK_DIR="/root/nodejs-hy2"
    
    echo -e "${YELLOW}[3/5] 正在下载项目代码...${PLAIN}"
    
    # 如果目录存在，先备份
    if [ -d "$WORK_DIR" ]; then
        echo -e "${YELLOW}检测到目录 $WORK_DIR 已存在，正在备份...${PLAIN}"
        mv "$WORK_DIR" "${WORK_DIR}_backup_$(date +%s)"
    fi

    mkdir -p "$WORK_DIR"
    
    # 尝试使用 git clone (如果有 git)
    if command -v git >/dev/null 2>&1; then
        git clone https://github.com/XCQ0607/nodejs-hy2.git "$WORK_DIR"
    else
        # 使用 wget 下载 zip 包
        echo -e "正在使用 wget 下载..."
        if ! wget -O /tmp/nodejs-hy2.zip https://github.com/XCQ0607/nodejs-hy2/archive/refs/heads/main.zip; then
            echo -e "${RED}下载失败，请检查网络连接${PLAIN}"
            exit 1
        fi
        
        echo -e "正在解压..."
        unzip -q /tmp/nodejs-hy2.zip -d /tmp/
        # 移动解压后的内容 (nodejs-hy2-main) 到工作目录
        cp -r /tmp/nodejs-hy2-main/* "$WORK_DIR"
        rm -rf /tmp/nodejs-hy2.zip /tmp/nodejs-hy2-main
    fi

    cd "$WORK_DIR"
    chmod +x start.sh
}

# 4. 配置环境变量
setup_env() {
    echo -e "${YELLOW}[4/5] 正在配置环境变量...${PLAIN}"
    
    # 如果没有 .env，从模板复制或创建
    if [ ! -f .env ]; then
        if [ -f .env.template ]; then
            cp .env.template .env
        else
            touch .env
        fi
    fi

    # 处理传入的环境变量参数 (例如 UUID=... PORT=...)
    # 遍历所有参数
    for arg in "$@"; do
        # 检查参数格式是否为 KEY=VALUE
        if [[ "$arg" == *=* ]]; then
            key="${arg%%=*}"
            value="${arg#*=}"
            
            # 使用 sed 更新或追加环境变量
            if grep -q "^$key=" .env; then
                # 如果存在，替换 (使用 | 作为分隔符，避免 value 中含有 / 导致报错)
                sed -i "s|^$key=.*|$key=$value|" .env
            else
                # 如果不存在，追加
                echo "$key=$value" >> .env
            fi
            echo -e "${GREEN}已设置: $key=$value${PLAIN}"
        fi
    done
}

# 5. 启动服务
start_service() {
    echo -e "${YELLOW}[5/5] 正在启动服务...${PLAIN}"
    ./start.sh
}

# 捕获错误信号
trap 'echo -e "${RED}安装过程中断或出错${PLAIN}"; exit 1' ERR

# 主流程
install_dependencies
install_node
download_code
setup_env "$@"
start_service
