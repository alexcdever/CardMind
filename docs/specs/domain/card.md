# 卡片领域模型规格

**状态**: 活跃
**依赖**: [types.md](types.md)
**相关测试**: `rust/src/models/card.rs` (tests module)

---

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

**实现逻辑**:

```
structure Card:
    // 必需属性
    id: String                    // UUID v7 格式
    title: String                 // 卡片标题
    content: String               // Markdown 格式内容
    created_at: i64              // Unix 毫秒时间戳
    updated_at: i64              // Unix 毫秒时间戳
    
    // 可选属性
    deleted: boolean             // 软删除标志,默认 false
    tags: Vec<String>            // 标签列表,默认空
    last_edit_device: Option<String>  // 最后编辑设备 ID

function create_card(title, content):
    // 步骤1：生成时间有序的唯一标识符
    // 设计决策：使用 UUID v7 实现时间排序
    card_id = generate_uuid_v7()
    
    // 步骤2：获取当前时间戳
    current_time = get_current_timestamp_millis()
    
    // 步骤3：创建卡片实例
    card = Card {
        id: card_id,
        title: title,
        content: content,
        created_at: current_time,
        updated_at: current_time,
        deleted: false,
        tags: [],
        last_edit_device: None
    }
    
    log_debug("Created card: " + card_id)
    return card

function get_current_timestamp_millis():
    // 获取当前 Unix 毫秒时间戳
    // 注意：使用毫秒精度以支持高频操作
    return current_time_in_milliseconds_since_epoch()
```

### 场景：卡片包含可选属性

- **前置条件**: 卡片存在
- **操作**: 检查卡片
- **预期结果**: 卡片应具有删除标志（布尔值,默认 false）
- **并且**: 卡片应具有标签列表（Vec<String>,默认为空）
- **并且**: 卡片应具有可选的最后编辑设备标识符

**实现逻辑**:

```
function validate_card(card):
    // 验证卡片的可选属性
    
    // 步骤1：验证删除标志
    if card.deleted is not boolean:
        return error "Invalid deleted flag type"
    
    // 步骤2：验证标签列表
    if card.tags is not Vec<String>:
        return error "Invalid tags type"
    
    // 步骤3：验证设备标识符
    if card.last_edit_device is Some:
        if not is_valid_device_id(card.last_edit_device):
            return error "Invalid device ID format"
    
    return success
```

---

## 需求：UUID v7 标识符

系统应使用 UUID v7（时间有序）作为卡片标识符。

### 场景：卡片 ID 按时间排序

- **前置条件**: 顺序创建两张卡片
- **操作**: 卡片 A 在卡片 B 之前创建
- **预期结果**: 卡片 A 的 ID 应在字典序上小于卡片 B 的 ID
- **并且**: ID 应按创建时间自然排序

**实现逻辑**:

```
function generate_uuid_v7():
    // 生成时间有序的 UUID v7
    // 设计决策：UUID v7 前 48 位是时间戳,确保时间排序
    
    // 步骤1：获取当前时间戳（毫秒）
    timestamp_ms = get_current_timestamp_millis()
    
    // 步骤2：生成随机部分
    random_bits = generate_random_bits(74)
    
    // 步骤3：组合为 UUID v7 格式
    // 格式: timestamp(48) + version(4) + random(12) + variant(2) + random(62)
    uuid = construct_uuid_v7(timestamp_ms, random_bits)
    
    return uuid.to_string()

function demonstrate_time_ordering():
    // 演示时间排序特性
    
    // 创建第一张卡片
    card_a = create_card("Card A", "Content A")
    
    // 等待 1 毫秒
    sleep(1)
    
    // 创建第二张卡片
    card_b = create_card("Card B", "Content B")
    
    // 验证排序
    // 注意：字符串比较即可实现时间排序
    assert card_a.id < card_b.id
    
    log_info("UUID v7 time ordering verified")
    return success
```

---

## 需求：Markdown 内容支持

系统应以 Markdown 格式存储卡片内容。

### 场景：卡片内容为 Markdown

- **前置条件**: 创建一张卡片
- **操作**: 设置内容
- **预期结果**: 内容应以纯文本 Markdown 格式存储
- **并且**: 内容应支持标准 Markdown 语法

**实现逻辑**:

```
function set_card_content(card, markdown_content):
    // 步骤1：验证内容不为空
    if markdown_content is empty:
        return error "Content cannot be empty"
    
    // 步骤2：存储为纯文本
    // 设计决策：不解析 Markdown,保持原始格式
    // 注意：解析由前端负责
    card.content = markdown_content
    
    // 步骤3：更新时间戳
    card.updated_at = get_current_timestamp_millis()
    
    log_debug("Updated content for card: " + card.id)
    return success

function validate_markdown_syntax(content):
    // 可选：验证 Markdown 语法
    // 注意：这是可选的,因为任何文本都是有效的 Markdown
    
    // 检查常见的 Markdown 元素
    has_headers = content.contains("#")
    has_lists = content.contains("- ") or content.contains("* ")
    has_links = content.contains("[") and content.contains("](")
    
    return {
        is_valid: true,
        has_formatting: has_headers or has_lists or has_links
    }
```

---

## 需求：时间戳管理

系统应自动管理创建和修改时间戳。

### 场景：自动设置创建时间戳

- **前置条件**: 创建新卡片
- **操作**: 实例化卡片
- **预期结果**: created_at 时间戳应设置为当前时间
- **并且**: updated_at 时间戳初始应等于 created_at

**实现逻辑**:

```
function initialize_timestamps(card):
    // 步骤1：获取当前时间
    current_time = get_current_timestamp_millis()
    
    // 步骤2：设置创建时间
    // 设计决策：创建时间永不改变
    card.created_at = current_time
    
    // 步骤3：初始化更新时间
    // 注意：初始时两个时间戳相同
    card.updated_at = current_time
    
    log_debug("Initialized timestamps for card: " + card.id)
    return success
```

### 场景：修改时更新时间戳

- **前置条件**: 卡片存在
- **操作**: 修改卡片的标题、内容或标签
- **预期结果**: updated_at 时间戳应更新为当前时间
- **并且**: created_at 时间戳应保持不变

**实现逻辑**:

```
function update_card_field(card, field_name, new_value):
    // 步骤1：保存原始创建时间
    original_created_at = card.created_at
    
    // 步骤2：更新字段
    if field_name == "title":
        card.title = new_value
    else if field_name == "content":
        card.content = new_value
    else if field_name == "tags":
        card.tags = new_value
    else:
        return error "Unknown field: " + field_name
    
    // 步骤3：更新修改时间戳
    card.updated_at = get_current_timestamp_millis()
    
    // 步骤4：确保创建时间未改变
    // 设计决策：创建时间是不可变的
    assert card.created_at == original_created_at
    
    log_debug("Updated " + field_name + " for card: " + card.id)
    return success
```

---

## 需求：标签管理

系统应支持为卡片添加和移除标签。

### 场景：为卡片添加标签

- **前置条件**: 卡片存在且没有特定标签
- **操作**: 为卡片添加标签
- **预期结果**: 标签应添加到卡片的标签列表
- **并且**: updated_at 时间戳应更新

**实现逻辑**:

```
function add_tag(card, tag):
    // 步骤1：验证标签格式
    if tag is empty:
        return error "Tag cannot be empty"
    
    if length(tag) > 50:
        return error "Tag too long (max 50 characters)"
    
    // 步骤2：检查标签是否已存在
    // 设计决策：防止重复标签
    if card.tags.contains(tag):
        log_debug("Tag already exists: " + tag)
        return success  // 幂等操作
    
    // 步骤3：添加标签
    card.tags.append(tag)
    
    // 步骤4：更新时间戳
    card.updated_at = get_current_timestamp_millis()
    
    log_debug("Added tag '" + tag + "' to card: " + card.id)
    return success
```

### 场景：防止重复标签

- **前置条件**: 卡片已有特定标签
- **操作**: 再次添加相同标签
- **预期结果**: 标签不应在列表中重复
- **并且**: updated_at 时间戳不应更新

**实现逻辑**:

```
function ensure_unique_tags(card):
    // 确保标签列表中没有重复
    // 设计决策：使用集合去重
    
    // 步骤1：转换为集合
    unique_tags = convert_to_set(card.tags)
    
    // 步骤2：检查是否有重复
    if length(unique_tags) < length(card.tags):
        log_warn("Found duplicate tags in card: " + card.id)
        
        // 步骤3：移除重复
        card.tags = convert_to_vec(unique_tags)
        
        return {
            had_duplicates: true,
            removed_count: length(card.tags) - length(unique_tags)
        }
    
    return {
        had_duplicates: false,
        removed_count: 0
    }
```

### 场景：从卡片移除标签

- **前置条件**: 卡片有特定标签
- **操作**: 移除标签
- **预期结果**: 标签应从卡片的标签列表中移除
- **并且**: updated_at 时间戳应更新

**实现逻辑**:

```
function remove_tag(card, tag):
    // 步骤1：检查标签是否存在
    if not card.tags.contains(tag):
        log_debug("Tag not found: " + tag)
        return success  // 幂等操作
    
    // 步骤2：移除标签
    card.tags.remove(tag)
    
    // 步骤3：更新时间戳
    card.updated_at = get_current_timestamp_millis()
    
    log_debug("Removed tag '" + tag + "' from card: " + card.id)
    return success

function clear_all_tags(card):
    // 清除所有标签
    if card.tags is empty:
        return success  // 已经为空
    
    card.tags.clear()
    card.updated_at = get_current_timestamp_millis()
    
    log_debug("Cleared all tags from card: " + card.id)
    return success
```

---

## 需求：软删除

系统应支持软删除卡片，而不是物理删除。

### 场景：软删除卡片

- **前置条件**: 卡片存在且未删除
- **操作**: 标记卡片为已删除
- **预期结果**: deleted 标志应设置为 true
- **并且**: updated_at 时间戳应更新
- **并且**: 卡片数据应保留

**实现逻辑**:

```
function soft_delete_card(card):
    // 步骤1：检查是否已删除
    if card.deleted:
        log_debug("Card already deleted: " + card.id)
        return success  // 幂等操作
    
    // 步骤2：标记为已删除
    // 设计决策：软删除保留数据以支持恢复
    card.deleted = true
    
    // 步骤3：更新时间戳
    card.updated_at = get_current_timestamp_millis()
    
    log_info("Soft deleted card: " + card.id)
    return success

function restore_card(card):
    // 恢复已删除的卡片
    if not card.deleted:
        log_debug("Card not deleted: " + card.id)
        return success  // 幂等操作
    
    card.deleted = false
    card.updated_at = get_current_timestamp_millis()
    
    log_info("Restored card: " + card.id)
    return success

function is_deleted(card):
    // 检查卡片是否已删除
    return card.deleted
```

---

## 需求：设备追踪

系统应追踪哪个设备最后编辑了每张卡片。

### 场景：记录最后编辑设备

- **前置条件**: 在特定设备上编辑卡片
- **操作**: 设置设备标识符
- **预期结果**: last_edit_device 应设置为设备标识符
- **并且**: updated_at 时间戳应更新

**实现逻辑**:

```
function set_last_edit_device(card, device_id):
    // 步骤1：验证设备 ID 格式
    if not is_valid_device_id(device_id):
        return error "Invalid device ID format"
    
    // 步骤2：设置设备标识符
    // 设计决策：追踪最后编辑设备以支持冲突解决
    card.last_edit_device = Some(device_id)
    
    // 步骤3：更新时间戳
    card.updated_at = get_current_timestamp_millis()
    
    log_debug("Set last edit device for card " + card.id + ": " + device_id)
    return success

function get_last_edit_device(card):
    // 获取最后编辑设备
    if card.last_edit_device is None:
        return None
    
    return card.last_edit_device

function is_valid_device_id(device_id):
    // 验证设备 ID 格式
    // 设计决策：设备 ID 应该是 UUID 格式
    if device_id is empty:
        return false
    
    if not is_valid_uuid(device_id):
        return false
    
    return true
```

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
- **内容**: 可以为空,无长度限制
- **标签**: 每个标签最大 50 字符,不允许重复
- **时间戳**: 必须是正整数,updated_at >= created_at

**性能特征**:
- **创建时间**: < 1ms
- **更新时间**: < 1ms
- **标签操作**: O(n) 其中 n 是标签数量
- **内存占用**: ~1KB per card (不含内容)

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

**集成测试**:
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
