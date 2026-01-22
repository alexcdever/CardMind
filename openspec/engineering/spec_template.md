# 规格模板

**版本**：1.0.0
**状态**：草稿 | 生效中 | 已废弃
**依赖**：[other_spec.md](path/to/other_spec.md)
**相关测试**：`path/to/test_file.rs` 或 `path/to/test_file.dart`

---

## 格式说明：主规格 vs Delta Spec

**本模板用于主规格（Main Spec）**：
- 位置：`openspec/specs/`
- 风格：描述系统的**稳定、已实现状态**（"是什么"）
- 禁止使用：Transformation、Core Changes、Behavior Change、Key Changes 等变更描述

**Delta Spec（变更规格）**：
- 位置：`openspec/changes/<change-name>/specs/`
- 风格：描述**正在进行的变更**（"如何改造"）
- 生命周期：变更完成后，改写为主规格风格并同步到 `openspec/specs/`

详见：[spec_format_standard](./engineering/spec_format_standard.md)

---

## 概述

功能及其目的的简要描述。

---

## 需求：需求标题

系统应[主动语态的需求陈述]。

### 场景：场景标题

- **前置条件**：前置条件
- **操作**：操作或事件
- **预期结果**：预期结果
- **并且**：附加结果

### 场景：另一个场景标题

- **前置条件**：前置条件
- **操作**：操作或事件
- **预期结果**：预期结果

---

## 需求：另一个需求标题

系统应[需求陈述]。

### 场景：场景标题

- **前置条件**：前置条件
- **操作**：操作或事件
- **预期结果**：预期结果

---

## 测试覆盖

**测试文件**：`path/to/spec_test.rs` 或 `path/to/spec_test.dart`

**单元测试**：
- `it_should_[test_description]()` - 测试内容
- `it_should_[test_description]()` - 测试内容

**集成测试**：
- `it_should_[test_description]()` - 测试内容

**验收标准**：
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**架构决策记录**：
- [ADR-XXXX: 决策标题](../adr/xxxx-decision-title.md)

**相关规格**：
- [related_spec.md](path/to/related_spec.md)

---

**最后更新**：YYYY-MM-DD
**作者**：CardMind Team
