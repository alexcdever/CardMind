# Specification Writing Guide
# 规格编写指南

**Version**: 1.0.0
**版本**: 1.0.0

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

---

## Purpose
## 目的

This guide defines the standard format and best practices for writing specifications in the CardMind project. All specifications use a two-line bilingual format (English-Chinese) to ensure clarity for both AI tools and human developers.

本指南定义了 CardMind 项目中编写规格的标准格式和最佳实践。所有规格使用两行双语格式（英中），以确保 AI 工具和人类开发者都能清晰理解。

**Why this format?**
**为什么使用这种格式？**

- **English**: Ensures precise technical terminology (SHALL, MUST, GIVEN, WHEN, THEN) that AI tools understand correctly
- **英语**：确保精确的技术术语（SHALL、MUST、GIVEN、WHEN、THEN），AI 工具能正确理解

- **Chinese**: Developers' native language, facilitates faster understanding and collaboration
- **中文**：开发者的母语，促进更快的理解和协作

- **Two-line format**: Clear separation, easy to read and maintain
- **两行格式**：清晰分隔，易于阅读和维护

---

## Standard Format
## 标准格式

### 1. Two-Line Principle
### 1. 两行原则

**All content uses two-line format: English first, Chinese immediately follows.**
**所有内容都使用两行格式：英文在前，中文紧随其后。**

```markdown
# English Title
# 中文标题

**English Metadata**: value
**中文元数据**: value

## English Heading
## 中文标题

English paragraph text.

中文段落文本。
```

---

### 2. Document Structure
### 2. 文档结构

Every specification must follow this structure:
每个规格必须遵循以下结构：

```markdown
# [Feature Name] Specification
# [功能名称] 规格

**Version**: X.Y.Z
**版本**: X.Y.Z

**Status**: Draft | Active | Deprecated
**状态**: 草稿 | 生效中 | 已废弃

**Dependencies**: [spec.md](path/to/spec.md)
**依赖**: [spec.md](path/to/spec.md)

**Related Tests**: `path/to/test.rs`
**相关测试**: `path/to/test.rs`

---

## Overview
## 概述

English description of the specification.

中文规格描述。

---

## Requirement: Requirement Title
## 需求：需求标题

English requirement statement using SHALL/SHOULD/MAY.

中文需求陈述使用"应"/"宜"/"可"。

### Scenario: Scenario Title
### 场景：场景标题

- **GIVEN**: precondition
- **前置条件**：前置条件
- **WHEN**: action
- **操作**：操作
- **THEN**: expected result
- **预期结果**：预期结果
- **AND**: additional condition or result
- **并且**：附加条件或结果

---

## Test Coverage
## 测试覆盖

**Test File**: `path/to/test.rs`
**测试文件**: `path/to/test.rs`

**Unit Tests**:
**单元测试**:
- `test_name()` - English description
- `test_name()` - 中文描述

**Acceptance Criteria**:
**验收标准**:
- [ ] English criterion
- [ ] 中文标准

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [spec.md](path) - English description
- [spec.md](path) - 中文描述
```

---

## Format Requirements
## 格式要求

### Requirement: All section headings must use two-line format
### 需求：所有章节标题必须使用两行格式

All section headings (# through #### levels) SHALL have both English and Chinese versions on separate consecutive lines.

所有章节标题（# 到 #### 级别）应在连续的两行上同时具有英文和中文版本。

**Example**:
**示例**:

```markdown
## Overview
## 概述

### Scenario: Create card
### 场景：创建卡片
```

**Rules**:
**规则**:
- Both lines SHALL use the same heading level marker (##, ###, etc.)
- 两行应使用相同的标题级别标记（##、### 等）
- Chinese line SHALL immediately follow English line
- 中文行应紧跟英文行
- No blank lines between English and Chinese headings
- 英文和中文标题之间不应有空行

---

### Requirement: Metadata must use two-line format
### 需求：元数据必须使用两行格式

Metadata fields SHALL use two consecutive lines, with English first followed by Chinese.

元数据字段应使用连续的两行，英文在前，中文紧随其后。

**Example**:
**示例**:

```markdown
**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [types.md](../types.md)
**依赖**: [types.md](../types.md)
```

**Rules**:
**规则**:
- Use Markdown links for dependencies
- 使用 Markdown 链接表示依赖
- Use relative paths
- 使用相对路径
- Status must be one of: Draft, Active, Deprecated
- 状态必须是：草稿、生效中、已废弃 之一

---

### Requirement: Scenario clauses must use two-line format
### 需求：场景子句必须使用两行格式

All scenario clauses (GIVEN/WHEN/THEN/AND) SHALL have both English and Chinese versions on separate consecutive lines.

所有场景子句（GIVEN/WHEN/THEN/AND）应在连续的两行上同时具有英文和中文版本。

**Example**:
**示例**:

```markdown
- **GIVEN**: a card exists in a pool
- **前置条件**：数据池中存在一张卡片
- **WHEN**: the card is modified
- **操作**：卡片被修改
- **THEN**: the system SHALL generate a new version
- **预期结果**：系统应生成新版本
- **AND**: the version SHALL be stored
- **并且**：版本应被存储
```

**Keyword Mapping**:
**关键字映射**:
- GIVEN / 前置条件 - Precondition
- WHEN / 操作 - Action or trigger
- THEN / 预期结果 - Expected result
- AND / 并且 - Additional condition or result

---

### Requirement: Body text must use bilingual paragraphs
### 需求：正文文本必须使用双语段落

Body text paragraphs SHALL have both English and Chinese versions, with English first followed by a blank line and then Chinese.

正文段落应同时具有英文和中文版本，英文在前，空行分隔，然后是中文。

**Example**:
**示例**:

```markdown
This specification defines the Card domain entity, which represents a single note card in the CardMind system.

本规格定义了 Card 领域实体，代表 CardMind 系统中的单个笔记卡片。
```

---

## Keywords and Terminology
## 关键字和术语

### Requirement Keywords
### 需求关键字

Use these keywords in requirement statements:
在需求陈述中使用这些关键字：

| English | 中文 | Meaning / 含义 |
|---------|------|----------------|
| SHALL | 应 | Mandatory requirement / 强制性需求 |
| SHOULD | 宜 | Recommended but not mandatory / 推荐但非强制 |
| MAY | 可 | Optional / 可选 |
| MUST NOT | 禁止 | Forbidden / 禁止 |

**Pattern**:
**模式**:

```markdown
The system SHALL [verb] [object] [condition].

系统应[动词][对象][条件]。
```

**Examples**:
**示例**:

```markdown
The system SHALL reject duplicate card IDs.

系统应拒绝重复的卡片 ID。

The device SHALL clear local data when leaving a pool.

设备离开池时应清除本地数据。
```

---

### Consistent Terminology
### 一致的术语

Use consistent Chinese translations for English technical terms:
对英语技术术语使用一致的中文翻译：

| English | 中文 | Note / 说明 |
|---------|------|-------------|
| Pool | 池 | Don't use "池子" or "存储池" / 不使用"池子"或"存储池" |
| Device | 设备 | Don't use "装置" / 不使用"装置" |
| Card | 卡片 | Don't use "卡" / 不使用"卡" |
| Sync | 同步 | Don't use "同步化" / 不使用"同步化" |
| Joined Pool | 已加入池 | Don't use "加入的池" / 不使用"加入的池" |
| Specification | 规格 | Don't use "规范" / 不使用"规范" |
| Requirement | 需求 | Don't use "要求" / 不使用"要求" |
| Scenario | 场景 | Don't use "情景" / 不使用"情景" |

---

## Best Practices
## 最佳实践

### 1. Keep scenarios atomic and testable
### 1. 保持场景原子化和可测试性

Each scenario should test one specific behavior:
每个场景应测试一个特定行为：

```markdown
✅ Good / 正确:
### Scenario: Create card with valid title
### 场景：使用有效标题创建卡片

- **GIVEN**: user has permission to create cards
- **前置条件**：用户有权限创建卡片
- **WHEN**: user creates a card with title "My Note"
- **操作**：用户创建标题为"My Note"的卡片
- **THEN**: the card SHALL be created successfully
- **预期结果**：卡片应成功创建

❌ Bad / 错误:
### Scenario: Card management
### 场景：卡片管理

- **GIVEN**: user is logged in
- **前置条件**：用户已登录
- **WHEN**: user performs various card operations
- **操作**：用户执行各种卡片操作
- **THEN**: all operations work correctly
- **预期结果**：所有操作都正常工作
```

---

### 2. Map scenarios to test cases
### 2. 将场景映射到测试用例

Link scenarios to actual test implementations:
将场景链接到实际测试实现：

```markdown
## Test Coverage
## 测试覆盖

**Unit Tests**:
**单元测试**:
- `it_should_create_card_with_valid_title()` - Maps to scenario "Create card with valid title"
- `it_should_create_card_with_valid_title()` - 映射到场景"使用有效标题创建卡片"
```

---

### 3. Use relative paths for dependencies
### 3. 使用相对路径表示依赖

Always use relative paths in dependency links:
始终在依赖链接中使用相对路径：

```markdown
✅ Good / 正确:
**Dependencies**: [types.md](../types.md), [pool/model.md](../pool/model.md)
**依赖**: [types.md](../types.md), [pool/model.md](../pool/model.md)

❌ Bad / 错误:
**Dependencies**: types.md, pool/model.md
**依赖**: types.md, pool/model.md
```

---

### 4. Describe stable state, not changes
### 4. 描述稳定状态，而非变更

Main specs describe "what is", not "what changed":
主规格描述"是什么"，而非"改变了什么"：

```markdown
✅ Good / 正确:
The system SHALL store card content in Markdown format.

系统应以 Markdown 格式存储卡片内容。

❌ Bad / 错误:
We changed the system to store card content in Markdown format instead of plain text.

我们将系统改为以 Markdown 格式存储卡片内容，而不是纯文本。
```

**Note**: Change descriptions belong in delta specs under `openspec/changes/<change-name>/specs/`, not in main specs.
**注意**：变更描述属于 `openspec/changes/<change-name>/specs/` 下的 delta specs，而非主规格。

---

### 5. Code Examples and Pseudocode
### 5. 代码示例与伪代码

#### 5.1 Prefer Pseudocode Over Detailed Implementation
#### 5.1 优先使用伪代码而非详细实现

Specifications SHOULD use pseudocode that emphasizes logic flow and design intent, rather than detailed implementation code.

规格文档应该使用强调逻辑流程和设计意图的伪代码，而不是详细的实现代码。

**Rationale:**
**理由：**

- **Error Prevention**: Detailed code examples may contain bugs that get copied into business code
- **错误预防**：详细的代码示例可能包含错误，这些错误会被复制到业务代码中
- **Maintenance Burden**: Implementation-specific code requires constant synchronization with actual codebase
- **维护负担**：特定实现的代码需要与实际代码库持续同步
- **Implementation Flexibility**: Pseudocode allows developers freedom in implementation choices
- **实现灵活性**：伪代码允许开发者在实现选择上有自由度
- **Focus on Logic**: Specifications should define "what" and "why", not "how"
- **关注逻辑**：规格文档应该定义"做什么"和"为什么"，而不是"怎么做"

---

#### 5.2 Guidelines for Effective Pseudocode
#### 5.2 有效伪代码的指南

When writing pseudocode in specifications, follow these principles:

在规格中编写伪代码时，遵循以下原则：

1. **Emphasize Logic Flow**: Show the sequence of operations and decision points
1. **强调逻辑流程**：展示操作序列和决策点

2. **Highlight Key Decisions**: Make architectural choices and design rationale explicit
2. **突出关键决策**：明确架构选择和设计理由

3. **Avoid Language-Specific Details**: Don't use specific APIs, syntax, or library calls
3. **避免特定语言细节**：不要使用特定的API、语法或库调用

4. **Use Descriptive Names**: Variable and function names should be self-explanatory
4. **使用描述性名称**：变量和函数名应该是自解释的

5. **Include Comments**: Explain the "why" behind non-obvious logic
5. **包含注释**：解释非显而易见逻辑背后的"为什么"

6. **Keep It Simple**: Omit error handling, type annotations, and boilerplate unless critical to understanding
6. **保持简单**：省略错误处理、类型注解和样板代码，除非对理解至关重要

---

#### 5.3 Example Comparison
#### 5.3 示例对比

**❌ Detailed Code (Avoid):**
**❌ 详细代码（避免）：**

```rust
// DON'T: Too implementation-specific, contains syntax details
// 不要：过于特定于实现，包含语法细节
pub async fn sync_card(&self, card_id: Uuid) -> Result<(), SyncError> {
    let card = self.store.get_card(card_id).await
        .map_err(|e| SyncError::StorageError(e))?;

    let loro_doc = LoroDoc::new();
    loro_doc.set_peer_id(self.peer_id);

    let map = loro_doc.get_map("card");
    map.insert("title", card.title.clone())?;
    map.insert("content", card.content.clone())?;
    map.insert("updated_at", card.updated_at.timestamp())?;

    let snapshot = loro_doc.export_snapshot();
    self.sync_service.send(snapshot).await?;

    Ok(())
}
```

**✅ Pseudocode (Preferred):**
**✅ 伪代码（推荐）：**

```
// DO: Focus on logic and design intent
// 推荐：关注逻辑和设计意图

function sync_card(card_id):
    // Step 1: Retrieve card from local storage
    // 步骤1：从本地存储检索卡片
    card = get_card_from_store(card_id)

    // Step 2: Convert to CRDT representation
    // 步骤2：转换为CRDT表示
    // Design decision: Use map structure for field-level merging
    // 设计决策：使用映射结构实现字段级合并
    crdt_doc = create_crdt_document()
    crdt_doc.add_field("title", card.title)
    crdt_doc.add_field("content", card.content)
    crdt_doc.add_field("updated_at", card.updated_at)

    // Step 3: Send to sync service
    // 步骤3：发送到同步服务
    // Note: Sync service handles network transport and conflict resolution
    // 注意：同步服务处理网络传输和冲突解决
    sync_service.send(crdt_doc)

    return success
```

**Key Differences:**
**关键区别：**

| Aspect | Detailed Code | Pseudocode |
|--------|---------------|------------|
| **Focus** | How to implement | What happens |
| **关注点** | 如何实现 | 发生什么 |
| **Syntax** | Rust-specific | Language-agnostic |
| **语法** | Rust特定 | 与语言无关 |
| **Error Handling** | Explicit Result types | Omitted for clarity |
| **错误处理** | 显式Result类型 | 为清晰省略 |
| **APIs** | Loro library calls | Generic operations |
| **API** | Loro库调用 | 通用操作 |
| **Comments** | Implementation notes | Design rationale |
| **注释** | 实现说明 | 设计理由 |

---

#### 5.4 When to Use Detailed Code
#### 5.4 何时使用详细代码

In rare cases, detailed code examples MAY be appropriate:

在极少数情况下，详细代码示例可能是合适的：

- **API Contracts**: When defining exact function signatures or interfaces
- **API契约**：定义精确的函数签名或接口时
- **Data Formats**: When specifying exact JSON, SQL, or protocol structures
- **数据格式**：指定精确的JSON、SQL或协议结构时
- **Critical Algorithms**: When the specific algorithm is part of the requirement
- **关键算法**：特定算法是需求的一部分时

Even in these cases, accompany detailed code with explanatory comments about design intent.

即使在这些情况下，也应在详细代码中附带关于设计意图的解释性注释。

---

#### 5.5 Pseudocode Format Template
#### 5.5 伪代码格式模板

Use this template for pseudocode blocks:

使用此模板编写伪代码块：

```
function operation_name(parameters):
    // High-level description of what this does
    // 这个操作的高层描述

    // Step 1: First major operation
    // 步骤1：第一个主要操作
    result1 = do_something(parameters)

    // Step 2: Decision point
    // 步骤2：决策点
    if condition:
        // Design decision: Why we chose this path
        // 设计决策：为什么选择这条路径
        handle_case_a()
    else:
        handle_case_b()

    // Step 3: Final operation
    // 步骤3：最终操作
    // Note: Important context about this step
    // 注意：关于此步骤的重要上下文
    finalize(result1)

    return success
```

---

## Complete Example
## 完整示例

Here is a complete example specification:
以下是一个完整的示例规格：

```markdown
# Card Creation Specification
# 卡片创建规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [pool/model.md](../pool/model.md)
**依赖**: [pool/model.md](../pool/model.md)

**Related Tests**: `rust/tests/card_creation_test.rs`
**相关测试**: `rust/tests/card_creation_test.rs`

---

## Overview
## 概述

This specification defines card creation behavior in the CardMind system. Cards are automatically associated with the device's joined pool and synchronized across devices.

本规格定义了 CardMind 系统中的卡片创建行为。卡片自动关联到设备已加入的池，并在设备间同步。

---

## Requirement: Automatic pool association
## 需求：自动池关联

When a user creates a new card, the system SHALL automatically associate the card with the device's joined pool.

当用户创建新卡片时，系统应自动将卡片关联到设备已加入的池。

### Scenario: Create card in joined pool
### 场景：在已加入池中创建卡片

- **GIVEN**: the device has joined a pool
- **前置条件**：设备已加入一个池
- **WHEN**: user creates a new card with title and content
- **操作**：用户创建包含标题和内容的新卡片
- **THEN**: the card SHALL be created with a unique UUID v7 identifier
- **预期结果**：卡片应使用唯一的 UUID v7 标识符创建
- **AND**: the card SHALL be added to the joined pool's card list
- **并且**：卡片应添加到已加入池的卡片列表
- **AND**: the card SHALL be visible to all devices in the pool
- **并且**：该池中的所有设备应可见该卡片

### Scenario: Reject card creation when no pool joined
### 场景：未加入池时拒绝创建卡片

- **GIVEN**: the device has not joined any pool
- **前置条件**：设备未加入任何池
- **WHEN**: user attempts to create a new card
- **操作**：用户尝试创建新卡片
- **THEN**: the system SHALL reject the request with error code `NO_POOL_JOINED`
- **预期结果**：系统应以错误码 `NO_POOL_JOINED` 拒绝请求
- **AND**: no card SHALL be created
- **并且**：不应创建任何卡片

---

## Requirement: Unique identifier generation
## 需求：唯一标识符生成

The system SHALL generate a unique UUID v7 identifier for each newly created card.

系统应为每个新创建的卡片生成唯一的 UUID v7 标识符。

### Scenario: Generate time-sortable UUID
### 场景：生成时间可排序的 UUID

- **GIVEN**: the system is ready to create a new card
- **前置条件**：系统准备创建新卡片
- **WHEN**: card creation process begins
- **操作**：卡片创建过程开始
- **THEN**: a UUID v7 SHALL be generated using current timestamp
- **预期结果**：应使用当前时间戳生成 UUID v7
- **AND**: the UUID SHALL be globally unique
- **并且**：UUID 应全局唯一
- **AND**: the UUID SHALL be lexicographically sortable by creation time
- **并且**：UUID 应可按创建时间进行字典序排序

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/card_creation_test.rs`
**测试文件**: `rust/tests/card_creation_test.rs`

**Unit Tests**:
**单元测试**:
- `it_should_create_card_with_uuid_v7()` - Verify UUID v7 generation
- `it_should_create_card_with_uuid_v7()` - 验证 UUID v7 生成
- `it_should_add_card_to_joined_pool()` - Verify pool association
- `it_should_add_card_to_joined_pool()` - 验证池关联
- `it_should_reject_creation_without_joined_pool()` - Verify error handling
- `it_should_reject_creation_without_joined_pool()` - 验证错误处理

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] UUID v7 IDs are time-ordered
- [ ] UUID v7 ID 按时间排序
- [ ] Cards auto-join current pool
- [ ] 卡片自动加入当前池
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Architecture Decision Records**:
**架构决策记录**:
- [ADR-0001: Single Pool Ownership](../../docs/adr/0001-single-pool-ownership.md)
- [ADR-0001: 单池所有权](../../docs/adr/0001-single-pool-ownership.md)

**Related Specs**:
**相关规格**:
- [pool/model.md](../pool/model.md) - Pool model specification
- [pool/model.md](../pool/model.md) - 池模型规格

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
```

---

## Template
## 模板

Use this template when creating new specifications:
创建新规格时使用此模板：

```markdown
# [Feature Name] Specification
# [功能名称] 规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Draft
**状态**: 草稿

**Dependencies**: [spec.md](path/to/spec.md)
**依赖**: [spec.md](path/to/spec.md)

**Related Tests**: `path/to/test.rs`
**相关测试**: `path/to/test.rs`

---

## Overview
## 概述

[English description]

[中文描述]

---

## Requirement: [Requirement Title]
## 需求：[需求标题]

[English requirement statement using SHALL/SHOULD/MAY]

[中文需求陈述使用"应"/"宜"/"可"]

### Scenario: [Scenario Title]
### 场景：[场景标题]

- **GIVEN**: [precondition]
- **前置条件**：[前置条件]
- **WHEN**: [action]
- **操作**：[操作]
- **THEN**: [expected result]
- **预期结果**：[预期结果]
- **AND**: [additional result]
- **并且**：[附加结果]

---

## Test Coverage
## 测试覆盖

**Test File**: `path/to/test.rs`
**测试文件**: `path/to/test.rs`

**Unit Tests**:
**单元测试**:
- `test_name()` - [description]
- `test_name()` - [描述]

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [spec.md](path) - [description]
- [spec.md](path) - [描述]

---

**Last Updated**: YYYY-MM-DD
**最后更新**: YYYY-MM-DD

**Authors**: CardMind Team
**作者**: CardMind Team
```

---

## Validation Checklist
## 验证清单

Before submitting a specification, verify:
提交规格前，请验证：

- [ ] All headings use two-line format (English + Chinese)
- [ ] 所有标题都使用两行格式（英文 + 中文）

- [ ] All metadata uses two-line format
- [ ] 所有元数据都使用两行格式

- [ ] All scenario clauses use two-line format
- [ ] 所有场景子句都使用两行格式

- [ ] SHALL/SHOULD/MAY keywords used correctly
- [ ] SHALL/SHOULD/MAY 关键字使用正确

- [ ] All scenarios follow GIVEN-WHEN-THEN structure
- [ ] 所有场景遵循 GIVEN-WHEN-THEN 结构

- [ ] Dependencies use Markdown links with relative paths
- [ ] 依赖使用 Markdown 链接和相对路径

- [ ] Test cases listed and mapped to scenarios
- [ ] 测试用例已列出并映射到场景

- [ ] Chinese translations accurate and consistent
- [ ] 中文翻译准确且一致

- [ ] Describes stable state, not changes
- [ ] 描述稳定状态，而非变更

---

## Tools and References
## 工具和参考

**Validation Tool**: `tool/verify_spec_sync.dart`
**验证工具**: `tool/verify_spec_sync.dart`

**Example Specs**: See `openspec/specs/domain/` for reference implementations
**示例规格**: 参考 `openspec/specs/domain/` 中的实现

**Related Guides**:
**相关指南**:
- [spec_format_standard.md](spec_format_standard.md) - Main spec vs delta spec distinction
- [spec_format_standard.md](spec_format_standard.md) - 主规格与 delta spec 的区别
- [spec_coding_guide.md](spec_coding_guide.md) - Spec coding implementation guide
- [spec_coding_guide.md](spec_coding_guide.md) - Spec coding 实施指南

---

**Questions?** Refer to existing specs in `openspec/specs/domain/` as examples.
**有疑问？** 参考 `openspec/specs/domain/` 中现有的规格作为示例。

---

## Spec-Code-Test Mapping Conventions
## 规格-代码-测试映射约定

**Purpose**: Establish clear traceability from specifications to code and tests using semantic naming.
**目的**: 使用语义化命名建立从规格到代码和测试的清晰追踪关系。

### Naming Philosophy
### 命名哲学

**Use semantic, descriptive names instead of numeric codes.**
**使用语义化、描述性的名称而不是数字编码。**

**Why semantic naming?**
**为什么使用语义化命名？**
- **Human-readable**: Immediately understand what the test covers
- **人类可读**: 立即理解测试覆盖的内容
- **AI-friendly**: Tools can infer relationships without lookup tables
- **AI友好**: 工具可以推断关系而无需查找表
- **Maintainable**: No need to maintain separate numbering systems
- **易维护**: 无需维护单独的编号系统
- **Self-documenting**: File names describe their purpose
- **自文档化**: 文件名描述其用途

### Rust Module Mapping
### Rust 模块映射

**Convention**: Test filename semantically matches the spec and implementation
**约定**: 测试文件名语义上匹配规格和实现

| Spec File | Test File | Code File |
|-----------|-----------|-----------|
| `domain/pool/model.md` | `rust/tests/pool_model_test.rs` | `rust/src/models/pool.rs` |
| `architecture/sync/service.md` | `rust/tests/sync_service_test.rs` | `rust/src/services/sync_service.rs` |
| `architecture/sync/peer_discovery.md` | `rust/tests/peer_discovery_test.rs` | `rust/src/network/peer_discovery.rs` |
| `architecture/storage/card_store.md` | `rust/tests/card_store_test.rs` | `rust/src/storage/card_store.rs` |
| `architecture/storage/device_config.md` | `rust/tests/device_config_test.rs` | `rust/src/models/device_config.rs` |

**Naming Rules**:
**命名规则**:
1. Test file: `{feature}_test.rs` (lowercase, underscores, descriptive)
2. Test file: `{feature}_test.rs` (小写，下划线，描述性)
3. Test functions: `it_should_{behavior}()` (BDD style)
4. Test functions: `it_should_{behavior}()` (BDD 风格)

**Example Test Structure**:
**测试结构示例**:
```rust
// rust/tests/pool_model_test.rs
// Spec: openspec/specs/domain/pool/model.md
// 规格: openspec/specs/domain/pool/model.md

#[cfg(test)]
mod pool_model_test {
    use super::*;

    #[test]
    fn it_should_enforce_single_pool_constraint() {
        // GIVEN: Device has joined a pool
        // 前置条件: 设备已加入一个池

        // WHEN: Attempting to join another pool
        // 操作: 尝试加入另一个池

        // THEN: Operation fails with error
        // 预期结果: 操作失败并返回错误
    }
}
```

### Flutter Module Mapping
### Flutter 模块映射

**Convention**: Spec file path maps to test directory structure
**约定**: 规格文件路径映射到测试目录结构

| Spec File | Test File | Widget File |
|-----------|-----------|-------------|
| `ui/screens/mobile/home_screen.md` | `test/specs/home_screen_spec_test.dart` | `lib/screens/home.dart` |
| `ui/components/shared/note_card.md` | `test/specs/note_card_component_spec_test.dart` | `lib/widgets/components/note_card.dart` |
| `ui/adaptive/layouts.md` | `test/specs/responsive_layout_spec_test.dart` | `lib/adaptive/layouts.dart` |

**Naming Rules**:
**命名规则**:
1. Spec test: `test/specs/{feature}_spec_test.dart`
2. Spec test: `test/specs/{feature}_spec_test.dart`
3. Widget test: `test/widgets/{widget}_test.dart`
4. Widget test: `test/widgets/{widget}_test.dart`
5. Integration test: `test/integration/{feature}_test.dart`
6. Integration test: `test/integration/{feature}_test.dart`

**Example Test Structure**:
**测试结构示例**:
```dart
// test/specs/home_screen_spec_test.dart
// Spec: ui/screens/mobile/home_screen.md
// 规格: ui/screens/mobile/home_screen.md

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Screen Specification', () {
    testWidgets('it should display card list', (tester) async {
      // GIVEN: User has cards in the pool
      // 前置条件: 用户池中有卡片

      // WHEN: Home screen loads
      // 操作: 主屏幕加载

      // THEN: Card list is displayed
      // 预期结果: 显示卡片列表
    });
  });
}
```

**Mapping Documentation**:
**映射文档**:

**Rust Mapping**: Documented in spec file's "Related Tests" metadata
**Rust 映射**: 在规格文件的"相关测试"元数据中记录

```markdown
**Related Tests**: `rust/tests/pool_model_test.rs`
**相关测试**: `rust/tests/pool_model_test.rs`
```

**Flutter Mapping**: Documented in [FLUTTER_SPEC_TEST_MAP.md](../../docs/testing/FLUTTER_SPEC_TEST_MAP.md)
**Flutter 映射**: 记录在 [FLUTTER_SPEC_TEST_MAP.md](../../docs/testing/FLUTTER_SPEC_TEST_MAP.md)

### Verification
### 验证

**Check Rust Mapping**:
**检查 Rust 映射**:
```bash
# List all test files
ls rust/tests/*_test.rs

# Verify spec reference in test file
grep "Spec:" rust/tests/pool_model_test.rs
```

**Check Flutter Mapping**:
**检查 Flutter 映射**:
```bash
# List all spec tests
find test/specs -name "*_spec_test.dart"

# Check mapping table
cat docs/testing/FLUTTER_SPEC_TEST_MAP.md
```

### Best Practices
### 最佳实践

1. **Always create spec before code**: Spec → Test → Code
2. **总是先创建规格再写代码**: 规格 → 测试 → 代码

3. **Use descriptive names in commits**: "feat(pool): implement single pool constraint"
4. **在提交中使用描述性名称**: "feat(pool): implement single pool constraint"

5. **Link spec in test comments**: Add spec file path at top of test file
6. **在测试注释中链接规格**: 在测试文件顶部添加规格文件路径

7. **Update mapping when refactoring**: Keep spec-test-code mapping current
8. **重构时更新映射**: 保持规格-测试-代码映射最新

9. **One feature per test file**: Keep tests focused and cohesive
10. **每个测试文件一个功能**: 保持测试专注和内聚

### Coverage Tracking
### 覆盖率追踪

**Current Coverage**:
**当前覆盖率**:
- Rust: 4/87 specs have explicit tests (~5%)
- Rust: 4/87 规格有显式测试 (~5%)
- Flutter: 28/60 specs have tests (~47%)
- Flutter: 28/60 规格有测试 (~47%)

**Goal**: 90% spec coverage by end of Phase 4
**目标**: Phase 4 结束时达到 90% 规格覆盖率

**Tracking**: See [DOCUMENTATION_MAP.md](../../docs/DOCUMENTATION_MAP.md) for full mapping
**追踪**: 查看 [DOCUMENTATION_MAP.md](../../docs/DOCUMENTATION_MAP.md) 获取完整映射

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Maintainers**: CardMind Team
**维护者**: CardMind Team
