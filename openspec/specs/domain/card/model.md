# Card Domain Model Specification
# 卡片领域模型规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [types.md](../types.md)
**依赖**: [types.md](../types.md)

**Related Tests**: `rust/src/models/card.rs` (tests module)
**相关测试**: `rust/src/models/card.rs` (tests module)

---

## Overview
## 概述

This specification defines the Card domain entity, which represents a single note card in the CardMind system. Each card contains a title, Markdown content, metadata, and supports soft deletion.

本规格定义了 Card 领域实体，代表 CardMind 系统中的单个笔记卡片。每张卡片包含标题、Markdown 内容、元数据，并支持软删除。

---

## Requirement: Card Entity Definition
## 需求：卡片实体定义

The system SHALL define a Card entity with the following core attributes.

系统应定义 Card 实体，包含以下核心属性。

### Scenario: Card contains required attributes
### 场景：卡片包含必需属性

- **GIVEN**: a card is created
- **前置条件**：创建一张卡片
- **WHEN**: the card entity is instantiated
- **操作**：实例化卡片实体
- **THEN**: the card SHALL have a unique identifier (UUID v7)
- **预期结果**：卡片应具有唯一标识符（UUID v7）
- **AND**: the card SHALL have a title (String)
- **并且**：卡片应具有标题（字符串）
- **AND**: the card SHALL have content in Markdown format (String)
- **并且**：卡片应具有 Markdown 格式的内容（字符串）
- **AND**: the card SHALL have creation timestamp (Unix milliseconds)
- **并且**：卡片应具有创建时间戳（Unix 毫秒）
- **AND**: the card SHALL have last modification timestamp (Unix milliseconds)
- **并且**：卡片应具有最后修改时间戳（Unix 毫秒）

### Scenario: Card contains optional attributes
### 场景：卡片包含可选属性

- **GIVEN**: a card exists
- **前置条件**：卡片存在
- **WHEN**: the card is examined
- **操作**：检查卡片
- **THEN**: the card SHALL have a deletion flag (boolean, default false)
- **预期结果**：卡片应具有删除标志（布尔值，默认 false）
- **AND**: the card SHALL have a list of tags (Vec<String>, default empty)
- **并且**：卡片应具有标签列表（Vec<String>，默认为空）
- **AND**: the card SHALL have an optional last edit device identifier
- **并且**：卡片应具有可选的最后编辑设备标识符

---

## Requirement: UUID v7 Identifier
## 需求：UUID v7 标识符

The system SHALL use UUID v7 (time-ordered) as the card identifier.

系统应使用 UUID v7（时间有序）作为卡片标识符。

### Scenario: Card ID is time-ordered
### 场景：卡片 ID 按时间排序

- **GIVEN**: two cards are created sequentially
- **前置条件**：顺序创建两张卡片
- **WHEN**: Card A is created before Card B
- **操作**：卡片 A 在卡片 B 之前创建
- **THEN**: Card A's ID SHALL be lexicographically smaller than Card B's ID
- **预期结果**：卡片 A 的 ID 应在字典序上小于卡片 B 的 ID
- **AND**: the IDs SHALL naturally sort by creation time
- **并且**：ID 应按创建时间自然排序

---

## Requirement: Markdown Content Support
## 需求：Markdown 内容支持

The system SHALL store card content in Markdown format.

系统应以 Markdown 格式存储卡片内容。

### Scenario: Card content is Markdown
### 场景：卡片内容为 Markdown

- **GIVEN**: a card is created
- **前置条件**：创建一张卡片
- **WHEN**: content is set
- **操作**：设置内容
- **THEN**: the content SHALL be stored as plain text Markdown
- **预期结果**：内容应以纯文本 Markdown 格式存储
- **AND**: the content SHALL support standard Markdown syntax
- **并且**：内容应支持标准 Markdown 语法

---

## Requirement: Timestamp Management
## 需求：时间戳管理

The system SHALL automatically manage creation and modification timestamps.

系统应自动管理创建和修改时间戳。

### Scenario: Creation timestamp is set automatically
### 场景：自动设置创建时间戳

- **GIVEN**: a new card is created
- **前置条件**：创建新卡片
- **WHEN**: the card is instantiated
- **操作**：实例化卡片
- **THEN**: the created_at timestamp SHALL be set to current time
- **预期结果**：created_at 时间戳应设置为当前时间
- **AND**: the updated_at timestamp SHALL equal created_at initially
- **并且**：updated_at 时间戳初始应等于 created_at

### Scenario: Modification timestamp updates on change
### 场景：修改时更新时间戳

- **GIVEN**: a card exists
- **前置条件**：卡片存在
- **WHEN**: the card's title, content, or tags are modified
- **操作**：修改卡片的标题、内容或标签
- **THEN**: the updated_at timestamp SHALL be updated to current time
- **预期结果**：updated_at 时间戳应更新为当前时间
- **AND**: the created_at timestamp SHALL remain unchanged
- **并且**：created_at 时间戳应保持不变

---

## Requirement: Tag Management
## 需求：标签管理

The system SHALL support adding and removing tags from cards.

系统应支持为卡片添加和移除标签。

### Scenario: Add tag to card
### 场景：为卡片添加标签

- **GIVEN**: a card exists without a specific tag
- **前置条件**：卡片存在且没有特定标签
- **WHEN**: a tag is added to the card
- **操作**：为卡片添加标签
- **THEN**: the tag SHALL be added to the card's tag list
- **预期结果**：标签应添加到卡片的标签列表
- **AND**: the updated_at timestamp SHALL be updated
- **并且**：updated_at 时间戳应更新

### Scenario: Prevent duplicate tags
### 场景：防止重复标签

- **GIVEN**: a card already has a specific tag
- **前置条件**：卡片已有特定标签
- **WHEN**: the same tag is added again
- **操作**：再次添加相同标签
- **THEN**: the tag SHALL NOT be duplicated in the list
- **预期结果**：标签不应在列表中重复
- **AND**: the updated_at timestamp SHALL NOT be updated
- **并且**：updated_at 时间戳不应更新

### Scenario: Remove tag from card
### 场景：从卡片移除标签

- **GIVEN**: a card has a specific tag
- **前置条件**：卡片有特定标签
- **WHEN**: the tag is removed
- **操作**：移除标签
- **THEN**: the tag SHALL be removed from the card's tag list
- **预期结果**：标签应从卡片的标签列表中移除
- **AND**: the updated_at timestamp SHALL be updated
- **并且**：updated_at 时间戳应更新

---

## Requirement: Device Tracking
## 需求：设备追踪

The system SHALL track which device last edited each card.

系统应追踪哪个设备最后编辑了每张卡片。

### Scenario: Record last edit device
### 场景：记录最后编辑设备

- **GIVEN**: a card is edited on a specific device
- **前置条件**：在特定设备上编辑卡片
- **WHEN**: the device identifier is set
- **操作**：设置设备标识符
- **THEN**: the last_edit_device SHALL be set to the device identifier
- **预期结果**：last_edit_device 应设置为设备标识符
- **AND**: the updated_at timestamp SHALL be updated
- **并且**：updated_at 时间戳应更新

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/src/models/card.rs` (tests module)
**测试文件**: `rust/src/models/card.rs` (tests module)

**Unit Tests**:
**单元测试**:
- `test_card_creation()` - Card creation with initial values
- `test_card_creation()` - 卡片创建及初始值
- `test_card_update()` - Card update and timestamp
- `test_card_update()` - 卡片更新和时间戳
- `test_card_soft_delete()` - Soft delete functionality
- `test_card_soft_delete()` - 软删除功能

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] UUID v7 IDs are time-ordered
- [ ] UUID v7 ID 按时间排序
- [ ] Timestamps are managed automatically
- [ ] 时间戳自动管理
- [ ] Tags can be added and removed
- [ ] 标签可以添加和移除
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [rules.md](rules.md) - Card business rules
- [rules.md](rules.md) - 卡片业务规则
- [types.md](../types.md) - Common types
- [types.md](../types.md) - 共享类型

**Implementation**:
**实现**:
- `rust/src/models/card.rs` - Card model implementation
- `rust/src/models/card.rs` - Card 模型实现

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
