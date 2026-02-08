# 通用类型系统规格

## 概述

本规格定义了在所有 CardMind 规格中使用的可重用数据类型和约束，确保系统内数据建模一致性。

**技术栈**:
- **uuid** = "1.6" - UUID v7 生成
- **chrono** = "0.4" - 时间戳处理
- **serde** = "1.0" - 序列化/反序列化

**核心类型**:
- UniqueIdentifier (UUID v7)
- OptionalText (可选字符串)
- MarkdownText (Markdown 内容)
- Timestamp (Unix 毫秒)

---

## 需求：唯一标识符类型

系统应为分布式系统提供全局唯一标识符。

### 场景：生成与校验唯一标识符

- **前置条件**: 需要为 Card/Pool/Device 生成 ID
- **操作**: 生成并校验唯一标识符
- **预期结果**: 标识符全局唯一且可按时间排序
- **并且**: 标识符满足 UUID v7 格式约束

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

### 场景：校验与清理可选文本

- **前置条件**: 需要存储标题或名称
- **操作**: 校验并清理可选文本
- **预期结果**: 文本满足长度与字符约束
- **并且**: 允许 null 或空字符串

**定义**: OptionalText

**约束**:
- 可为 null 或空字符串
- 最大长度：256 个 Unicode 字符（非字节）
- 不得包含控制字符（例如 `\0`）

**用途**: `Card.title`, `Pool.name`

---

## 需求：Markdown 文本类型

系统应提供使用 CommonMark Markdown 格式化的内容类型。

### 场景：校验 Markdown 文本

- **前置条件**: 需要存储卡片内容
- **操作**: 校验 Markdown 文本
- **预期结果**: 文本非空且包含至少一个非空白字符
- **并且**: 支持常见 Markdown 语法

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

### 场景：生成与校验时间戳

- **前置条件**: 需要记录创建/更新时间
- **操作**: 生成并校验时间戳
- **预期结果**: 时间戳为 UTC 毫秒且在合法范围内
- **并且**: 时间戳格式可被序列化/反序列化

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

## 需求：引用完整性

系统应在数据结构之间强制执行引用完整性约束。

### 场景：校验池引用有效性

- **前置条件**: DeviceConfig.pool_id 已设置
- **操作**: 验证池引用
- **预期结果**: pool_id 必须引用现有的 Pool
- **并且**: 设备必须属于该池

### 场景：校验卡片-池绑定一致性

- **前置条件**: Pool.card_ids 包含卡片 ID
- **操作**: 验证绑定一致性
- **预期结果**: SQLite card_pool_bindings 表必须有相应条目

---

## 需求：时间戳一致性

系统应强制执行时间戳一致性规则。

### 场景：创建早于更新

- **前置条件**: 任何具有 created_at 和 updated_at 的实体
- **操作**: 校验时间戳一致性
- **预期结果**: `created_at <= updated_at` 必须始终为真

### 场景：自动更新时间戳

- **前置条件**: 实体被修改
- **操作**: 更新时间戳
- **预期结果**: updated_at 必须自动更新

### 场景：UTC 时区

- **前置条件**: 任何时间戳字段
- **操作**: 确保统一时区
- **预期结果**: 时间戳必须使用 UTC 时区

---

## 需求：软删除

系统应支持卡片的软删除。

### 场景：软删除的卡片不在默认查询中

- **前置条件**: is_deleted = true 的卡片
- **操作**: 默认查询卡片列表
- **预期结果**: 卡片不应出现在默认查询中

### 场景：软删除的卡片可以恢复

- **前置条件**: 软删除的卡片
- **操作**: 恢复卡片
- **预期结果**: is_deleted = false

---

## 补充说明

**类型定义**:

**验证规则**:
- **UniqueIdentifier**: 必须是有效的 UUID v7 格式
- **OptionalText**: 最大 256 Unicode 字符,无控制字符
- **MarkdownText**: 不能为空,支持 CommonMark
- **Timestamp**: 非负整数,UTC 时区

**约束强制**:
- **引用完整性**: 应用层验证
- **时间戳一致性**: 自动更新机制
- **软删除**: 查询层过滤

---

## 相关文档

**领域规格**:
- [card.md](card.md) - 使用 Card 类型
- [pool.md](pool.md) - 使用 Pool 类型
- [sync.md](sync.md) - 使用时间戳类型

**架构规格**:
- [../architecture/storage/device_config.md](../architecture/storage/device_config.md) - 使用 DeviceConfig 类型
- [../architecture/storage/card_store.md](../architecture/storage/card_store.md) - 使用 Card 和 Pool 类型
- [../architecture/sync/service.md](../architecture/sync/service.md) - 使用时间戳类型

---

## 测试覆盖

**测试文件**: `rust/tests/common_types_feature_test.rs`

**单元测试**:
- `it_should_generate_valid_uuid_v7()` - 验证唯一标识符
- `it_should_enforce_optional_text_constraints()` - 验证可选文本
- `it_should_support_markdown_features()` - 验证 Markdown 文本
- `it_should_handle_timestamps_correctly()` - 验证时间戳
- `it_should_enforce_referential_integrity()` - 引用完整性
- `it_should_enforce_timestamp_consistency()` - 时间戳一致性
- `it_should_support_soft_delete()` - 软删除
- `it_should_validate_uuid_format()` - UUID 格式验证
- `it_should_sanitize_text()` - 文本清理
- `it_should_parse_markdown()` - Markdown 解析
- `it_should_format_timestamps()` - 时间戳格式化
- `it_should_repair_bindings()` - 绑定修复

**功能测试**:
- `test_type_system_integration()` - 类型系统集成
- `test_constraint_enforcement()` - 约束强制执行
- `test_data_consistency()` - 数据一致性

**验收标准**:
- [x] 所有类型约束均已验证
- [x] 引用完整性已强制执行
- [x] 时间戳一致性已维护
- [x] 软删除按预期工作
- [x] UUID v7 时间排序正确
- [x] 代码审查通过
