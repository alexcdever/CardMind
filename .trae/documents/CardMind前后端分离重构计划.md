# CardMind前后端分离重构计划

## 1. 重构目标

将当前的"前端包干所有活，后端只负责信令服务"架构，重构成标准的Web前后端分离架构，实现：

* 后端负责业务逻辑、数据存储和API提供

* 前端负责用户界面和用户交互

* 前后端通过HTTP API进行通信

## 2. 重构原则

* **业务逻辑后端化**：将核心业务逻辑从前端转移到后端

* **API驱动开发**：后端提供完整的RESTful API

* **数据一致性**：确保前后端数据同步和一致性

* **保持实时同步**：保留WebRTC实时同步功能

* **渐进式重构**：逐步迁移功能，确保系统稳定性

## 3. 代码结构调整

### 3.1 后端代码结构（保持不变）

```
signaling-server/
├── src/
│   ├── controllers/      # 新增：API控制器
│   ├── services/         # 新增：业务逻辑服务
│   ├── models/           # 新增：数据模型
│   ├── middlewares/      # 新增：中间件
│   ├── config/           # 新增：配置文件
│   ├── access-code-utils.js
│   ├── device-utils.js
│   ├── server.js
│   └── yjs-document-manager.js
├── package.json
└── tsconfig.json         # 新增：TypeScript配置
```

### 3.2 前端代码结构（简化）

```
src/
├── components/           # React组件
├── services/             # 前端服务（API调用、本地缓存）
├── stores/               # 状态管理
├── types/                # 类型定义
├── utils/                # 工具函数
└── App.tsx
```

## 4. 后端API设计

### 4.1 卡片管理API

* `GET /api/cards` - 获取所有卡片

* `GET /api/cards/:id` - 获取单个卡片

* `POST /api/cards` - 创建卡片

* `PUT /api/cards/:id` - 更新卡片

* `DELETE /api/cards/:id` - 删除卡片（软删除）

* `POST /api/cards/:id/restore` - 恢复卡片

* `GET /api/cards/deleted` - 获取已删除卡片

* `POST /api/cards/batch-delete` - 批量删除卡片

* `POST /api/cards/batch-restore` - 批量恢复卡片

* `GET /api/cards/search` - 搜索卡片

* `GET /api/cards/filter` - 筛选卡片

### 4.2 Yjs文档管理API

* `GET /api/documents` - 获取活跃文档列表

* `GET /api/documents/:networkId` - 获取文档状态

* `POST /api/documents/:networkId` - 创建或加入文档

* `DELETE /api/documents/:networkId` - 删除文档

### 4.3 设备管理API

* `POST /api/device/fingerprint` - 生成设备指纹

* `POST /api/device/register` - 注册设备

* `GET /api/device/:id` - 获取设备信息

### 4.4 网络管理API

* `POST /api/networks` - 创建网络

* `GET /api/networks/:id` - 获取网络信息

* `GET /api/networks/:id/devices` - 获取网络设备列表

### 4.5 Access Code API

* `POST /api/access-code` - 生成Access Code

* `POST /api/access-code/parse` - 解析Access Code

## 5. 数据流向设计

### 5.1 正常流程

```
前端 → HTTP API → 后端控制器 → 后端服务 → 数据库/Yjs文档 → 后端服务 → 后端控制器 → HTTP API → 前端
```

### 5.2 实时同步流程

```
前端A → WebSocket → 后端信令服务 → WebSocket → 前端B
前端A → Yjs更新 → 后端Yjs管理器 → Yjs更新 → 前端B
```

## 6. 重构步骤

### 步骤1：后端基础架构搭建

* 安装必要的依赖（TypeScript、Express、Mongoose等）

* 配置TypeScript编译

* 搭建Express服务器基础架构

* 配置中间件（CORS、日志、错误处理等）

### 步骤2：后端API开发

* 实现卡片管理API

* 实现Yjs文档管理API

* 实现设备管理API

* 实现网络管理API

* 实现Access Code API

### 步骤3：前端代码调整

* 简化前端业务逻辑

* 实现API调用服务

* 实现本地缓存机制

* 调整状态管理

### 步骤4：数据迁移

* 设计数据迁移方案

* 实现数据迁移脚本

* 测试数据迁移

### 步骤5：集成测试

* 测试前后端API通信

* 测试实时同步功能

* 测试离线支持

* 测试跨设备同步

### 步骤6：部署和监控

* 配置部署环境

* 实现日志和监控

* 配置CI/CD流程

## 7. 注意事项

### 7.1 保持向后兼容

* 确保重构后的API与现有前端代码兼容

* 提供API版本控制

### 7.2 性能优化

* 实现API缓存

* 优化数据库查询

* 实现分页和限流

### 7.3 安全性

* 实现用户认证和授权

* 配置HTTPS

* 实现输入验证和输出过滤

### 7.4 测试覆盖

* 编写单元测试

* 编写集成测试

* 编写端到端测试

## 8. 预期效果

* **更好的代码组织**：前后端职责明确，代码结构清晰

* **更好的可维护性**：业务逻辑集中在后端，便于维护和扩展

* **更好的性能**：后端优化数据库查询和缓存

* **更好的安全性**：后端实现认证和授权

* **更好的扩展性**：便于添加新功能和支持更多平台

## 9. 结论

根据前后端分离的原则，我们不需要将`/d:/Projects/CardMind/signaling-server/src`里的业务代码转移到`/d:/Projects/CardMind/signaling-server`里，而是应该：

1. 在`signaling-server/src`目录下扩展后端架构，添加控制器、服务、模型等目录
2. 实现完整的RESTful API
3. 简化前端业务逻辑，改为调用后端API
4. 保持WebRTC信令服务和Yjs文档管理不变
5. 实现前后端通过HTTP API进行通信

这样可以实现标准的Web前后端分离架构，同时保持系统的实时同步功能。
