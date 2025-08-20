# CardMind

CardMind 是一个跨平台的知识卡片管理应用，采用现代化的 Web 技术栈构建，支持 Web PWA、桌面应用和 Docker 容器化部署。

## 🎯 项目愿景

CardMind 致力于成为个人知识管理的智能中枢，通过卡片化的知识管理方式，帮助用户构建可连接、可发现、可应用的个人知识体系。

## 🏗️ 项目架构

项目采用现代化的 Monorepo 架构，使用 pnpm workspaces 管理多个相关包：

```
CardMind/
├── apps/
│   ├── web/              # Web PWA 应用 (Vite + React)
│   ├── electron/         # Electron 桌面应用
│   └── docker/           # Docker 容器化部署
├── packages/
│   ├── types/            # TypeScript 类型定义
│   ├── shared/           # 共享工具和库
│   └── relay/            # WebSocket 实时协作服务
├── docs/                 # 项目文档
├── scripts/              # 构建和开发脚本
└── 配置文件...
```

## 🚀 技术栈

### 核心技术
- **包管理**: pnpm + workspaces
- **构建工具**: Vite
- **前端框架**: React 18 + TypeScript
- **状态管理**: Zustand
- **UI 框架**: Ant Design 5.x
- **样式方案**: Tailwind CSS

### 数据存储
- **浏览器存储**: IndexedDB (Dexie)
- **实时协作**: Yjs + y-websocket
- **后端服务**: Node.js + Express + Socket.io
- **缓存**: Redis (可选)

### 开发工具
- **类型检查**: TypeScript 严格模式
- **代码规范**: ESLint + Prettier
- **测试框架**: Jest + React Testing Library
- **Git Hooks**: Husky + lint-staged

## 🛠️ 快速开始

### 环境要求
- Node.js >= 18
- pnpm >= 8
- Git

### 安装依赖
```bash
# 安装 pnpm (如果尚未安装)
npm install -g pnpm

# 安装所有依赖
pnpm install
```

### 开发命令

#### 启动开发环境
```bash
# 启动 Web 应用
pnpm dev:web

# 启动 Electron 桌面应用
pnpm dev:electron

# 启动实时协作服务
pnpm --filter @cardmind/relay dev
```

#### 构建生产版本
```bash
# 构建所有应用
pnpm build

# 单独构建 Web 应用
pnpm build:web

# 构建 Electron 应用
pnpm build:electron
```

#### 其他常用命令
```bash
# 运行测试
pnpm test

# 代码格式化
pnpm format

# 代码检查
pnpm lint

# 类型检查
pnpm type-check
```

## 📦 应用部署

### Web PWA 部署
```bash
# 构建生产版本
pnpm build:web

# 部署到静态托管服务 (Vercel, Netlify, GitHub Pages)
# 构建输出: apps/web/dist/
```

### Electron 桌面应用
```bash
# 构建桌面应用
pnpm build:electron

# 输出:
# - Windows: apps/electron/dist/CardMind Setup.exe
# - macOS: apps/electron/dist/CardMind.dmg
# - Linux: apps/electron/dist/CardMind.AppImage
```

### Docker 容器化
```bash
# 构建 Docker 镜像
pnpm --filter @cardmind/docker build

# 运行容器
pnpm --filter @cardmind/docker start
```

## 📚 文档导航

### 开发者文档
- [架构设计](docs/developer/architecture.md) - 项目架构和技术决策
- [技术栈详解](docs/developer/tech-stack.md) - 完整技术栈说明
- [功能逻辑](docs/developer/features.md) - 核心功能实现逻辑
- [产品定位](docs/developer/product-positioning.md) - 产品规划和路线图
- [部署指南](docs/developer/deployment.md) - 详细部署流程
- [迁移计划](docs/developer/migration-plan.md) - 项目重构完成报告

### 用户文档
- [快速入门](docs/user/getting-started.md) - 新用户入门指南
- [功能详解](docs/user/features-guide.md) - 完整功能特性说明

## 🎯 核心功能特性

### 知识卡片管理
- ✅ 卡片创建、编辑、删除
- ✅ 富文本编辑 (Markdown 支持)
- ✅ 标签系统和智能分组
- ✅ 全文搜索和语义搜索

### 智能特性
- ✅ 智能标签推荐
- ✅ 知识关联推荐
- ✅ 学习进度跟踪
- ✅ 遗忘曲线提醒

### 协作功能
- ✅ 实时多人协作
- ✅ 评论和讨论
- ✅ 版本历史记录
- ✅ 权限管理

### 跨平台支持
- ✅ Web PWA (响应式设计)
- ✅ Electron 桌面应用
- ✅ Docker 容器化部署
- ✅ 离线使用支持

## 🤝 参与贡献

我们欢迎所有形式的贡献！

### 贡献方式
1. **报告问题**: 提交详细的 Issue 报告
2. **功能建议**: 分享您的想法和建议
3. **代码贡献**: 提交 Pull Request
4. **文档改进**: 帮助完善文档

### 开发规范
- 遵循项目代码规范
- 所有代码需包含中文注释
- 提交前确保测试通过
- 使用语义化的 Git 提交信息

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙋‍♂️ 联系我们

- **问题反馈**: [GitHub Issues](https://github.com/your-repo/cardmind/issues)
- **功能建议**: [GitHub Discussions](https://github.com/your-repo/cardmind/discussions)
- **技术支持**: support@cardmind.com

---

**开始使用 CardMind，构建您的个人知识管理体系！**
