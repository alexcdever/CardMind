# CardMind

CardMind 是一个跨平台的记忆卡片应用，帮助用户更好地学习和记忆。支持 Web、桌面、移动端和 Docker 部署。

## 🏗️ 项目架构

项目采用 **Monorepo** 架构，使用 **pnpm workspace** 管理多个包和应用：

```
cardmind/
├── packages/              # 共享包
│   ├── types/            # TypeScript 类型定义
│   ├── shared/           # 共享工具和库
│   └── relay/            # WebSocket 实时协作服务
├── apps/                 # 应用
│   ├── web/              # Web PWA 应用
│   ├── electron/         # Electron 桌面应用
│   └── docker/           # Docker 部署配置
└── docs/                 # 项目文档
```

## 🚀 技术栈

### 核心
- **包管理器**: pnpm + workspace
- **构建工具**: Vite (Web/Electron) + Metro (RN)
- **语言**: TypeScript 5.x

### Web/桌面
- **框架**: React 18.x + Electron 28.x
- **样式**: Ant Design 5.x + CSS Modules
- **状态**: Zustand
- **数据库**: IndexedDB (Dexie)
- **协同**: Yjs + WebRTC

### 移动端
- **框架**: React Native 0.71.x
- **状态**: Zustand
- **数据库**: SQLite (React Native)

### 服务端
- **实时**: WebSocket (Node.js)
- **容器**: Docker

## 🎯 快速开始

### 环境要求
- Node.js >= 18
- pnpm >= 8
- Git



### 安装

```bash
# 克隆项目
git clone <repository-url>
cd cardmind

# 安装所有依赖
pnpm install
```

### 开发启动

#### Web 应用
```bash
# 启动开发服务器
pnpm dev:web

# 构建生产版本
pnpm build:web

# 预览构建结果
pnpm preview:web
```

#### Electron 桌面应用
```bash
# 启动开发环境
pnpm dev:electron

# 构建桌面应用
pnpm build:electron

# 运行构建的应用
pnpm start:electron
```

#### 实时协作服务
```bash
# 启动中继服务
pnpm --filter @cardmind/relay dev

# 构建服务
pnpm --filter @cardmind/relay build
```



#### Docker 部署
```bash
# 构建 Docker 镜像
pnpm --filter @cardmind/docker build

# 启动容器
pnpm --filter @cardmind/docker start
```

## 📦 工作区包说明

| 包名 | 路径 | 描述 |
|------|------|------|
| `@cardmind/types` | `packages/types` | TypeScript 类型定义 |
| `@cardmind/shared` | `packages/shared` | 共享工具和库 |
| `@cardmind/relay` | `packages/relay` | WebSocket 实时协作服务 |
| `@cardmind/web` | `apps/web` | Web PWA 应用 |
| `@cardmind/electron` | `apps/electron` | Electron 桌面应用 |
| `@cardmind/docker` | `apps/docker` | Docker 部署配置 |

## 🛠️ 开发命令汇总

### 常用命令
```bash
# 安装所有依赖
pnpm install

# 构建所有项目
pnpm build

# 运行测试
pnpm test

# 代码格式化
pnpm format

# 代码检查
pnpm lint

# 清理所有构建产物
pnpm clean
```

### 特定项目命令
```bash
# Web 应用
pnpm --filter @cardmind/web [dev|build|preview]

# Electron 应用
pnpm --filter @cardmind/electron [dev|build|start]

# Relay 服务
pnpm --filter @cardmind/relay [dev|build]
```

## 🔧 开发规范

### 代码风格
- 使用 ESLint + Prettier 进行代码格式化
- 遵循 TypeScript 严格模式
- 所有代码需包含中英文注释

### Git 提交规范
- `feat`: 新功能
- `fix`: 修复问题
- `docs`: 文档修改
- `style`: 代码格式修改
- `refactor`: 代码重构
- `test`: 测试用例修改
- `chore`: 其他修改

### 分支管理
- `main`: 主分支，保持稳定
- `develop`: 开发分支
- `feature/*`: 功能分支
- `fix/*`: 修复分支



## 🐳 Docker 部署

### 要求
- Docker Desktop
- Docker Compose

### 部署步骤
1. 确保所有项目已构建：`pnpm build`
2. 构建 Docker 镜像：`pnpm --filter @cardmind/docker build`
3. 启动容器：`pnpm --filter @cardmind/docker start`
4. 访问应用：`http://localhost:3000`

## 📖 更多文档

- [开发指南](dev.md) - 详细的开发环境配置和架构说明
- [用户文档](user_documentation.md) - 用户使用指南
- [部署文档](deployment.md) - 应用部署和发布流程


## 📝 许可证

MIT License