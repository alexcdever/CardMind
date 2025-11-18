# 技术类文档说明

本目录包含 CardMind 项目的技术文档，涵盖技术栈、架构设计、实现方案和跨平台兼容性等技术细节。

## 文档列表

### 核心技术文档
- **tech-stack.md** - 技术栈文档
  - 内容：前后端技术选型、开发工具、部署方案
  - 读者：全栈开发者、DevOps工程师
  - 作用：指导开发环境搭建和技术选型

- **tech-concepts.md** - 技术概念文档
  - 内容：核心概念解释、技术原理、设计模式
  - 读者：开发者、架构师
  - 作用：理解项目技术基础和设计理念

### 功能实现文档
- **implementation-plan.md** - 卡片功能实现
  - 内容：卡片CRUD功能实现、数据存储、同步机制
  - 读者：前端开发者、全栈开发者
  - 作用：指导核心功能开发

- **api-testing-design.md** - API测试设计
  - 内容：接口定义、测试用例、Mock数据
  - 读者：后端开发者、测试工程师
  - 作用：指导API开发和测试

### 组件与交互文档
- **component-definitions.md** - 组件定义
  - 内容：React组件结构、状态管理、Props接口
  - 读者：前端开发者
  - 作用：指导组件开发和复用

- **interaction-logic.md** - 交互逻辑
  - 内容：用户交互流程、事件处理、状态转换
  - 读者：前端开发者、产品经理
  - 作用：理解交互实现逻辑

### 架构设计文档
- **cross-platform-architecture.md** - 跨平台架构
  - 内容：多平台架构设计、代码复用策略
  - 读者：架构师、全栈开发者
  - 作用：指导跨平台开发

- **offline-lan-architecture.md** - 离线局域网架构
  - 内容：离线组网方案、P2P通信、设备发现
  - 读者：网络工程师、后端开发者
  - 作用：实现局域网多设备协作

- **local-signaling-server.md** - 本地信令服务器
  - 内容：信令服务设计、WebRTC连接建立
  - 读者：后端开发者、网络工程师
  - 作用：实现实时通信基础

- **cross-platform-compatibility.md** - 跨平台兼容性
  - 内容：平台差异处理、兼容性方案
  - 读者：全栈开发者、测试工程师
  - 作用：确保多平台一致性

- **pure-p2p-architecture.md** - 纯P2P架构
  - 内容：去中心化设计、数据同步策略
  - 读者：架构师、后端开发者
  - 作用：实现无中心节点协作

- **security-authentication.md** - 安全认证设计
  - 内容：身份认证、数据加密、安全策略
  - 读者：安全工程师、后端开发者
  - 作用：保障系统安全性

## 阅读建议

1. **入门开发者**：先阅读 `tech-stack.md` 和 `tech-concepts.md`
2. **前端开发者**：重点关注 `implementation-plan.md`、`component-definitions.md`
3. **后端开发者**：重点关注 `api-testing-design.md`、`offline-lan-architecture.md`
4. **架构师**：重点关注 `cross-platform-architecture.md`、`pure-p2p-architecture.md`

## 相关文档

- [项目需求文档](../01-requirements/requirements.md) - 了解功能需求
- [UI设计文档](../02-design/ui-design.md) - 查看界面设计
- [局域网互联测试](../04-testing/lan-interconnection-test.md) - 了解测试方案