# Bilingual Specification Writing Guide
# 双语规格编写指南

**Version** | **版本**: 1.0.0
**Last Updated** | **最后更新**: 2026-01-21

---

## Purpose | 目的

This guide defines the standard format for writing bilingual (English-Chinese) specifications in the CardMind project.

本指南定义了 CardMind 项目中编写双语（英中）规格的标准格式。

**Why Bilingual? | 为什么使用双语？**
- **English**: Ensures precise technical terminology (SHALL, MUST, GIVEN, WHEN, THEN) that AI tools understand correctly
- **英语**：确保精确的技术术语（SHALL、MUST、GIVEN、WHEN、THEN），AI 工具能正确理解
- **Chinese**: Native language for developers, facilitates faster comprehension and collaboration
- **中文**：开发者的母语，促进更快的理解和协作

---

## Standard Format | 标准格式

### 1. Document Structure | 文档结构

Every specification MUST follow this structure:

每个规格必须遵循以下结构：

```markdown
# [Feature Name] Specification
# [功能名称] 规格

**Metadata Section** (Version, Status, Dependencies, Tests)
**元数据部分**（版本、状态、依赖、测试）

**Overview** (Brief description)
**概述**（简要描述）

**Requirements** (Multiple requirement sections)
**需求**（多个需求部分）

**Test Coverage** (Test files, test cases, acceptance criteria)
**测试覆盖**（测试文件、测试用例、验收标准）

**Related Documents** (ADRs, Related specs)
**相关文档**（ADR、相关规格）
```

### 2. Metadata Section | 元数据部分

```markdown
**Version** | **版本**: X.Y.Z
**Status** | **状态**: Draft | Active | Deprecated
**Dependencies** | **依赖**: [spec.md](path/to/spec.md)
**Related Tests** | **相关测试**: `path/to/test.rs`
```

**Rules | 规则**:
- Use Markdown links for dependencies | 使用 Markdown 链接表示依赖
- Use relative paths | 使用相对路径
- Status must be one of: Draft, Active, Deprecated | 状态必须是：Draft、Active、Deprecated 之一

### 3. Requirement Sections | 需求部分

Each requirement follows this pattern:

每个需求遵循此模式：

```markdown
## Requirement: [Title in English]
## 需求：[中文标题]

[SHALL statement in English]
[中文陈述（使用"应"）]

### Scenario: [Scenario Title in English]
### 场景：[场景中文标题]

- **GIVEN** [precondition in English]
- **前置条件**：[中文前置条件]
- **WHEN** [action in English]
- **操作**：[中文操作]
- **THEN** [outcome in English]
- **预期结果**：[中文预期结果]
- **AND** [additional outcome]
- **并且**：[附加结果]
```

### 4. Key Keywords | 关键关键字

**Requirement Keywords | 需求关键字**:
- SHALL / 应 - Mandatory requirement | 强制性需求
- SHOULD / 宜 - Recommended but not mandatory | 推荐但非强制
- MAY / 可 - Optional | 可选
- MUST NOT / 禁止 - Forbidden | 禁止

**Scenario Keywords | 场景关键字**:
- GIVEN / 前置条件 - Precondition | 前置条件
- WHEN / 操作 - Action or trigger | 操作或触发
- THEN / 预期结果 - Expected outcome | 预期结果
- AND / 并且 - Additional condition or outcome | 附加条件或结果

---

## Templates | 模板

### Full Template | 完整模板
See [SPEC_TEMPLATE.md](SPEC_TEMPLATE.md) for the complete template.
完整模板请参见 [SPEC_TEMPLATE.md](SPEC_TEMPLATE.md)。

### Example Specification | 示例规格
See [SPEC_EXAMPLE.md](SPEC_EXAMPLE.md) for a complete example.
完整示例请参见 [SPEC_EXAMPLE.md](SPEC_EXAMPLE.md)。

---

## Best Practices | 最佳实践

### 1. English First, Chinese Follows | 英文在前，中文紧随

```markdown
✅ GOOD | 正确:
## Requirement: Data Synchronization
## 需求：数据同步

❌ BAD | 错误:
## 需求：数据同步
## Requirement: Data Synchronization
```

**Why? | 为什么？** AI tools parse English technical terms more reliably.
AI 工具更可靠地解析英语技术术语。

### 2. Consistent Terminology | 一致的术语

Use the same Chinese translation for English technical terms throughout the document:

在整个文档中对英语技术术语使用相同的中文翻译：

| English | 中文 | Notes | 说明 |
|---------|------|-------|------|
| Pool | 池 | Not "池子" or "存储池" | 不使用"池子"或"存储池" |
| Device | 设备 | Not "装置" | 不使用"装置" |
| Card | 卡片 | Not "卡" | 不使用"卡" |
| Sync | 同步 | Not "同步化" | 不使用"同步化" |
| Resident Pool | 常驻池 | Not "居民池" | 不使用"居民池" |

### 3. SHALL Statements | SHALL 陈述

**Pattern | 模式**:
```markdown
The system SHALL [verb] [object] [condition].
系统应[动词][对象][条件]。
```

**Examples | 示例**:
```markdown
✅ The system SHALL reject duplicate card IDs.
✅ 系统应拒绝重复的卡片 ID。

✅ The device SHALL clear local data when leaving a pool.
✅ 设备离开池时应清除本地数据。
```

### 4. Scenario Structure | 场景结构

Keep scenarios atomic and testable:

保持场景原子化和可测试性：

```markdown
✅ GOOD | 正确:
### Scenario: Create card with valid title
### 场景：使用有效标题创建卡片
- **GIVEN** user has access to card creation
- **前置条件**：用户有权限创建卡片
- **WHEN** user creates a card with title "My Note"
- **操作**：用户创建标题为"My Note"的卡片
- **THEN** card SHALL be created successfully
- **预期结果**：卡片应成功创建

❌ BAD | 错误:
### Scenario: Card management
### 场景：卡片管理
- **GIVEN** user is logged in
- **WHEN** user does various card operations
- **THEN** all operations work
```

### 5. Test Mapping | 测试映射

Link scenarios to actual test cases:

将场景链接到实际测试用例：

```markdown
## Test Coverage | 测试覆盖

**Unit Tests** | **单元测试**:
- `it_should_create_card_with_valid_title()` - Maps to Scenario "Create card with valid title"
- `it_should_create_card_with_valid_title()` - 映射到场景"使用有效标题创建卡片"
```

---

## Validation Checklist | 验证清单

Before submitting a specification, verify:

提交规格前，请验证：

- [ ] All sections are bilingual (English first, Chinese follows)
- [ ] 所有部分都是双语（英文在前，中文紧随）
- [ ] SHALL/SHOULD/MAY keywords are used correctly
- [ ] SHALL/SHOULD/MAY 关键字使用正确
- [ ] All scenarios follow GIVEN-WHEN-THEN structure
- [ ] 所有场景遵循 GIVEN-WHEN-THEN 结构
- [ ] Dependencies use Markdown links
- [ ] 依赖使用 Markdown 链接
- [ ] Test cases are listed and mapped to scenarios
- [ ] 测试用例已列出并映射到场景
- [ ] Chinese translations are accurate and consistent
- [ ] 中文翻译准确且一致

---

## Tools | 工具

**Template File** | **模板文件**: `openspec/specs/SPEC_TEMPLATE.md`
**Example File** | **示例文件**: `openspec/specs/SPEC_EXAMPLE.md`
**Validation Tool** | **验证工具**: `tool/verify_spec_sync.dart`

---

**Questions? | 有疑问？** Refer to existing bilingual specs in `openspec/specs/domain/` for examples.

参考 `openspec/specs/domain/` 中现有的双语规格作为示例。

---

**Last Updated** | **最后更新**: 2026-01-21
**Maintained By** | **维护者**: CardMind Team
