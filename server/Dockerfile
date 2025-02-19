# 使用较新版本的 Debian
FROM debian:bookworm-slim

# 设置工作目录
WORKDIR /app

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制本地构建产物
COPY target/release/cardmind-server .
COPY migrations ./migrations

# 设置健康检查
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["./cardmind-server"]
