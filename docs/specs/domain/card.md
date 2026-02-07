# 卡片领域模型规格

## 概述

本规格定义了 Card 领域实体，代表 CardMind 系统中的单个笔记卡片。每张卡片包含标题、Markdown 内容、元数据，并支持软删除。

**技术栈**:
- **uuid** = "1.6" - UUID v7 生成
- **serde** = "1.0" - 序列化/反序列化
- **chrono** = "0.4" - 时间戳处理

**核心特性**:
- UUID v7 时间有序标识符
- Markdown 格式内容存储
- 自动时间戳管理
- 标签系统
- 软删除支持
- 设备追踪

---

## 需求：卡片实体定义

系统应定义 Card 实体，包含以下核心属性。

### 场景：卡片包含必需属性

- **前置条件**: 创建一张卡片
- **操作**: 实例化卡片实体
- **预期结果**: 卡片应具有唯一标识符（UUID v7）
- **并且**: 卡片应具有标题（字符串）
- **并且**: 卡片应具有 Markdown 格式的内容（字符串）
- **并且**: 卡片应具有创建时间戳（Unix 毫秒）
- **并且**: 卡片应具有最后修改时间戳（Unix 毫秒）

### 场景：卡片包含可选属性

- **前置条件**: 卡片存在
- **操作**: 检查卡片
- **预期结果**: 卡片应具有删除标志（布尔值,默认 false）
- **并且**: 卡片应具有标签列表（Vec<String>,默认为空）
- **并且**: 卡片应具有可选的最后编辑设备标识符

---

## 需求：UUID v7 标识符

系统应使用 UUID v7（时间有序）作为卡片标识符。

### 场景：卡片 ID 按时间排序

- **前置条件**: 顺序创建两张卡片
- **操作**: 卡片 A 在卡片 B 之前创建
- **预期结果**: 卡片 A 的 ID 应在字典序上小于卡片 B 的 ID
- **并且**: ID 应按创建时间自然排序

---

## 需求：Markdown 内容支持

系统应以 Markdown 格式存储卡片内容。

### 场景：卡片内容为 Markdown

- **前置条件**: 创建一张卡片
- **操作**: 设置内容
- **预期结果**: 内容应以纯文本 Markdown 格式存储
- **并且**: 内容应支持标准 Markdown 语法

---

## 需求：时间戳管理

系统应自动管理创建和修改时间戳。

### 场景：自动设置创建时间戳

- **前置条件**: 创建新卡片
- **操作**: 实例化卡片
- **预期结果**: created_at 时间戳应设置为当前时间
- **并且**: updated_at 时间戳初始应等于 created_at

### 场景：修改时更新时间戳

- **前置条件**: 卡片存在
- **操作**: 修改卡片的标题、内容或标签
- **预期结果**: updated_at 时间戳应更新为当前时间
- **并且**: created_at 时间戳应保持不变

---

## 需求：标签管理

系统应支持为卡片添加和移除标签。

### 场景：为卡片添加标签

- **前置条件**: 卡片存在且没有特定标签
- **操作**: 为卡片添加标签
- **预期结果**: 标签应添加到卡片的标签列表
- **并且**: updated_at 时间戳应更新

### 场景：防止重复标签

- **前置条件**: 卡片已有特定标签
- **操作**: 再次添加相同标签
- **预期结果**: 标签不应在列表中重复
- **并且**: updated_at 时间戳不应更新

### 场景：从卡片移除标签

- **前置条件**: 卡片有特定标签
- **操作**: 移除标签
- **预期结果**: 标签应从卡片的标签列表中移除
- **并且**: updated_at 时间戳应更新

---

## 需求：软删除

系统应支持软删除卡片，而不是物理删除。

### 场景：软删除卡片

- **前置条件**: 卡片存在且未删除
- **操作**: 标记卡片为已删除
- **预期结果**: deleted 标志应设置为 true
- **并且**: updated_at 时间戳应更新
- **并且**: 卡片数据应保留

---

## 需求：设备追踪

系统应追踪哪个设备最后编辑了每张卡片。

### 场景：记录最后编辑设备

- **前置条件**: 在特定设备上编辑卡片
- **操作**: 设置设备标识符
- **预期结果**: last_edit_device 应设置为设备标识符
- **并且**: updated_at 时间戳应更新

---

## 补充说明

**数据结构**:
```rust
pub struct Card {
    pub id: String,                    // UUID v7
    pub title: String,                 // 卡片标题
    pub content: String,               // Markdown 内容
    pub created_at: i64,              // Unix 毫秒
    pub updated_at: i64,              // Unix 毫秒
    pub deleted: bool,                // 软删除标志
    pub tags: Vec<String>,            // 标签列表
    pub last_edit_device: Option<String>,  // 设备 ID
}
```

**设计模式**:
- **值对象模式**: Card 作为不可变实体
- **软删除模式**: 保留数据以支持恢复
- **时间戳模式**: 自动管理创建和修改时间

**验证规则**:
- **ID**: 必须是有效的 UUID v7 格式
- **标题**: 不能为空,最大 200 字符
- **内容**: 不能为空,必须包含至少一个非空白字符
- **标签**: 每个标签最大 50 字符,不允许重复
- **时间戳**: 必须是正整数,updated_at >= created_at

**性能特征**:
- **标签操作**: O(n) 其中 n 是标签数量

---

## 相关文档

**领域规格**:
- [pool.md](pool.md) - 池领域模型
- [sync.md](sync.md) - 同步领域模型
- [types.md](types.md) - 共享类型定义

**架构规格**:
- [../architecture/storage/card_store.md](../architecture/storage/card_store.md) - CardStore 实现
- [../architecture/storage/loro_integration.md](../architecture/storage/loro_integration.md) - Loro 集成

**实现**:
- `rust/src/models/card.rs` - Card 模型实现

---

## 测试覆盖

**测试文件**: `rust/src/models/card.rs` (tests module)

**单元测试**:
- `test_card_creation()` - 卡片创建及初始值
- `test_card_update()` - 卡片更新和时间戳
- `test_card_soft_delete()` - 软删除功能
- `test_uuid_v7_ordering()` - UUID v7 时间排序
- `test_add_tag()` - 添加标签
- `test_remove_tag()` - 移除标签
- `test_duplicate_tags()` - 防止重复标签
- `test_device_tracking()` - 设备追踪
- `test_markdown_content()` - Markdown 内容存储
- `test_timestamp_management()` - 时间戳管理
- `test_restore_deleted_card()` - 恢复已删除卡片

**功能测试**:
- `test_card_lifecycle()` - 完整生命周期
- `test_concurrent_updates()` - 并发更新
- `test_serialization()` - 序列化/反序列化

**验收标准**:
- [x] 所有单元测试通过
- [x] UUID v7 ID 按时间排序
- [x] 时间戳自动管理
- [x] 标签可以添加和移除
- [x] 软删除功能正常
- [x] 设备追踪工作正常
- [x] 代码审查通过
