# CardMind 技术栈文档

## 1. 前端技术栈

### 1.1 核心框架
- **React**: 用于构建用户界面的JavaScript库
- **TypeScript**: 提供类型安全的JavaScript超集

### 1.2 UI组件库
- **Ant Design**: 企业级UI组件库
- **Tailwind CSS**: 实用优先的CSS框架，用于快速构建自定义设计

### 1.3 状态管理
- **Zustand**: 轻量级状态管理解决方案

### 1.4 数据存储
- **Dexie.js**: IndexedDB的包装库，简化本地数据库操作
- **IndexedDB**: 浏览器内置的本地存储机制，用于存储业务数据

### 1.5 实时同步
- **Yjs**: CRDT(Conflict-free Replicated Data Type)库，实现无冲突数据同步
- **WebRTC**: 实现点对点实时通信
- **y-webrtc**: Yjs的WebRTC连接器
- **y-indexeddb**: Yjs的IndexedDB持久化适配器

### 1.6 安全与加密
- **Web Crypto API**: 浏览器内置的加密功能
- **AES-256-GCM**: 高级加密标准，用于数据加密
- **PBKDF2**: 密码基础密钥派生函数，用于安全地从密码生成加密密钥

### 1.7 开发工具
- **Vite**: 下一代前端构建工具，提供极速开发体验
- **ESLint**: 代码质量工具
- **Prettier**: 代码格式化工具
- **Jest**: 测试框架
- **Cypress**: E2E测试框架

### 1.8 PWA支持
- **Workbox**: 用于构建Progressive Web App的库
- **Service Worker**: 实现离线功能和资源缓存

## 2. 架构设计

### 2.1 整体架构
- 离线优先的PWA架构
- 端到端加密存储
- 无冲突的CRDT数据同步
- 响应式设计，跨设备兼容
- 模块化架构，易于扩展

### 2.2 技术架构分层
- **表现层**: React组件，Ant Design UI
- **状态管理层**: Zustand
- **业务服务层**: 各类服务（CardService, EncryptionService, SyncService等）
- **数据访问层**: Dexie.js, Yjs
- **存储层**: IndexedDB, Yjs持久化

### 2.3 数据模型设计
- **Card**: 核心数据实体，包含id, title, content, createdAt, updatedAt, isDeleted等字段

## 3. 目录结构

```
├── public/             # 静态资源
├── src/                # 源代码
│   ├── components/     # React组件
│   │   ├── CardList/
│   │   ├── CardEditor/
│   ├── stores/         # 状态管理
│   │   ├── cardStore.ts
│   │   └── syncStore.ts
│   ├── services/       # 业务服务
│   │   ├── CardService.ts
│   │   ├── EncryptionService.ts
│   │   └── SyncService.ts
│   ├── utils/          # 工具函数
│   │   ├── encryption.ts
│   │   └── validation.ts
│   └── types/          # 类型定义
│       └── card.types.ts
```