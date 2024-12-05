# CardMind

CardMind 是一个跨平台的记忆卡片应用，帮助用户更好地学习和记忆。

## 项目结构

```
CardMind/
├── packages/
│   ├── core/           # 共享的核心功能
│   │   ├── src/
│   │   │   ├── database/  # 数据库模型和操作
│   │   │   ├── types/     # 共享类型定义
│   │   │   └── utils/     # 工具函数
│   │   └── package.json
│   │
│   ├── desktop/       # 桌面端应用 (Electron)
│   │   ├── electron/  # Electron 主进程
│   │   ├── src/      # React 渲染进程
│   │   └── package.json
│   │
│   └── mobile/       # 移动端应用 (React Native)
│       └── package.json
│
├── package.json      # 工作区配置
└── pnpm-workspace.yaml
```

## 技术栈

- 包管理器: pnpm
- 构建工具: Vite
- 框架:
  - 桌面端: Electron + React + TypeScript
  - 移动端: React Native + TypeScript
- 数据库: SQLite
- UI 组件库: Ant Design

## 开发指南

### 环境要求

- Node.js >= 16
- pnpm >= 8
- Git

### 安装

```bash
# 安装依赖
pnpm install
```

### 开发命令

```bash
# 启动桌面应用
pnpm --filter @cardmind/desktop start

# 构建桌面应用
pnpm --filter @cardmind/desktop build

# 运行测试
pnpm test

# 清理构建文件
pnpm clean
```

### 开发规范

1. 代码风格

   - 使用 ESLint 和 Prettier 进行代码格式化
   - 遵循 TypeScript 严格模式

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

## 许可证

MIT
