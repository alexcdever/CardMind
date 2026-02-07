# 通用类型系统规格

**状态**: 活跃
**依赖**: 无
**相关测试**: `rust/tests/common_types_feature_test.rs`

---

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

**实现逻辑**:

```
function generate_unique_identifier():
    // 步骤1：生成 UUID v7
    // 设计决策：UUID v7 前 48 位是时间戳,确保时间排序
    uuid = generate_uuid_v7()
    
    // 步骤2：转换为字符串格式
    // 格式: 8-4-4-4-12 (例如: 018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f)
    uuid_string = uuid.to_string()
    
    log_debug("Generated unique identifier: " + uuid_string)
    return uuid_string

function validate_unique_identifier(id):
    // 验证唯一标识符格式
    
    // 步骤1：检查长度
    if length(id) != 36:
        return error "Invalid length: expected 36 characters"
    
    // 步骤2：检查格式
    // 格式: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if not matches_uuid_pattern(id):
        return error "Invalid UUID format"
    
    // 步骤3：验证版本号
    // UUID v7 的版本位应该是 7
    version = extract_version(id)
    if version != 7:
        return error "Invalid UUID version: expected v7"
    
    return success

function compare_identifiers_by_time(id_a, id_b):
    // 比较两个标识符的时间顺序
    // 设计决策：UUID v7 可以直接字符串比较
    
    if id_a < id_b:
        return -1  // id_a 更早
    else if id_a > id_b:
        return 1   // id_b 更早
    else:
        return 0   // 相同
```

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

**实现逻辑**:

```
function validate_optional_text(text):
    // 验证可选文本约束
    
    // 步骤1：允许 null 或空字符串
    if text is None or text is empty:
        return success
    
    // 步骤2：检查长度（Unicode 字符数）
    // 设计决策：使用 Unicode 字符数而非字节数
    char_count = count_unicode_characters(text)
    
    if char_count > 256:
        return error "Text too long: " + char_count + " characters (max 256)"
    
    // 步骤3：检查控制字符
    if contains_control_characters(text):
        return error "Text contains invalid control characters"
    
    return success

function sanitize_optional_text(text):
    // 清理可选文本
    
    // 步骤1：移除前后空白
    sanitized = trim(text)
    
    // 步骤2：移除控制字符
    sanitized = remove_control_characters(sanitized)
    
    // 步骤3：截断到最大长度
    if count_unicode_characters(sanitized) > 256:
        sanitized = truncate_to_chars(sanitized, 256)
    
    return sanitized

function contains_control_characters(text):
    // 检查是否包含控制字符
    for each char in text:
        if is_control_character(char):
            return true
    
    return false
```

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

**实现逻辑**:

```
function validate_markdown_text(markdown):
    // 验证 Markdown 文本
    
    // 步骤1：不能为空
    if markdown is None or markdown is empty:
        return error "Markdown content cannot be empty"
    
    // 步骤2：至少包含一个非空白字符
    if trim(markdown) is empty:
        return error "Markdown content must contain at least one non-whitespace character"
    
    // 步骤3：可选：验证 Markdown 语法
    // 注意：这是可选的,因为任何文本都是有效的 Markdown
    syntax_check = check_markdown_syntax(markdown)
    
    if syntax_check.has_errors:
        log_warn("Markdown syntax warnings: " + syntax_check.warnings)
    
    return success

function parse_markdown_features(markdown):
    // 解析 Markdown 特性
    
    features = {
        has_headers: false,
        has_lists: false,
        has_code_blocks: false,
        has_inline_code: false,
        has_quotes: false,
        has_links: false,
        has_tables: false,
        has_formatting: false
    }
    
    // 检测标题
    if markdown.contains("#"):
        features.has_headers = true
    
    // 检测列表
    if markdown.contains("- ") or markdown.contains("* ") or markdown.contains("1. "):
        features.has_lists = true
    
    // 检测代码块
    if markdown.contains("```"):
        features.has_code_blocks = true
    
    // 检测内联代码
    if markdown.contains("`"):
        features.has_inline_code = true
    
    // 检测引用块
    if markdown.contains("> "):
        features.has_quotes = true
    
    // 检测链接
    if markdown.contains("[") and markdown.contains("]" + "("):
        features.has_links = true
    
    // 检测表格
    if markdown.contains("|"):
        features.has_tables = true
    
    // 检测格式化
    if markdown.contains("**") or markdown.contains("*") or markdown.contains("~~"):
        features.has_formatting = true
    
    return features

function sanitize_markdown(markdown):
    // 清理 Markdown 内容
    // 设计决策：保持原始格式,仅移除危险内容
    
    // 步骤1：移除潜在的 XSS 脚本
    // 注意：如果渲染为 HTML,需要防止 XSS
    sanitized = remove_script_tags(markdown)
    
    // 步骤2：规范化换行符
    sanitized = normalize_line_endings(sanitized)
    
    return sanitized
```

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

**实现逻辑**:

```
function get_current_timestamp():
    // 获取当前 Unix 毫秒时间戳
    // 设计决策：使用毫秒精度支持高频操作
    
    current_time = get_system_time()
    millis = current_time.to_unix_millis()
    
    return millis

function validate_timestamp(timestamp):
    // 验证时间戳
    
    // 步骤1：检查非负
    if timestamp < 0:
        return error "Timestamp cannot be negative"
    
    // 步骤2：检查范围
    // Unix 纪元: 1970-01-01 00:00:00 UTC = 0
    // 最大值: 2262-04-11 23:47:16.854 UTC = 9223372036854775807
    min_timestamp = 0
    max_timestamp = 9223372036854775807
    
    if timestamp < min_timestamp or timestamp > max_timestamp:
        return error "Timestamp out of valid range"
    
    return success

function format_timestamp(timestamp):
    // 格式化时间戳为人类可读格式
    
    // 步骤1：转换为 DateTime
    datetime = timestamp_to_datetime(timestamp)
    
    // 步骤2：格式化为 ISO 8601
    // 格式: YYYY-MM-DDTHH:MM:SS.sssZ
    formatted = datetime.to_iso8601()
    
    return formatted

function parse_timestamp(iso_string):
    // 从 ISO 8601 字符串解析时间戳
    
    // 步骤1：解析 ISO 8601 格式
    datetime = parse_iso8601(iso_string)
    
    if datetime is error:
        return datetime
    
    // 步骤2：转换为 Unix 毫秒
    timestamp = datetime.to_unix_millis()
    
    return timestamp

function compare_timestamps(timestamp_a, timestamp_b):
    // 比较两个时间戳
    
    if timestamp_a < timestamp_b:
        return -1  // timestamp_a 更早
    else if timestamp_a > timestamp_b:
        return 1   // timestamp_b 更早
    else:
        return 0   // 相同
```

---

## 需求：引用完整性

系统应在数据结构之间强制执行引用完整性约束。

### 场景：校验池引用有效性

- **前置条件**: DeviceConfig.pool_id 已设置
- **操作**: 验证池引用
- **预期结果**: pool_id 必须引用现有的 Pool
- **并且**: 设备必须属于该池

**实现逻辑**:

```
function validate_pool_reference(device_config):
    // 验证池引用完整性
    
    // 步骤1：检查是否设置了池 ID
    if device_config.pool_id is None:
        return success  // 未设置池 ID,无需验证
    
    // 步骤2：验证池是否存在
    pool_id = device_config.pool_id
    pool = load_pool(pool_id)
    
    if pool is error:
        return error "Invalid pool reference: pool " + pool_id + " does not exist"
    
    // 步骤3：验证设备在池的设备列表中
    device_id = device_config.device_id
    
    if not pool.device_ids.contains(device_id):
        return error "Device " + device_id + " not in pool " + pool_id
    
    return success
```

### 场景：校验卡片-池绑定一致性

- **前置条件**: Pool.card_ids 包含卡片 ID
- **操作**: 验证绑定一致性
- **预期结果**: SQLite card_pool_bindings 表必须有相应条目

**实现逻辑**:

```
function validate_card_pool_binding(pool_id, card_id):
    // 验证卡片-池绑定一致性
    
    // 步骤1：检查 Loro 文档中的绑定
    pool = load_pool(pool_id)
    
    if pool is error:
        return pool
    
    loro_has_binding = pool.card_ids.contains(card_id)
    
    // 步骤2：检查 SQLite 缓存中的绑定
    db = get_sqlite_connection()
    result = db.query(
        "SELECT 1 FROM card_pool_bindings 
         WHERE pool_id = ? AND card_id = ?",
        [pool_id, card_id]
    )
    
    sqlite_has_binding = result.has_rows()
    
    // 步骤3：验证一致性
    if loro_has_binding != sqlite_has_binding:
        return error "Inconsistent card-pool binding: " +
                     "Loro=" + loro_has_binding + ", " +
                     "SQLite=" + sqlite_has_binding
    
    return success

function repair_card_pool_bindings(pool_id):
    // 修复卡片-池绑定不一致
    
    // 步骤1：从 Loro 获取权威数据
    pool = load_pool(pool_id)
    
    if pool is error:
        return pool
    
    // 步骤2：清除 SQLite 中的旧绑定
    db = get_sqlite_connection()
    db.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", [pool_id])
    
    // 步骤3：重建绑定
    for each card_id in pool.card_ids:
        db.execute(
            "INSERT INTO card_pool_bindings (pool_id, card_id) VALUES (?, ?)",
            [pool_id, card_id]
        )
    
    log_info("Repaired card-pool bindings for pool: " + pool_id)
    return success
```

---

## 需求：时间戳一致性

系统应强制执行时间戳一致性规则。

### 场景：创建早于更新

- **前置条件**: 任何具有 created_at 和 updated_at 的实体
- **操作**: 校验时间戳一致性
- **预期结果**: `created_at <= updated_at` 必须始终为真

**实现逻辑**:

```
function validate_timestamp_consistency(entity):
    // 验证时间戳一致性
    
    // 步骤1：检查是否有时间戳字段
    if not has_field(entity, "created_at") or not has_field(entity, "updated_at"):
        return success  // 无时间戳字段,无需验证
    
    // 步骤2：验证创建时间 <= 更新时间
    if entity.created_at > entity.updated_at:
        return error "Invalid timestamps: created_at (" + entity.created_at + 
                     ") > updated_at (" + entity.updated_at + ")"
    
    return success
```

### 场景：自动更新时间戳

- **前置条件**: 实体被修改
- **操作**: 更新时间戳
- **预期结果**: updated_at 必须自动更新

**实现逻辑**:

```
function auto_update_timestamp(entity):
    // 自动更新时间戳
    // 设计决策：任何修改都应更新 updated_at
    
    // 步骤1：保存原始创建时间
    original_created_at = entity.created_at
    
    // 步骤2：更新修改时间
    entity.updated_at = get_current_timestamp()
    
    // 步骤3：确保创建时间未改变
    assert entity.created_at == original_created_at
    
    // 步骤4：验证一致性
    result = validate_timestamp_consistency(entity)
    
    if result is error:
        return result
    
    return success
```

### 场景：UTC 时区

- **前置条件**: 任何时间戳字段
- **操作**: 确保统一时区
- **预期结果**: 时间戳必须使用 UTC 时区

**实现逻辑**:

```
function ensure_utc_timezone(timestamp):
    // 确保时间戳使用 UTC 时区
    // 设计决策：所有时间戳统一使用 UTC
    
    // 步骤1：Unix 时间戳本身就是 UTC
    // 注意：Unix 时间戳定义为自 1970-01-01 00:00:00 UTC 以来的秒数
    
    // 步骤2：如果从本地时间转换,需要转换为 UTC
    if is_local_time(timestamp):
        utc_timestamp = convert_to_utc(timestamp)
        return utc_timestamp
    
    return timestamp
```

---

## 需求：软删除

系统应支持卡片的软删除。

### 场景：软删除的卡片不在默认查询中

- **前置条件**: is_deleted = true 的卡片
- **操作**: 默认查询卡片列表
- **预期结果**: 卡片不应出现在默认查询中

**实现逻辑**:

```
function query_active_cards():
    // 查询活动卡片（排除已删除）
    // 设计决策：默认查询不包含已删除卡片
    
    db = get_sqlite_connection()
    results = db.query(
        "SELECT * FROM cards WHERE deleted = 0 ORDER BY updated_at DESC"
    )
    
    return results

function query_all_cards_including_deleted():
    // 查询所有卡片（包括已删除）
    // 用途：管理界面、恢复功能
    
    db = get_sqlite_connection()
    results = db.query(
        "SELECT * FROM cards ORDER BY updated_at DESC"
    )
    
    return results
```

### 场景：软删除的卡片可以恢复

- **前置条件**: 软删除的卡片
- **操作**: 恢复卡片
- **预期结果**: is_deleted = false

**实现逻辑**:

```
function soft_delete_card(card_id):
    // 软删除卡片
    
    // 步骤1：加载卡片
    card = load_card(card_id)
    
    if card is error:
        return card
    
    // 步骤2：标记为已删除
    card.deleted = true
    card.updated_at = get_current_timestamp()
    
    // 步骤3：保存变更
    save_card(card)
    
    log_info("Soft deleted card: " + card_id)
    return success

function restore_card(card_id):
    // 恢复已删除的卡片
    
    // 步骤1：加载卡片（包括已删除）
    card = load_card_including_deleted(card_id)
    
    if card is error:
        return card
    
    // 步骤2：检查是否已删除
    if not card.deleted:
        return error "Card is not deleted: " + card_id
    
    // 步骤3：恢复卡片
    card.deleted = false
    card.updated_at = get_current_timestamp()
    
    // 步骤4：保存变更
    save_card(card)
    
    log_info("Restored card: " + card_id)
    return success

function permanently_delete_card(card_id):
    // 永久删除卡片
    // 注意：这是破坏性操作,无法恢复
    
    // 步骤1：确认卡片已软删除
    card = load_card_including_deleted(card_id)
    
    if card is error:
        return card
    
    if not card.deleted:
        return error "Card must be soft deleted first: " + card_id
    
    // 步骤2：删除 Loro 文档
    delete_loro_document(card_id)
    
    // 步骤3：删除 SQLite 记录
    db = get_sqlite_connection()
    db.execute("DELETE FROM cards WHERE id = ?", [card_id])
    db.execute("DELETE FROM card_pool_bindings WHERE card_id = ?", [card_id])
    
    log_warn("Permanently deleted card: " + card_id)
    return success
```

---

## 补充说明

**类型定义**:
```rust
pub type UniqueIdentifier = String;  // UUID v7 格式
pub type OptionalText = Option<String>;  // 最大 256 字符
pub type MarkdownText = String;  // 无长度限制
pub type Timestamp = i64;  // Unix 毫秒
```

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
