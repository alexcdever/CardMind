# CardMind

CardMind 是一个跨平台的记忆卡片应用，帮助用户更好地学习和记忆。

## 项目结构

项目采用单体仓库结构，包含桌面端和移动端两个应用：

```
CardMind/
├── src/                    # 桌面端应用源码 (Electron + React)
│   ├── components/         # React组件
│   ├── db/                # 数据库相关
│   ├── stores/            # 状态管理
│   ├── styles/            # 样式文件
│   ├── types/             # 类型定义
│   └── utils/             # 工具函数
├── CardMindAndroid/        # 移动端应用 (React Native)
│   ├── android/           # Android原生代码
│   ├── ios/              # iOS原生代码
│   ├── src/              # React Native源码
│   └── ...               # React Native相关配置
├── docs/                  # 项目文档
├── electron-main.mjs      # Electron主进程文件
├── package.json          # 根目录包配置
├── pnpm-workspace.yaml   # pnpm工作区配置
└── ...                   # 其他配置文件
```

## 技术栈

- 包管理器: pnpm
- 构建工具: Vite (桌面端)
- 框架:
  - 桌面端: Electron + React + TypeScript
  - 移动端: React Native + TypeScript
- 数据库: SQLite
- 状态管理: Zustand
- UI 组件库: Ant Design

## 开发指南

### 环境要求

- Node.js >= 16
- pnpm >= 8
- Git
- 移动端开发额外要求:
  - Android Studio (Android开发)
  - Xcode (iOS开发，仅限macOS)

### 安装

```bash
# 安装所有依赖
pnpm install
```

### 开发命令

#### 桌面端应用
```bash
# 启动开发服务器
pnpm dev

# 构建桌面应用
pnpm build

# 预览构建结果
pnpm preview
```

#### 移动端应用
```bash
# 进入移动端目录
cd CardMindAndroid

# Android开发
npm run android

# iOS开发 (macOS)
npm run ios

# Metro打包器
npm start
```

#### 通用命令
```bash
# 运行测试
pnpm test

# 代码格式化
pnpm format

# 代码检查
pnpm lint
```

### 开发规范

1. 代码风格
   - 使用 ESLint 和 Prettier 进行代码格式化
   - 遵循 TypeScript 严格模式
   - 所有代码需包含中文注释

2. Git 提交规范
   - feat: 新功能
   - fix: 修复问题
   - docs: 文档修改
   - style: 代码格式修改
   - refactor: 代码重构
   - test: 测试用例修改
   - chore: 其他修改

3. 分支管理
   - main: 主分支，保持稳定
   - develop: 开发分支
   - feature/\*: 功能分支
   - fix/\*: 修复分支

## 开发文档

- [开发指南](docs/dev.md) - 详细的开发环境配置和架构说明
- [用户文档](docs/user_documentation.md) - 用户使用指南
- [部署文档](deployment.md) - 应用部署和发布流程

## 许可证

MIT
