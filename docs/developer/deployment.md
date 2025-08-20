# CardMind 多平台部署指南

## 🎯 部署架构概览

CardMind 支持三种部署方式：
- **Web PWA**: 静态网站部署
- **Electron**: 桌面应用打包
- **Docker**: 容器化部署

## 📦 部署包说明

| 部署方式 | 路径 | 命令 | 输出 |
|----------|------|------|------|
| **Web PWA** | `apps/web` | `pnpm build:web` | `apps/web/dist/` |
| **Electron** | `apps/electron` | `pnpm build:electron` | `apps/electron/dist/` |
| **Docker** | `apps/docker` | `pnpm --filter @cardmind/docker build` | Docker 镜像 |

## 🌐 Web PWA 部署

### 构建命令
```bash
# 构建生产版本
pnpm build:web

# 输出目录
# apps/web/dist/
# 包含：index.html, sw.js, manifest.json 等 PWA 文件
```

### 部署方式
1. **静态服务器**: Nginx, Apache, Vercel, Netlify
2. **CDN**: CloudFlare, AWS S3 + CloudFront
3. **平台服务**: GitHub Pages, Vercel, Netlify

### 示例 - Vercel 部署
```bash
# 安装 Vercel CLI
npm i -g vercel

# 部署到 Vercel
vercel --prod apps/web/dist
```

## 🖥️ Electron 桌面应用

### 构建命令
```bash
# 构建所有平台
pnpm build:electron

# 构建特定平台
pnpm --filter @cardmind/electron build:win   # Windows
pnpm --filter @cardmind/electron build:mac   # macOS
pnpm --filter @cardmind/electron build:linux # Linux
```

### 输出文件
- **Windows**: `.exe` 安装包
- **macOS**: `.dmg` 磁盘镜像
- **Linux**: `.AppImage` 或 `.deb` 包

### 发布渠道
1. **GitHub Releases**: 自动发布到 GitHub
2. **应用商店**: Microsoft Store, Mac App Store
3. **官网下载**: 自建下载页面



## 🐳 Docker 容器化部署

### 构建命令
```bash
# 构建 Docker 镜像
pnpm --filter @cardmind/docker build

# 或者手动构建
cd apps/docker
docker build -t cardmind:latest .
```

### 运行容器
```bash
# 使用 Docker Compose
pnpm --filter @cardmind/docker start

# 或者手动运行
docker run -d -p 3000:3000 --name cardmind cardmind:latest
```

### Docker Compose 配置
```yaml
# docker-compose.yml
version: '3.8'
services:
  cardmind:
    image: cardmind:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
    restart: unless-stopped
```

### 部署环境
- **本地开发**: Docker Desktop
- **云服务器**: AWS ECS, Google Cloud Run, Azure Container Instances
- **Kubernetes**: K8s 集群部署

## 🚀 一键部署脚本

### 所有平台构建
```bash
# 构建所有项目
pnpm build

# 构建并打包所有平台
pnpm package:all
```

### 自动化部署
```bash
# GitHub Actions 自动部署
# 配置文件：.github/workflows/release.yml

# 触发发布
# 创建新的 release tag
git tag v1.0.0
git push origin v1.0.0
```

## 📋 部署检查清单

### 部署前检查
- [ ] 所有测试通过
- [ ] 代码审查完成
- [ ] 版本号更新
- [ ] 构建成功
- [ ] 功能测试通过

### 部署后验证
- [ ] Web 应用正常访问
- [ ] PWA 功能正常
- [ ] 桌面应用可安装
- [ ] 移动端应用可安装
- [ ] 实时协作功能正常
- [ ] Docker 容器正常运行

## 🔧 环境配置

### 环境变量
```bash
# Web 应用
VITE_API_URL=https://api.cardmind.com
VITE_WS_URL=wss://ws.cardmind.com

# Electron 应用
ELECTRON_API_URL=https://api.cardmind.com
ELECTRON_WS_URL=wss://ws.cardmind.com
```

### 配置文件
- **Web**: `apps/web/.env.production`
- **Electron**: `apps/electron/.env`
- **Docker**: `apps/docker/.env`

## 📊 性能优化

### 构建优化
- **代码分割**: 按路由和组件分割
- **懒加载**: 动态导入组件
- **压缩**: Gzip/Brotli 压缩
- **缓存**: CDN 缓存策略

### Docker 优化
- **多阶段构建**: 减小镜像体积
- **缓存层**: 优化 Dockerfile 缓存
- **基础镜像**: 使用 Alpine Linux

## 🛡️ 安全建议

### Web 安全
- HTTPS 强制
- CSP 策略
- 输入验证
- XSS 防护

### 移动端安全
- 代码混淆
- 证书固定
- 数据加密
- 安全存储

## 📞 支持

### 部署问题
- 查看 [BUILD_STATUS.md](../BUILD_STATUS.md) 了解构建状态
- 检查 [migration_progress.md](../migration_progress.md) 了解迁移进度
- 提交 Issue 到 GitHub 仓库

### 联系信息
- GitHub Issues: [项目仓库](https://github.com/your-org/cardmind/issues)
- 文档反馈: docs@cardmind.com