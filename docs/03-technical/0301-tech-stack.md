# CardMind 技术栈文档

## 1. 概述

本文档详细介绍了CardMind项目使用的技术栈，面向开发人员和技术决策者。CardMind采用现代化技术栈，支持跨平台部署和离线优先的数据同步。

## 2. 核心内容

### 2.1 前端技术栈

#### 2.1.1 核心框架
- **React**: 用于构建用户界面的JavaScript库
- **TypeScript**: 提供类型安全的JavaScript超集

#### 2.1.2 UI组件库
- **Ant Design**: 企业级UI组件库
- **Tailwind CSS**: 实用优先的CSS框架，用于快速构建自定义设计

#### 2.1.3 状态管理
- **Zustand**: 轻量级状态管理解决方案

#### 2.1.4 数据存储
- **Dexie.js**: IndexedDB的包装库，简化本地数据库操作
- **IndexedDB**: 浏览器内置的本地存储机制，用于存储业务数据

#### 2.1.5 实时同步
- **Yjs**: CRDT(Conflict-free Replicated Data Type)库，实现无冲突数据同步
- **WebRTC**: 实现点对点实时通信
- **y-webrtc**: Yjs的WebRTC连接器
- **y-indexeddb**: Yjs的IndexedDB持久化适配器

#### 2.1.6 设备标识
- **UUID**: 生成唯一标识符，用于网络ID和设备ID
- **设备指纹技术**: 收集设备特征，用于生成设备标识

#### 2.1.7 开发工具
- **Vite**: 下一代前端构建工具，提供极速开发体验
- **ESLint**: 代码质量工具
- **Prettier**: 代码格式化工具
- **Jest**: 测试框架
- **Cypress**: E2E测试框架

#### 2.1.8 依赖管理
- **pnpm**: 高性能的Node.js包管理器，提供更快的安装速度和更小的磁盘占用

#### 2.1.9 PWA支持
- **Workbox**: 用于构建Progressive Web App的库
- **Service Worker**: 实现离线功能和资源缓存

#### 2.1.10 跨平台支持
- **Electron**: 将Web应用打包为桌面应用（Windows/macOS/Linux）
- **React Native**: 构建原生移动应用（iOS/Android）
- **Capacitor**: 作为Electron和RN的替代方案

#### 2.1.11 信令服务
- **WebSocket**: 实时双向通信协议，用于WebRTC信令传输
- **后端信令服务**: Node.js + Express + WebSocket服务器，为Web平台提供信令支持
  - **Web平台后端**: Express + WebSocket（提供完整的HTTP信令服务器）
  - **功能**: WebRTC信令交换、设备发现、文件传输协调
- **本地客户端信令服务**: Electron/React Native平台内置信令服务
  - **Electron平台**: Express + WebSocket（桌面端内置HTTP服务器）
  - **React Native平台**: NanoHTTPD/GCDWebServer + WebSocket（移动端HTTP服务器）
- **mDNS/Bonjour**: 本地网络设备发现服务
  - **Web平台**: mDNS.js库（Service Worker处理UDP广播）
  - **Electron**: 原生Bonjour支持
  - **React Native**: 原生mDNS/Bonjour支持
- **自动端口分配**: 动态端口检测与分配，避免端口冲突

#### 2.1.12 跨平台兼容性
- **统一网络适配层**: NetworkAdapter抽象接口，支持平台特定实现
- **存储适配层**: StorageAdapter统一接口，支持IndexedDB/SQLite/AsyncStorage
- **平台能力检测**: 运行时检测平台能力，智能选择最优策略
- **渐进式降级**: 根据平台能力自动降级到可用方案
- **错误处理与恢复**: 跨平台统一的错误处理和自动降级机制

### 2.2 后端技术栈

#### 2.2.1 运行时环境
- **Node.js**: JavaScript运行时环境

#### 2.2.2 Web框架
- **Express**: 轻量级Web应用框架

#### 2.2.3 实时通信
- **Socket.IO**: WebSocket库，支持实时双向通信
- **ws**: 轻量级WebSocket库

#### 2.2.4 数据存储
- **SQLite**: 轻量级关系型数据库
- **AsyncStorage**: React Native的异步存储系统

#### 2.2.5 网络发现
- **mDNS.js**: JavaScript实现的mDNS库
- **Bonjour**: 原生mDNS服务发现

#### 2.2.6 移动端原生模块
- **NanoHTTPD**: Android平台的轻量级HTTP服务器
- **GCDWebServer**: iOS平台的HTTP服务器

### 2.3 数据模型

#### 2.3.1 核心实体
- **Card**: 卡片实体，包含id、title、content、createdAt、updatedAt、isDeleted等字段
- **Network**: 网络实体，包含networkId、accessCode、createdAt等字段
- **Device**: 设备实体，包含deviceId、deviceName、platform、lastSeen等字段

#### 2.3.2 数据结构
- **Yjs文档**: 使用Yjs的CRDT数据结构存储卡片数据
- **IndexedDB**: 浏览器本地存储，用于持久化卡片数据
- **AsyncStorage**: React Native本地存储

### 2.4 开发环境

#### 2.4.1 构建工具
- **Vite**: 前端构建工具
- **TypeScript**: 类型检查和编译
- **ESBuild**: 快速JavaScript打包器

#### 2.4.2 代码质量
- **ESLint**: JavaScript/TypeScript代码检查
- **Prettier**: 代码格式化
- **Husky**: Git钩子管理
- **lint-staged**: 只对暂存文件运行lint

#### 2.4.3 测试工具
- **Jest**: JavaScript测试框架
- **React Testing Library**: React组件测试
- **Cypress**: 端到端测试

#### 2.4.4 部署工具
- **Docker**: 容器化部署
- **PM2**: Node.js进程管理器

### 2.5 目录结构技术栈映射

```
src/
├── components/         # React组件（React + TypeScript + Ant Design）
├── stores/            # 状态管理（Zustand）
├── services/          # 业务服务（TypeScript）
├── types/             # 类型定义（TypeScript）
├── utils/             # 工具函数（TypeScript）
└── main.tsx           # 应用入口（React + TypeScript）

public/
├── service-worker.js  # Service Worker（PWA支持）
├── manifest.json      # PWA清单文件
└── test-network.html  # 网络测试页面

signaling-server/      # 信令服务器（Node.js + Express + WebSocket）
└── src/
    └── yjs-document-manager.js  # Yjs文档管理
```

## 3. 注意事项

### 3.1 技术选型考虑
- 前端框架选择React是基于其生态成熟度和开发效率
- 状态管理选择Zustand而非Redux是为了简化代码结构
- 使用Yjs实现CRDT同步是为了解决多设备数据冲突问题

### 3.2 跨平台兼容性
- Web平台需要额外的信令服务器支持WebRTC连接
- Electron和React Native平台可以内置信令服务
- 不同平台的存储机制不同，需要适配层统一接口

### 3.3 性能考虑
- IndexedDB适合大量结构化数据存储
- Yjs的CRDT算法在大量并发编辑时可能有性能影响
- WebRTC连接建立过程可能需要优化用户体验

### 3.4 安全考虑
- WebRTC连接默认加密，但仍需验证设备身份
- 本地数据存储需要加密保护
- Access Code需要安全生成和验证

## 4. 关联文档

- [技术概念文档](0302-tech-concepts.md) - 理解核心概念和原理
- [统一业务逻辑架构设计](0302-unified-business-logic-design.md) - 架构设计原则和分层结构
- [技术实现示例](0303-implementation-examples.md) - 具体的代码实现示例
- [跨平台架构设计](0306-cross-platform-architecture.md) - 跨平台技术架构详细设计
- [纯离线局域网组网架构](0308-offline-lan-architecture.md) - 局域网组网技术方案