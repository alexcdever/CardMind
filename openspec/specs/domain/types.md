# Common Type System Specification
# 通用类型系统规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: None
**依赖**: 无
**Related Tests**: `rust/tests/common_types_spec.rs`
**相关测试**: `rust/tests/common_types_spec.rs`

---

## Overview
## 概述

This specification defines reusable data types and constraints used across all CardMind specifications. It ensures consistency in data modeling across the system.

本规格定义了在所有 CardMind 规格中使用的可重用数据类型和约束。它确保了整个系统中数据建模的一致性。

---

## Requirement: Unique identifier type
## 需求：唯一标识符类型

The system SHALL provide a globally unique identifier for distributed systems.

系统应为分布式系统提供全局唯一标识符。

**Definition**: UniqueIdentifier
**定义**: UniqueIdentifier

**Requirements**:
**要求**:
- Globally unique without centralized coordination
- 无需集中协调即可全局唯一
- Time-ordered (sortable by creation time)
- 按时间排序（可按创建时间排序）
- 128-bit length
- 128 位长度
- Collision probability < 10^-15
- 碰撞概率 < 10^-15

**Implementation**: UUID v7
**实现**: UUID v7

**Example**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f`
**示例**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f`

**Usage**: `Card.id`, `Pool.id`, `DeviceConfig.device_id`
**用途**: `Card.id`, `Pool.id`, `DeviceConfig.device_id`

---

## Requirement: Optional text type
## 需求：可选文本类型

The system SHALL provide a UTF-8 encoded string type that may be null or empty.

系统应提供可为空或空字符串的 UTF-8 编码字符串类型。

**Definition**: OptionalText
**定义**: OptionalText

**Constraints**:
**约束**:
- May be null or empty string
- 可为 null 或空字符串
- Maximum length: 256 Unicode characters (not bytes)
- 最大长度：256 个 Unicode 字符（非字节）
- Must not contain control characters (e.g., `\0`)
- 不得包含控制字符（例如 `\0`）

**Usage**: `Card.title`, `Pool.name`
**用途**: `Card.title`, `Pool.name`

---

## Requirement: Markdown text type
## 需求：Markdown 文本类型

The system SHALL provide a content type formatted with CommonMark Markdown.

系统应提供使用 CommonMark Markdown 格式化的内容类型。

**Definition**: MarkdownText
**定义**: MarkdownText

**Supported Features**:
**支持的功能**:
- Headings (H1-H6)
- 标题（H1-H6）
- Lists (ordered, unordered)
- 列表（有序、无序）
- Code blocks (with syntax highlighting)
- 代码块（带语法高亮）
- Inline code
- 内联代码
- Blockquotes
- 引用块
- Links
- 链接
- Tables
- 表格
- Bold, italic, strikethrough
- 粗体、斜体、删除线

**Constraints**:
**约束**:
- Cannot be empty string (at least one space)
- 不能为空字符串（至少一个空格）
- No maximum length (limited by system performance)
- 无最大长度限制（受系统性能限制）

**Usage**: `Card.content`
**用途**: `Card.content`

---

## Requirement: Timestamp type
## 需求：时间戳类型

The system SHALL provide a Unix timestamp in milliseconds for time-related fields.

系统应为时间相关字段提供以毫秒为单位的 Unix 时间戳。

**Definition**: Timestamp
**定义**: Timestamp

**Format**: Unix epoch milliseconds
**格式**: Unix 纪元毫秒

**Precision**: Millisecond (1/1000 second)
**精度**: 毫秒（1/1000 秒）

**Timezone**: UTC
**时区**: UTC

**Example**: `1704067200000` (2024-01-01 00:00:00 UTC)
**示例**: `1704067200000` (2024-01-01 00:00:00 UTC)

**Constraints**:
**约束**:
- Non-negative integer
- 非负整数
- Range: 1970-01-01 to 2262-04-11
- 范围：1970-01-01 到 2262-04-11

**Usage**: `Card.created_at`, `Card.updated_at`, `Pool.created_at`
**用途**: `Card.created_at`, `Card.updated_at`, `Pool.created_at`

---

## Requirement: Domain terminology
## 需求：域术语

The system SHALL define standard terminology used throughout the application.

系统应定义整个应用程序中使用的标准术语。

| Term | English Description | 术语 | 中文描述 |
|------|---------------------|------|----------|
| **Card** | Basic note unit containing title and Markdown content | **卡片** | 包含标题和 Markdown 内容的基本笔记单元 |
| **Pool** | Single user's note space containing multiple cards | **池** | 包含多张卡片的单个用户笔记空间 |
| **Device** | Terminal running CardMind | **设备** | 运行 CardMind 的终端 |
| **Member** | Device that has joined a pool | **成员** | 已加入池的设备 |
| **Sync** | P2P data synchronization between devices | **同步** | 设备间的 P2P 数据同步 |
| **CRDT** | Conflict-free Replicated Data Type | **CRDT** | 无冲突复制数据类型 |

---

## Requirement: Referential integrity
## 需求：引用完整性

The system SHALL enforce referential integrity constraints across data structures.

系统应在数据结构之间强制执行引用完整性约束。

### Constraint: Pool reference validity
### 约束：池引用有效性

- **GIVEN** DeviceConfig.pool_id is set
- **前置条件**：DeviceConfig.pool_id 已设置
- **THEN** it MUST reference an existing Pool
- **预期结果**：它必须引用现有的 Pool

### Constraint: Card-pool binding consistency
### 约束：卡片-池绑定一致性

- **GIVEN** Pool.card_ids contains a card ID
- **前置条件**：Pool.card_ids 包含卡片 ID
- **THEN** SQLite card_pool_bindings table MUST have corresponding entry
- **预期结果**：SQLite card_pool_bindings 表必须有相应条目

---

## Requirement: Timestamp consistency
## 需求：时间戳一致性

The system SHALL enforce timestamp consistency rules.

系统应强制执行时间戳一致性规则。

### Constraint: Creation before update
### 约束：创建早于更新

- **GIVEN** any entity with created_at and updated_at
- **前置条件**：任何具有 created_at 和 updated_at 的实体
- **THEN** `created_at <= updated_at` MUST always be true
- **预期结果**：`created_at <= updated_at` 必须始终为真

### Constraint: Automatic update timestamp
### 约束：自动更新时间戳

- **GIVEN** an entity is modified
- **前置条件**：实体被修改
- **THEN** updated_at MUST be automatically updated
- **预期结果**：updated_at 必须自动更新

### Constraint: UTC timezone
### 约束：UTC 时区

- **GIVEN** any timestamp field
- **前置条件**：任何时间戳字段
- **THEN** it MUST use UTC timezone
- **预期结果**：它必须使用 UTC 时区

---

## Requirement: Soft delete
## 需求：软删除

The system SHALL support soft delete for cards.

系统应支持卡片的软删除。

### Constraint: Soft-deleted cards not in default queries
### 约束：软删除的卡片不在默认查询中

- **GIVEN** a card with is_deleted = true
- **前置条件**：is_deleted = true 的卡片
- **THEN** the card SHALL NOT appear in default queries
- **预期结果**：卡片不应出现在默认查询中

### Constraint: Soft-deleted cards can be recovered
### 约束：软删除的卡片可以恢复

- **GIVEN** a soft-deleted card
- **前置条件**：软删除的卡片
- **THEN** the card SHALL be recoverable by setting is_deleted = false
- **预期结果**：可通过设置 is_deleted = false 恢复卡片

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/common_types_spec.rs`
**测试文件**: `rust/tests/common_types_spec.rs`

**Unit Tests**:
**单元测试**:
- `it_should_generate_valid_uuid_v7()` - Validate UniqueIdentifier
- 验证唯一标识符
- `it_should_enforce_optional_text_constraints()` - Validate OptionalText
- 验证可选文本
- `it_should_support_markdown_features()` - Validate MarkdownText
- 验证 Markdown 文本
- `it_should_handle_timestamps_correctly()` - Validate Timestamp
- 验证时间戳
- `it_should_enforce_referential_integrity()` - Referential integrity
- 引用完整性
- `it_should_enforce_timestamp_consistency()` - Timestamp consistency
- 时间戳一致性
- `it_should_support_soft_delete()` - Soft delete
- 软删除

**Acceptance Criteria**:
**验收标准**:
- [ ] All type constraints are validated
- [ ] 所有类型约束均已验证
- [ ] Referential integrity is enforced
- [ ] 引用完整性已强制执行
- [ ] Timestamp consistency is maintained
- [ ] 时间戳一致性已维护
- [ ] Soft delete works as expected
- [ ] 软删除按预期工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [pool/model.md](pool/model.md) - Uses Card and Pool types
- 使用 Card 和 Pool 类型
- [../architecture/storage/device_config.md](../architecture/storage/device_config.md) - Uses DeviceConfig type
- 使用 DeviceConfig 类型
- [../architecture/storage/card_store.md](../architecture/storage/card_store.md) - Uses Card and Pool types
- 使用 Card 和 Pool 类型
- [../architecture/sync/service.md](../architecture/sync/service.md) - Uses timestamp types
- 使用时间戳类型

**API Spec**:
**API 规格**:
- [../api/api_spec.md](../api/api_spec.md) - API field types
- API 字段类型

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
