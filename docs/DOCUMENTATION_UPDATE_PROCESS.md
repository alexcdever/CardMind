# 文档更新流程指南
# Documentation Update Process Guide

**版本 Version**: 1.0.0
**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team

---

## 📖 概述
## Overview

本文档定义了 CardMind 项目中文档的创建、更新和维护流程，确保文档与代码保持同步。
This document defines the process for creating, updating, and maintaining documentation in the CardMind project, ensuring documentation stays in sync with code.

---

## 🔄 文档生命周期
## Documentation Lifecycle

```
需求 → 规格 → 测试 → 代码 → 审查 → 归档
Requirement → Spec → Test → Code → Review → Archive
```

---

## 📝 何时更新文档
## When to Update Documentation

### 1. 新增功能 (New Feature)
### New Feature

**流程 Process**:
1. 先写规格 (Write spec first)
2. 再写测试 (Write tests)
3. 最后写代码 (Write code last)

**需要更新的文档 Documents to Update**:
- [ ] 创建规格文档 (Create spec document)
- [ ] 更新 `openspec/specs/README.md` 索引
- [ ] 创建测试文件 (Create test file)
- [ ] 更新 `docs/testing/FLUTTER_SPEC_TEST_MAP.md` (如果是 Flutter)
- [ ] 更新 `docs/DOCUMENTATION_MAP.md` (如果是新模块)
- [ ] 更新 `README.md` (如果影响项目概览)

**示例 Example**:
```bash
# 1. 创建规格
touch openspec/specs/features/new_feature/spec.md

# 2. 更新索引
# 编辑 openspec/specs/README.md

# 3. 创建测试
touch test/specs/new_feature_spec_test.dart

# 4. 更新映射表
# 编辑 docs/testing/FLUTTER_SPEC_TEST_MAP.md
```

---

### 2. 修改功能 (Modify Feature)
### Modify Feature

**流程 Process**:
1. 先更新规格 (Update spec first)
2. 更新测试 (Update tests)
3. 更新代码 (Update code)

**需要更新的文档 Documents to Update**:
- [ ] 更新规格文档 (Update spec document)
- [ ] 更新规格版本号 (Update spec version)
- [ ] 更新测试 (Update tests)
- [ ] 更新 ADR (如果是架构变更)

**示例 Example**:
```markdown
# 在规格文档中
**Version**: 1.0.0 → 1.1.0
**Last Updated**: 2026-01-24

## Changelog
## 变更日志

### v1.1.0 (2026-01-24)
- Added: New validation rule
- 新增：新的验证规则
```

---

### 3. 架构变更 (Architecture Change)
### Architecture Change

**流程 Process**:
1. 先写 ADR (Write ADR first)
2. 更新规格 (Update specs)
3. 更新代码 (Update code)

**需要更新的文档 Documents to Update**:
- [ ] 创建新的 ADR (Create new ADR)
- [ ] 更新相关规格文档 (Update related specs)
- [ ] 更新 `docs/adr/README.md` 索引
- [ ] 更新 `docs/DOCUMENTATION_MAP.md`
- [ ] 更新 `CLAUDE.md` (如果影响开发指南)

**ADR 模板 ADR Template**:
```markdown
# ADR-XXXX: [Decision Title]
# ADR-XXXX: [决策标题]

**Status**: Proposed | Accepted | Deprecated
**状态**: 提议中 | 已接受 | 已废弃

**Date**: 2026-01-24
**日期**: 2026-01-24

## Context
## 背景

[Why this decision is needed]
[为什么需要这个决策]

## Decision
## 决策

[What we decided to do]
[我们决定做什么]

## Consequences
## 后果

[Impact of this decision]
[这个决策的影响]
```

---

### 4. 重构 (Refactoring)
### Refactoring

**流程 Process**:
1. 更新规格 (如果行为改变)
2. 更新测试 (如果接口改变)
3. 重构代码

**需要更新的文档 Documents to Update**:
- [ ] 更新规格文档 (如果行为改变)
- [ ] 更新 ADR (如果架构改变)
- [ ] 更新代码注释

**注意 Note**: 如果只是内部重构，不改变外部行为，则不需要更新规格。
If it's only internal refactoring without changing external behavior, no need to update specs.

---

## ✅ 文档更新检查清单
## Documentation Update Checklist

### PR 提交前检查 (Before Submitting PR)
### Before Submitting PR

**基础检查 Basic Checks**:
- [ ] 所有新增的文档链接都指向存在的文件
- [ ] 所有修改的文档都更新了"最后更新"日期
- [ ] 所有规格文档都遵循双语格式
- [ ] 所有测试文件都有对应的规格文档

**规格文档检查 Spec Document Checks**:
- [ ] 规格编号正确 (SP-{MODULE}-{NUMBER})
- [ ] 版本号已更新 (如果是修改)
- [ ] 依赖关系已声明
- [ ] 测试文件已关联
- [ ] 使用 SHALL/SHOULD/MAY 关键字
- [ ] 所有场景遵循 GIVEN-WHEN-THEN 结构

**索引更新检查 Index Update Checks**:
- [ ] `openspec/specs/README.md` 已更新 (如果新增规格)
- [ ] `docs/DOCUMENTATION_MAP.md` 已更新 (如果新增模块)
- [ ] `docs/testing/FLUTTER_SPEC_TEST_MAP.md` 已更新 (如果是 Flutter)
- [ ] `docs/adr/README.md` 已更新 (如果新增 ADR)

**链接验证 Link Verification**:
```bash
# 运行链接验证脚本
dart tool/verify_spec_mapping.dart

# 检查所有 markdown 链接
# (Phase 4 将提供自动化工具)
```

---

## 🔧 文档维护工具
## Documentation Maintenance Tools

### 1. 规格映射验证工具
### Spec Mapping Verification Tool

**用途 Purpose**: 验证规格-测试-代码映射关系
Verify spec-test-code mapping relationships

**使用方法 Usage**:
```bash
dart tool/verify_spec_mapping.dart
```

**输出 Output**:
- Rust 测试覆盖率
- Flutter 测试覆盖率
- 缺失测试清单
- 孤立测试警告

---

### 2. 规格同步验证工具 (已有)
### Spec Sync Verification Tool (Existing)

**用途 Purpose**: 验证规格文档格式和同步状态
Verify spec document format and sync status

**使用方法 Usage**:
```bash
dart tool/verify_spec_sync.dart
```

---

### 3. 链接检查工具 (Phase 4)
### Link Checker Tool (Phase 4)

**用途 Purpose**: 检查所有 markdown 文档中的链接有效性
Check validity of all links in markdown documents

**计划 Planned**:
```bash
# 将在 Phase 4 实现
dart tool/check_markdown_links.dart
```

---

## 📋 常见场景示例
## Common Scenario Examples

### 场景 1: 添加新的 UI 组件
### Scenario 1: Adding New UI Component

**步骤 Steps**:

1. **创建规格文档**
```bash
# 创建规格文件
touch openspec/specs/ui/components/shared/new_component.md

# 编辑规格文档
# 使用 openspec/engineering/spec_writing_guide.md 中的模板
```

2. **更新索引**
```bash
# 编辑 openspec/specs/README.md
# 在 UI Components 表格中添加新行
```

3. **创建测试文件**
```bash
# 创建 widget 测试
touch test/widgets/new_component_test.dart

# 创建 spec 测试
touch test/specs/new_component_spec_test.dart
```

4. **更新映射表**
```bash
# 编辑 docs/testing/FLUTTER_SPEC_TEST_MAP.md
# 在 Shared Components 表格中添加新行
```

5. **实现代码**
```bash
# 创建组件文件
touch lib/widgets/components/new_component.dart
```

6. **验证**
```bash
# 运行验证脚本
dart tool/verify_spec_mapping.dart

# 运行测试
flutter test test/widgets/new_component_test.dart
flutter test test/specs/new_component_spec_test.dart
```

---

### 场景 2: 修改现有功能
### Scenario 2: Modifying Existing Feature

**步骤 Steps**:

1. **更新规格文档**
```markdown
# 在规格文档中更新版本号
**Version**: 1.0.0 → 1.1.0

# 添加变更日志
## Changelog
### v1.1.0 (2026-01-24)
- Modified: Validation logic
- 修改：验证逻辑
```

2. **更新测试**
```dart
// 更新测试用例以反映新行为
testWidgets('it should validate with new rules', (tester) async {
  // ...
});
```

3. **更新代码**
```dart
// 实现新的验证逻辑
```

4. **验证**
```bash
# 运行测试确保所有测试通过
flutter test
```

---

### 场景 3: 创建架构决策记录
### Scenario 3: Creating Architecture Decision Record

**步骤 Steps**:

1. **创建 ADR 文件**
```bash
# 使用下一个编号
touch docs/adr/0006-新决策.md
```

2. **编写 ADR**
```markdown
# 使用 ADR 模板
# 包含: Context, Decision, Consequences
```

3. **更新 ADR 索引**
```bash
# 编辑 docs/adr/README.md
# 添加新 ADR 到列表
```

4. **更新相关规格**
```markdown
# 在相关规格文档中引用 ADR
**Related ADR**: [ADR-0006: 新决策](../../docs/adr/0006-新决策.md)
```

5. **更新导航地图**
```bash
# 编辑 docs/DOCUMENTATION_MAP.md
# 在相关模块中添加 ADR 引用
```

---

## 🚨 常见错误和解决方案
## Common Mistakes and Solutions

### 错误 1: 忘记更新索引
### Mistake 1: Forgetting to Update Indexes

**症状 Symptom**: 新文档创建了，但在索引中找不到
New document created but not found in indexes

**解决方案 Solution**:
- 检查 `openspec/specs/README.md`
- 检查 `docs/DOCUMENTATION_MAP.md`
- 检查 `docs/testing/FLUTTER_SPEC_TEST_MAP.md`

---

### 错误 2: 链接使用绝对路径
### Mistake 2: Using Absolute Paths in Links

**症状 Symptom**: 链接在 GitHub 上无法正常工作
Links don't work properly on GitHub

**解决方案 Solution**:
```markdown
# ❌ 错误
[spec.md](/openspec/specs/domain/spec.md)

# ✅ 正确
[spec.md](../../openspec/specs/domain/spec.md)
```

---

### 错误 3: 规格编号不一致
### Mistake 3: Inconsistent Spec Numbers

**症状 Symptom**: 规格编号与测试文件名不匹配
Spec number doesn't match test filename

**解决方案 Solution**:
```markdown
# 规格文档中
**Spec Number**: SP-CARD-001

# 测试文件名应该是
rust/tests/sp_card_001_spec.rs
```

---

### 错误 4: 忘记更新版本号
### Mistake 4: Forgetting to Update Version

**症状 Symptom**: 规格修改了但版本号没变
Spec modified but version unchanged

**解决方案 Solution**:
```markdown
# 每次修改规格都要更新版本号
**Version**: 1.0.0 → 1.1.0
**Last Updated**: 2026-01-24

# 并添加变更日志
## Changelog
### v1.1.0 (2026-01-24)
- [描述变更]
```

---

## 📊 文档质量指标
## Documentation Quality Metrics

### 目标指标 Target Metrics

| 指标 Metric | 当前 Current | 目标 Target |
|-------------|-------------|-------------|
| 规格测试覆盖率 | 47% | 90% |
| 文档断链数 | 0 | 0 |
| ADR 完整性 | 100% | 100% |
| 规格双语合规 | 85% | 100% |

### 监控方法 Monitoring Methods

**每周检查 Weekly Checks**:
```bash
# 运行验证脚本
dart tool/verify_spec_mapping.dart

# 检查覆盖率
# 目标: 每周提升 5%
```

**每月审查 Monthly Reviews**:
- 审查所有文档的"最后更新"日期
- 检查是否有超过 3 个月未更新的文档
- 审查 ADR 是否需要更新状态

---

## 🔄 文档审查流程
## Documentation Review Process

### PR 审查清单 PR Review Checklist

**审查者检查 Reviewer Checks**:
- [ ] 所有新增文档都有正确的元数据 (版本、日期、作者)
- [ ] 所有链接都使用相对路径
- [ ] 所有规格文档都遵循双语格式
- [ ] 索引已更新
- [ ] 测试文件已创建/更新
- [ ] 验证脚本通过

**自动化检查 Automated Checks** (Phase 4):
- [ ] Markdown 链接有效性
- [ ] 规格格式验证
- [ ] 测试覆盖率检查

---

## 📚 相关文档
## Related Documents

- [规格编写指南](../openspec/engineering/spec_writing_guide.md) - 如何编写规格
- [文档导航地图](./DOCUMENTATION_MAP.md) - 文档索引
- [Flutter 映射表](./testing/FLUTTER_SPEC_TEST_MAP.md) - Flutter 规格-测试映射
- [ADR 索引](./adr/README.md) - 架构决策记录

---

## 🆘 获取帮助
## Getting Help

**文档问题 Documentation Issues**:
- 发现断链: 提交 Issue 到 GitHub
- 文档不清晰: 提交 PR 改进
- 需要新文档: 在 Issue 中说明需求

**流程问题 Process Issues**:
- 不确定如何更新: 查看本文档的"常见场景示例"
- 验证脚本报错: 查看"常见错误和解决方案"
- 其他问题: 联系维护者

---

**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team
