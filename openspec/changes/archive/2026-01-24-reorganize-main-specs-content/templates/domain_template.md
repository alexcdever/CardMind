# [领域实体名称] 领域模型规格
# [Domain Entity Name] Domain Model Specification

**Version** | **版本**: 1.0.0
**Status** | **状态**: Draft | 草稿
**Dependencies** | **依赖**: None
**Related Tests** | **相关测试**: N/A

---

## Overview | 概述

[简要描述该领域实体的业务含义和在系统中的角色]

[Brief description of the business meaning and role of this domain entity in the system]

---

## Requirement: [领域实体定义] | Domain Entity Definition

系统应定义 [实体名称] 领域实体及其核心属性。

The system SHALL define the [Entity Name] domain entity and its core attributes.

### Scenario: [实体包含核心属性] | Entity contains core attributes

- **GIVEN** | **前置条件**: [前置条件]
- **WHEN** | **操作**: [操作]
- **THEN** | **预期结果**: [预期结果]
- **AND** | **并且**: [附加结果]

---

## Requirement: [业务规则] | Business Rule

系统应强制执行 [业务规则描述]。

The system SHALL enforce [business rule description].

### Scenario: [规则场景] | Rule scenario

- **GIVEN** | **前置条件**: [前置条件]
- **WHEN** | **操作**: [操作]
- **THEN** | **预期结果**: [预期结果]

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `path/to/test.rs`

**Unit Tests** | **单元测试**:
- `test_name()` - Test description | 测试描述

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass | 所有单元测试通过
- [ ] Business rules are enforced | 业务规则得到执行
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [related_spec.md](path/to/related_spec.md) - Description | 描述

**ADRs** | **架构决策记录**:
- [ADR-XXXX](../../docs/adr/XXXX-title.md) - Decision title | 决策标题

---

**Last Updated** | **最后更新**: YYYY-MM-DD
**Authors** | **作者**: CardMind Team
