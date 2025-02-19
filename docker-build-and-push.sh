#!/bin/bash

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 设置 Docker 用户和镜像名
DOCKER_USER="alexcdever"
SERVER_IMAGE="cardmind-server"
WEB_IMAGE="cardmind-web"

# 设置版本号
VERSION=${1:-latest}

# 确保 Docker 已登录
echo -e "\n${GREEN}检查 Docker 登录状态...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker 守护进程未运行${NC}"
    exit 1
fi

if ! docker login >/dev/null 2>&1; then
    echo -e "${RED}请先登录 Docker Hub${NC}"
    docker login
fi

echo -e "${YELLOW}开始构建版本: ${VERSION}${NC}"

# 保存当前目录
ROOT_DIR=$(pwd)

# 构建后端
echo -e "\n${GREEN}在本地构建后端...${NC}"
cd server
cargo build --release
cd "$ROOT_DIR"

# 构建后端镜像
echo -e "\n${GREEN}构建后端镜像...${NC}"
docker build \
    --build-arg HTTP_PROXY=$http_proxy \
    --build-arg HTTPS_PROXY=$https_proxy \
    --build-arg http_proxy=$http_proxy \
    --build-arg https_proxy=$https_proxy \
    -t ${DOCKER_USER}/${SERVER_IMAGE}:${VERSION} \
    -f server/Dockerfile \
    server
docker tag ${DOCKER_USER}/${SERVER_IMAGE}:${VERSION} ${DOCKER_USER}/${SERVER_IMAGE}:latest

# 在本地构建前端
echo -e "\n${GREEN}在本地构建前端...${NC}"
cd packages/web
pnpm build

# 等待文件系统同步
sleep 2

# 检查构建是否成功
if [ ! -d "dist" ]; then
    echo -e "${RED}前端构建失败: dist 目录不存在${NC}"
    ls -la
    pwd
    exit 1
fi

# 构建前端镜像
echo -e "\n${GREEN}构建前端镜像...${NC}"
docker build \
    --build-arg HTTP_PROXY=$http_proxy \
    --build-arg HTTPS_PROXY=$https_proxy \
    --build-arg http_proxy=$http_proxy \
    --build-arg https_proxy=$https_proxy \
    -t ${DOCKER_USER}/${WEB_IMAGE}:${VERSION} \
    .
docker tag ${DOCKER_USER}/${WEB_IMAGE}:${VERSION} ${DOCKER_USER}/${WEB_IMAGE}:latest

cd "$ROOT_DIR"

# 推送镜像
echo -e "\n${GREEN}推送镜像到 Docker Hub...${NC}"
docker push ${DOCKER_USER}/${SERVER_IMAGE}:${VERSION}
docker push ${DOCKER_USER}/${SERVER_IMAGE}:latest
docker push ${DOCKER_USER}/${WEB_IMAGE}:${VERSION}
docker push ${DOCKER_USER}/${WEB_IMAGE}:latest

echo -e "\n${GREEN}构建完成！${NC}"
echo -e "后端镜像: ${DOCKER_USER}/${SERVER_IMAGE}:${VERSION}"
echo -e "前端镜像: ${DOCKER_USER}/${WEB_IMAGE}:${VERSION}"
