# 通用类型系统规格

**版本**: 1.0.0
**状态**: 活跃
**依赖**: 无
**相关测试**: `rust/tests/common_types_spec.rs`

---

## 概述

本规格定义了在所有 CardMind 规格中使用的可重用数据类型和约束。它确保了整个系统中数据建模的一致性。

---

## 需求：唯一标识符类型

系统应为分布式系统提供全局唯一标识符。

**定义**: UniqueIdentifier

**要求**:
- 无需集中协调即可全局唯一
- 按时间排序（可按创建时间排序）
- 128 位长度
- 碰撞概率 < 10^-15

**实现**: UUID v7

**示例**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f`

**用途**: `Card.id`, `Pool.id`, `DeviceConfig.device_id`

---

## 需求：可选文本类型

系统应提供可为空或空字符串的 UTF-8 编码字符串类型。

**定义**: OptionalText

**约束**:
- 可为 null 或空字符串
- 最大长度：256 个 Unicode 字符（非字节）
- 不得包含控制字符（例如 `\0`）

**用途**: `Card.title`, `Pool.name`

---

## 需求：Markdown 文本类型

系统应提供使用 CommonMark Markdown 格式化的内容类型。

**定义**: MarkdownText

**支持的功能**:
- 标题（H1-H6）
- 列表（有序、无序）
- 代码块（带语法高亮）
- 内联代码
- 引用块
- 链接
- 表格
- 粗体、斜体、删除线

**约束**:
- 不能为空字符串（至少一个空格）
- 无最大长度限制（受系统性能限制）

**用途**: `Card.content`

---

## 需求：时间戳类型

系统应为时间相关字段提供以毫秒为单位的 Unix 时间戳。

**定义**: Timestamp

**格式**: Unix 纪元毫秒

**精度**: 毫秒（1/1000 秒）

**时区**: UTC

**示例**: `1704067200000` (2024-01-01 00:00:00 UTC)

**约束**:
- 非负整数
- 范围：1970-01-01 到 2262-04-11

**用途**: `Card.created_at`, `Card.updated_at`, `Pool.created_at`

---

## 需求：域术语

系统应定义整个应用程序中使用的标准术语。

| 术语
|------|------|
| **Card**
| **Pool**
| **Device**
| **Member**
| **Sync**
| **CRDT**

---

## 需求：引用完整性

系统应在数据结构之间强制执行引用完整性约束。

### 约束：池引用有效性

- **前置条件**：DeviceConfig.pool_id 已设置
- **预期结果**：它必须引用现有的 Pool

### 约束：卡片-池绑定一致性

- **前置条件**：Pool.card_ids 包含卡片 ID
- **预期结果**：SQLite card_pool_bindings 表必须有相应条目

---

## 需求：时间戳一致性

系统应强制执行时间戳一致性规则。

### 约束：创建早于更新

- **前置条件**：任何具有 created_at 和 updated_at 的实体
- **预期结果**：`created_at <= updated_at` 必须始终为真

### 约束：自动更新时间戳

- **前置条件**：实体被修改
- **预期结果**：updated_at 必须自动更新

### 约束：UTC 时区

- **前置条件**：任何时间戳字段
- **预期结果**：它必须使用 UTC 时区

---

## 需求：软删除

系统应支持卡片的软删除。

### 约束：软删除的卡片不在默认查询中

- **前置条件**：is_deleted = true 的卡片
- **预期结果**：卡片不应出现在默认查询中

### 约束：软删除的卡片可以恢复

- **前置条件**：软删除的卡片
- **预期结果**：可通过设置 is_deleted = false 恢复卡片

---

## 测试覆盖

**测试文件**: `rust/tests/common_types_spec.rs`

**单元测试**:
- `it_should_generate_valid_uuid_v7()` - 验证唯一标识符
- `it_should_enforce_optional_text_constraints()` - 验证可选文本
- `it_should_support_markdown_features()` - 验证 Markdown 文本
- `it_should_handle_timestamps_correctly()` - 验证时间戳
- `it_should_enforce_referential_integrity()` - 引用完整性
- `it_should_enforce_timestamp_consistency()` - 时间戳一致性
- `it_should_support_soft_delete()` - 软删除

**验收标准**:
- [ ] 所有类型约束均已验证
- [ ] 引用完整性已强制执行
- [ ] 时间戳一致性已维护
- [ ] 软删除按预期工作
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [pool/model.md](pool/model.md) - 使用 Card 和 Pool 类型
- [../architecture/storage/device_config.md](../architecture/storage/device_config.md) - 使用 DeviceConfig 类型
- [../architecture/storage/card_store.md](../architecture/storage/card_store.md) - 使用 Card 和 Pool 类型
- [../architecture/sync/service.md](../architecture/sync/service.md) - 使用时间戳类型

- [../api/api_spec.md](../api/api_spec.md) - API 字段类型

---

**最后更新**: 2026-01-23

**作者**: CardMind Team
