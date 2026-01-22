# 卡片创建规格

**版本**：1.0.0
**状态**：生效中
**依赖**：[pool_model.md](pool_model.md)、[device_config.md](device_config.md)
**相关测试**：`rust/tests/card_store_test.rs`

---

## 概述

本规格定义了 CardMind 系统中卡片创建的需求，确保新卡片自动关联到设备已加入的池，并在设备间同步。

本示例聚焦于系统的稳定现状描述，不包含任何变更过程叙述。

---

## 需求：自动关联已加入池

当用户创建新卡片时，系统应自动将卡片关联到设备已加入的池。

### 场景：在已加入池中成功创建卡片

- **前置条件**：设备已加入一个池
- **操作**：用户创建包含标题和内容的新卡片
- **预期结果**：卡片应使用唯一的 UUID v7 标识符创建
- **并且**：卡片应添加到已加入池的卡片列表
- **并且**：该池中的所有设备应可见该卡片

### 场景：未加入池时拒绝创建卡片

- **前置条件**：设备未加入任何池
- **操作**：用户尝试创建新卡片
- **预期结果**：系统应以错误码 `NO_POOL_JOINED` 拒绝请求
- **并且**：不应创建任何卡片

---

## 需求：唯一标识符生成

系统应为每个新创建的卡片生成唯一的 UUID v7 标识符。

### 场景：生成时间可排序的 UUID

- **前置条件**：系统准备创建新卡片
- **操作**：卡片创建过程开始
- **预期结果**：应使用当前时间戳生成 UUID v7
- **并且**：UUID 应全局唯一
- **并且**：UUID 应可按创建时间进行字典序排序

---

## 需求：实时同步

当卡片创建时，系统应在 2 秒内将新卡片同步到同一池中的所有已连接设备。

### 场景：将新卡片同步到已连接的对等设备

- **前置条件**：多个设备连接到同一个池
- **操作**：设备 A 创建新卡片
- **预期结果**：卡片应在 2 秒内出现在设备 B 上
- **并且**：卡片在所有设备上应具有相同的 UUID
- **并且**：卡片在所有设备上应具有相同的内容

---

## 测试覆盖

**测试文件**：`rust/tests/card_creation_spec.rs`

**单元测试**：
- `it_should_create_card_with_uuid_v7()` - 验证 UUID v7 生成
- `it_should_add_card_to_joined_pool()` - 验证池关联
- `it_should_reject_creation_without_joined_pool()` - 验证错误处理
- `it_should_generate_unique_uuids_for_concurrent_creates()` - 验证唯一性

**集成测试**：
- `it_should_sync_new_card_across_devices()` - 验证 P2P 同步
- `it_should_persist_card_to_sqlite()` - 验证持久化
- `it_should_update_loro_document()` - 验证 CRDT 更新

**验收标准**：
- [x] 所有单元测试通过
- [x] 所有集成测试通过
- [x] 同步延迟 < 2 秒
- [x] 代码审查通过
- [x] 文档已更新

---

## 相关文档

**架构决策记录**：
- [ADR-0001: 单池所有权](../adr/0001-single-pool-ownership.md)
- [ADR-0002: 双层架构](../adr/0002-dual-layer-architecture.md)

**相关规格**：
- [pool_model.md](pool_model.md) - 池模型规格
- [device_config.md](device_config.md) - 设备配置
- [sync_protocol.md](sync_protocol.md) - 同步协议

---

**最后更新**：2026-01-23
**作者**：CardMind Team
