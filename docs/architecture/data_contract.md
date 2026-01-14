# 数据契约 (Data Contract)

> **设计哲学**: 本文档定义"数据类型和约束"，不包含具体字段定义。
> 详细字段定义请查看 [单池模型规格](../specs/rust/single_pool_model_spec.md)。

---

## 1. 类型系统

### 1.1 UniqueIdentifier (唯一标识符)

**要求**:
- 分布式环境下全局唯一，无需中心化协调
- 支持按创建时间排序（时间有序）
- 128 位长度
- 冲突概率极低 (< 10^-15)

**技术实现**: UUID v7

**示例值**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f`

---

### 1.2 OptionalText (可选文本)

**格式**: UTF-8 编码字符串

**约束**:
- 可为空 (null 或空字符串)
- 最大长度: 256 字符 (Unicode 字符，非字节)
- 不包含控制字符 (如 `\0`)

---

### 1.3 MarkdownText (Markdown文本)

**格式**: 符合 CommonMark 规范的 Markdown 文本

**支持特性**:
- 标题 (H1-H6)
- 列表 (有序、无序)
- 代码块 (带语法高亮)
- 行内代码
- 引用块
- 链接
- 表格
- 加粗、斜体、删除线

**约束**:
- 不能为空字符串 (至少一个空格)
- 最大长度: 无限制 (由系统性能决定)

---

### 1.4 Timestamp (时间戳)

**格式**: Unix 时间戳 (毫秒级)

**精度**: 毫秒 (1/1000 秒)

**时区**: UTC

**示例值**: `1704067200000` (2024-01-01 00:00:00 UTC)

**约束**:
- 非负整数
- 范围: 1970-01-01 至 2262-04-11

---

## 2. 领域术语

| 术语 | 描述 |
|------|------|
| **卡片 (Card)** | 笔记的基本单元，包含标题和Markdown内容 |
| **数据池 (Pool)** | 单个用户的笔记空间，包含多个卡片 |
| **设备 (Device)** | 运行CardMind的终端设备 |
| **成员 (Member)** | 已加入数据池的设备 |

---

## 3. 详细定义 (链接)

### 3.1 卡片模型
- 字段定义 → [单池模型规格 - Card模型](../specs/rust/single_pool_model_spec.md#21-card-模型)
- 不变式 → 同上
- 生命周期 → 同上

### 3.2 数据池模型
- 字段定义 → [单池模型规格 - Pool模型](../specs/rust/single_pool_model_spec.md#21-pool-模型真理源)
- 成员管理 → [Pool CRUD规格](../specs/rust/pool_model_spec.md)

### 3.3 设备配置模型
- 字段定义 → [DeviceConfig规格](../specs/rust/device_config_spec.md)
- 单池约束 → 同上

### 3.4 代码实现
- 运行 `cargo doc --open` 查看 Rust 结构体
- 源码位置: `rust/src/models/`

---

## 4. 数据完整性

### 4.1 引用完整性

- DeviceConfig.pool_id 必须存在于 Pool 文档集合中
- Pool.card_ids 必须与 SQLite `card_pool_bindings` 表保持一致

### 4.2 时间戳一致性

- `created_at <= updated_at` (始终成立)
- `updated_at` 在每次修改时自动更新
- 时间戳使用 UTC

### 4.3 软删除

- 软删除的卡片 (`is_deleted = true`) 不出现在默认查询中
- 软删除的卡片可以恢复

---

## 5. 相关文档

### 架构文档
- [系统设计](./system_design.md) - 双层架构原则
- [层分离策略](./layer_separation.md) - 分层详细说明
- [同步机制](./sync_mechanism.md) - 订阅驱动更新原理

### Spec文档
- [单池模型核心规格](../specs/rust/single_pool_model_spec.md) - 数据模型完整定义
- [Pool CRUD规格](../specs/rust/pool_model_spec.md) - 池操作规范
- [DeviceConfig规格](../specs/rust/device_config_spec.md) - 设备配置规范
- [API层规格](../specs/rust/api_spec.md) - API字段定义

### 代码
- 运行 `cargo doc --open` 查看 Rust API 文档
- 源码位置: `rust/src/models/`

---

## 6. 更新日志

| 版本 | 变更 |
|------|------|
| 1.2.0 | 重构：移除字段详细定义，链接到规格文档 |
| 1.1.0 | 适配单池模型：简化设备配置契约 |
| 1.0.0 | 初始版本 |

---

**设计原则**: 本文档定义类型系统和使用约束，具体的字段定义随实现变化，应以规格文档为准。
