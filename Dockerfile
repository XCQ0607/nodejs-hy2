# 使用 Node.js 轻量级镜像作为基础，因为我们需要运行 HTTP 订阅服务 (server.js)
FROM node:lts-slim


LABEL org.opencontainers.image.source=https://github.com/XCQ0607/nodejs-hy2
LABEL org.opencontainers.image.description="nodejs hy2 docker image"
LABEL org.opencontainers.image.licenses=MIT


# 设置工作目录
WORKDIR /app

# 安装必要的系统依赖
# curl: 下载脚本和二进制文件
# bash: 运行 start.sh
# openssl: 生成自签名证书
# ca-certificates: 确保 HTTPS 请求正常
# procps: 提供 ps 等命令 (可选，便于调试)
# iproute2: 某些网络检测可能需要
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 复制当前目录下的所有文件到容器中
COPY . .

# 赋予启动脚本执行权限
RUN chmod +x start.sh

# 暴露端口
# 3000: UDP (Hy2/Tuic) 和 TCP (HTTP Subscription)
# 3001: TCP (内部 VLESS-WS，通常仅本地使用，但如果需要也可暴露)
EXPOSE 3000/tcp 3000/udp 3001/tcp

# 定义环境变量默认值 (也可以在运行时通过 -e 覆盖)
ENV SUB_PATH=sub \
    UDP_TYPE=hy2 \
    HY2_PORT=3000 \
    ARGO_PORT=3001

# 启动命令
CMD ["./start.sh"]
