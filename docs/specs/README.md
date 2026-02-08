# CardMind 规格文档

## 概述

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
- [Loro 集成](architecture/storage/loro_integration.md) - Loro 集成与持久化

### 同步架构
- [同步服务](architecture/sync/service.md) - P2P 同步服务
- [节点发现](architecture/sync/peer_discovery.md) - mDNS 对等发现
- [订阅同步](architecture/sync/subscription.md) - 同步订阅与事件处理
- [冲突解决](architecture/sync/conflict_resolution.md) - CRDT 冲突处理

### 安全架构
- [secretkey 管理](architecture/security/password.md) - SHA-256 明文校验
- [隐私保护](architecture/security/privacy.md) - 隐私保护策略


- [API 文档](../../doc/api/) - Rust API 参考文档

## 功能规格（Features）

用户功能详细规格：

- [卡片功能](features/card/) - 卡片增删改查、标签、搜索过滤
- [数据池功能](features/pool/) - 池创建/加入/退出、成员、同步、发现
- [设置功能](features/settings/) - 外观、设备、本地数据管理、应用信息

（共 3 个功能模块）


界面组件和交互设计：

- [screens/](ui/screens/) - 屏幕页面规格
- [components/](ui/components/) - 组件规格
- [adaptive/](ui/adaptive/) - 自适应布局

（共 3 个 UI 目录，包含 30+ 个 UI 规格）

---

## 测试分类与覆盖率定义

- **单元测试**：面向逻辑代码的单模块验证（不跨多层调用）
- **功能测试**：跨模块/多层行为验证；规格测试默认归为功能测试

**单元测试覆盖率**：
- 统计规则：公开项数量与对应单元测试数量之比
- 阈值：≥ 90%
- 计数范围：
  - Rust：`rust/src` 逻辑代码（排除生成文件）
  - Flutter：`lib/models|services|utils|providers|constants`（排除 `lib/bridge` 与生成文件）

---

## 维护说明

本文档采用 Superpowers 工作流维护：

1. **开发前**：先更新本文档中的相关规格
2. **功能变更**：先更新规格文档，再更新测试，最后修改实现代码
3. **格式**：使用中文撰写，采用 GIVEN-WHEN-THEN 场景描述
4. **一致性**：代码实现必须与规格保持一致
5. **测试**：测试用例必须覆盖规格中的场景

### 更新流程
