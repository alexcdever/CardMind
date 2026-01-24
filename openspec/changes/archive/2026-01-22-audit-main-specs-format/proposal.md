# Proposal: Audit and Standardize Main Spec Format

## Why

主规格目录 (`openspec/specs/`) 中发现部分规格文档使用了变更风格的写法，包含 "Transformation"、"Behavior Change"、"Key Changes" 等描述变更过程的内容。根据 OpenSpec 规范，主规格应该描述系统的**稳定、已实现状态**（"是什么"），而不是**如何改造**（"如何变更"）。变更风格的规格应该作为 delta spec 存在于 `openspec/changes/<change-name>/specs/` 中，在变更完成后再同步并改写为稳定的主规格格式。

需要立即审查和修正，以确保主规格目录的一致性和可维护性。

## What Changes

- 审查 `openspec/specs/` 下所有规格文档，识别不符合主规格标准的文档
- 识别标准：
  - 标题包含 "Transformation"
  - 正文包含 "Core Changes"、"Key Changes"、"Behavior Change" 等变更描述
  - Overview 描述"如何改造"而非"是什么"
- 将变更风格的规格改写为稳定描述风格：
  - 标题从 "X Transformation Specification" 改为 "X Specification"
  - 移除 "Core Changes"、"Key Changes" 等变更历史段落
  - 改写 Overview 为描述最终状态
  - 保留所有需求和场景（Requirement/Scenario）
  - 代码示例中的注释从 "Behavior Change" 改为描述当前行为
- 创建格式审查检查清单和标准化指南
- 更新 `SPEC_TEMPLATE.md` 和 `SPEC_EXAMPLE.md`，明确主规格 vs delta spec 的区别

## Capabilities

### New Capabilities

- `spec-format-standard`: 定义主规格文档的标准格式要求，包括结构、语言风格、禁止使用的变更描述关键词等

### Modified Capabilities

- `card_store`: 需要从 "CardStore Transformation Specification" 改写为 "CardStore Specification"，移除变更风格描述
- `device_config`: 需要移除 "Key Changes" 段落，改写为稳定描述

## Impact

**受影响的规格文档**:
- `openspec/specs/domain/card_store.md` - 需要重写
- `openspec/specs/domain/device_config.md` - 需要重写

**受影响的文档**:
- `openspec/specs/SPEC_TEMPLATE.md` - 需要补充说明
- `openspec/specs/SPEC_EXAMPLE.md` - 需要补充说明
- `openspec/specs/README.md` - 可能需要更新状态

**受影响的流程**:
- OpenSpec 工作流中 delta spec 同步到主规格的步骤
- 规格审查和验收标准

**无代码影响**: 这是纯文档整理工作，不影响实现代码。
