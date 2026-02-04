# CardMind 规格文档

本文档定义 CardMind 系统的核心领域模型、架构设计和实现规范。

## 领域模型（Domain）

定义业务实体和规则：

- [卡片模型](domain/card.md) - 卡片实体定义、生命周期、业务规则
- [池模型](domain/pool.md) - 池和设备实体、单池约束、成员管理
- [同步模型](domain/sync.md) - 同步领域模型、冲突解决
- [通用类型](domain/types.md) - 共享类型定义

## 架构（Architecture）

定义技术实现方案：

### 存储架构
- [双层架构](architecture/storage/dual_layer.md) - Loro + SQLite 双层存储设计
- [卡片存储](architecture/storage/card_store.md) - 卡片存储实现
- [池存储](architecture/storage/pool_store.md) - 池存储实现
- [设备配置](architecture/storage/device_config.md) - 设备配置存储
- [SQLite 缓存](architecture/storage/sqlite_cache.md) - 查询缓存层

### 同步架构
- [同步服务](architecture/sync/service.md) - P2P 同步服务
- [节点发现](architecture/sync/peer_discovery.md) - mDNS 对等发现
- [冲突解决](architecture/sync/conflict_resolution.md) - CRDT 冲突处理

### 安全架构
- [密码管理](architecture/security/password.md) - bcrypt 密码管理
- [密钥存储](architecture/security/keyring.md) - Keyring 密钥存储


- [API 规格](../../openspec/specs/api/api_spec.md) - Rust API 统一接口定义

## 功能规格（Features）

用户功能详细规格：

- [卡片管理](features/card_management/) - 卡片创建、编辑、删除
- [池管理](features/pool_management/) - 池加入、退出、管理
- [P2P 同步](features/p2p_sync/) - 点对点同步功能
- [搜索过滤](features/search_and_filter/) - 全文搜索和筛选
- [设置](features/settings/) - 应用设置

（共 19 个功能规格）


界面组件和交互设计：

- [screens/](ui/screens/) - 屏幕页面规格
- [components/](ui/components/) - 组件规格
- [adaptive/](ui/adaptive/) - 自适应布局

（共 4 个 UI 目录，包含 30+ 个 UI 规格）

---

## 维护说明

本文档采用 Superpowers 工作流维护：

1. **开发前**：先更新本文档中的相关规格
2. **格式**：使用中文撰写，采用 GIVEN-WHEN-THEN 场景描述
3. **一致性**：代码实现必须与规格保持一致
4. **测试**：测试用例必须覆盖规格中的场景

### 更新流程

```
/brainstorm 新功能
  ↓
生成 docs/plans/ 计划文档
  ↓
明确涉及的 specs 文件
  ↓
更新 docs/specs/ 相关规格（必须）
  ↓
编码实现
  ↓
验证测试
  ↓
归档计划到 docs/archive/
```
