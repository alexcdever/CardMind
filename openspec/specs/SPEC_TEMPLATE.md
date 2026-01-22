# [Feature Name] Specification
# [功能名称] 规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Draft | Active | Deprecated
**Dependencies** | **依赖**: [other_spec.md](path/to/other_spec.md)
**Related Tests** | **相关测试**: `path/to/test_file.rs` or `path/to/test_file.dart`

---

## 📌 格式说明：主规格 vs Delta Spec

**本模板用于主规格（Main Spec）**:
- 位置：`openspec/specs/`
- 风格：描述系统的**稳定、已实现状态**（"是什么"）
- 禁止使用：Transformation、Core Changes、Behavior Change、Key Changes 等变更描述

**Delta Spec（变更规格）**:
- 位置：`openspec/changes/<change-name>/specs/`
- 风格：描述**正在进行的变更**（"如何改造"）
- 生命周期：变更完成后，改写为主规格风格并同步到 `openspec/specs/`

详见：[spec_format_standard](./engineering/spec_format_standard.md)

---

## Overview | 概述

[Brief description of the feature and its purpose]
[功能及其目的的简要描述]

---

## Requirement: [Requirement Title]
## 需求：[需求标题]

The system SHALL [requirement statement in active voice].
系统应[主动语态的需求陈述]。

### Scenario: [Scenario Title]
### 场景：[场景标题]

- **GIVEN** [precondition]
- **前置条件**：[前置条件]
- **WHEN** [action or event]
- **操作**：[操作或事件]
- **THEN** [expected outcome]
- **预期结果**：[预期结果]
- **AND** [additional outcome]
- **并且**：[附加结果]

### Scenario: [Another Scenario Title]
### 场景：[另一个场景标题]

- **GIVEN** [precondition]
- **前置条件**：[前置条件]
- **WHEN** [action or event]
- **操作**：[操作或事件]
- **THEN** [expected outcome]
- **预期结果**：[预期结果]

---

## Requirement: [Another Requirement Title]
## 需求：[另一个需求标题]

The system SHALL [requirement statement].
系统应[需求陈述]。

### Scenario: [Scenario Title]
### 场景：[场景标题]

- **GIVEN** [precondition]
- **前置条件**：[前置条件]
- **WHEN** [action or event]
- **操作**：[操作或事件]
- **THEN** [expected outcome]
- **预期结果**：[预期结果]

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `path/to/spec_test.rs` or `path/to/spec_test.dart`

**Unit Tests** | **单元测试**:
- `it_should_[test_description]()` - [What it tests | 测试内容]
- `it_should_[test_description]()` - [What it tests | 测试内容]

**Integration Tests** | **集成测试**:
- `it_should_[test_description]()` - [What it tests | 测试内容]

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass | 所有单元测试通过
- [ ] All integration tests pass | 所有集成测试通过
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**ADRs** | **架构决策记录**:
- [ADR-XXXX: Decision Title](../adr/xxxx-decision-title.md)

**Related Specs** | **相关规格**:
- [related_spec.md](path/to/related_spec.md)

---

**Last Updated** | **最后更新**: YYYY-MM-DD
**Authors** | **作者**: CardMind Team
