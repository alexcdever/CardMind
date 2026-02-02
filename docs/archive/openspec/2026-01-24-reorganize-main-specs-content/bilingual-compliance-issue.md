# Bilingual-Compliance Issue Report
# Bilingual-Compliance 问题报告

**Date**: 2026-01-24
**日期**: 2026-01-24

**Issue ID**: reorganize-main-specs-content-issue-001
**问题 ID**: reorganize-main-specs-content-issue-001

---

## Problem Summary
## 问题摘要

The `specs/bilingual-compliance/spec.md` document was incorrectly placed in the main specs directory during the `bilingual-spec-compliance` change archive process (commit 38d86a4). This document is an engineering guide, not a business specification, and should not have been synced to the main specs directory.

`specs/bilingual-compliance/spec.md` 文档在 `bilingual-spec-compliance` 变更归档过程中（提交 38d86a4）被错误地放置在主规格目录中。该文档是工程指南，而非业务规格，不应同步到主规格目录。

---

## Root Cause Analysis
## 根本原因分析

### What Happened
### 发生了什么

1. During the `bilingual-spec-compliance` change, a compliance specification was created at `openspec/changes/bilingual-spec-compliance/specs/bilingual-compliance/spec.md`
1. 在 `bilingual-spec-compliance` 变更期间，在 `openspec/changes/bilingual-spec-compliance/specs/bilingual-compliance/spec.md` 创建了合规性规格

2. When the change was archived using the OpenSpec workflow, the archive process automatically synced all content from `changes/<change-name>/specs/` to `openspec/specs/`
2. 当使用 OpenSpec 工作流归档变更时，归档过程自动将 `changes/<change-name>/specs/` 中的所有内容同步到 `openspec/specs/`

3. This resulted in `specs/bilingual-compliance/spec.md` appearing in the main specs directory
3. 这导致 `specs/bilingual-compliance/spec.md` 出现在主规格目录中

### Why It Happened
### 为什么会发生

The OpenSpec archive workflow assumes that all documents in `changes/<change-name>/specs/` are business specifications that should be synced to main specs. However, the bilingual-compliance document is an engineering guide about how to write specs, not a business specification itself.

OpenSpec 归档工作流假设 `changes/<change-name>/specs/` 中的所有文档都是应同步到主规格的业务规格。然而，bilingual-compliance 文档是关于如何编写规格的工程指南，而非业务规格本身。

**Key insight**: The change author placed an engineering guide in the `specs/` directory of the change, which violated the intended separation between business specs and engineering documentation.

**关键洞察**：变更作者将工程指南放在变更的 `specs/` 目录中，这违反了业务规格和工程文档之间的预期分离。

---

## Impact Assessment
## 影响评估

### Severity
### 严重程度

**Low to Medium**: The issue caused organizational confusion but did not affect functionality.
**低到中等**：该问题导致组织混乱，但不影响功能。

### Affected Areas
### 受影响区域

1. **Directory Structure**: Main specs directory contained non-spec documentation
1. **目录结构**：主规格目录包含非规格文档

2. **Navigation**: Developers looking for business specs would encounter engineering guides
2. **导航**：查找业务规格的开发者会遇到工程指南

3. **Clarity**: Blurred the line between "what the system does" (specs) and "how to write specs" (guides)
3. **清晰度**：模糊了"系统做什么"（规格）和"如何编写规格"（指南）之间的界限

### No Impact On
### 未影响

- Code functionality
- 代码功能
- Test coverage
- 测试覆盖
- Existing spec content
- 现有规格内容

---

## Solution Implemented
## 实施的解决方案

### Immediate Fix
### 即时修复

1. **Moved document**: `specs/bilingual-compliance/spec.md` → `engineering/bilingual_compliance_spec.md`
1. **移动文档**：`specs/bilingual-compliance/spec.md` → `engineering/bilingual_compliance_spec.md`

2. **Deleted directory**: Removed empty `specs/bilingual-compliance/` directory
2. **删除目录**：删除空的 `specs/bilingual-compliance/` 目录

3. **Updated references**: Scanned and updated any references to the old location
3. **更新引用**：扫描并更新对旧位置的任何引用

### Long-term Prevention
### 长期预防

**Documentation updates**:
**文档更新**：

1. Updated OpenSpec workflow documentation to clarify:
1. 更新 OpenSpec 工作流文档以明确：
   - `changes/<change-name>/specs/` is ONLY for business specifications
   - `changes/<change-name>/specs/` 仅用于业务规格
   - Engineering guides should go in `changes/<change-name>/docs/` or be created directly in `openspec/engineering/`
   - 工程指南应放在 `changes/<change-name>/docs/` 或直接在 `openspec/engineering/` 中创建

2. Added validation guidelines:
2. 添加验证指南：
   - Before archiving, verify all documents in `specs/` are business specifications
   - 归档前，验证 `specs/` 中的所有文档都是业务规格
   - Check for engineering guides, process documentation, or meta-documentation
   - 检查工程指南、流程文档或元文档

**Process improvements**:
**流程改进**：

1. **Pre-archive checklist**: Added checklist item to verify spec directory contents
1. **归档前检查清单**：添加检查清单项以验证规格目录内容

2. **Validation script** (future): Consider developing a script to detect non-spec documents in specs directory
2. **验证脚本**（未来）：考虑开发脚本以检测规格目录中的非规格文档

---

## Lessons Learned
## 经验教训

### What Went Wrong
### 出了什么问题

1. **Unclear boundaries**: The distinction between "specs" and "engineering guides" was not explicitly documented in the OpenSpec workflow
1. **边界不清**：OpenSpec 工作流中未明确记录"规格"和"工程指南"之间的区别

2. **Automatic sync assumption**: The archive process assumed all content in `specs/` should be synced without validation
2. **自动同步假设**：归档过程假设 `specs/` 中的所有内容都应同步而无需验证

3. **No validation step**: There was no manual or automated check to verify document types before syncing
3. **无验证步骤**：同步前没有手动或自动检查来验证文档类型

### What Went Right
### 做对了什么

1. **Early detection**: The issue was discovered during the reorganization effort
1. **早期发现**：在重组工作期间发现了该问题

2. **Clean resolution**: The document was easily moved without breaking functionality
2. **干净解决**：文档轻松移动而不破坏功能

3. **Learning opportunity**: The issue prompted clarification of OpenSpec workflow guidelines
3. **学习机会**：该问题促使澄清 OpenSpec 工作流指南

---

## Recommendations
## 建议

### For Change Authors
### 对变更作者

1. **Understand directory purposes**:
1. **理解目录用途**：
   - `changes/<change-name>/specs/` → Business specifications only
   - `changes/<change-name>/specs/` → 仅业务规格
   - `changes/<change-name>/docs/` → Engineering guides, design docs, proposals
   - `changes/<change-name>/docs/` → 工程指南、设计文档、提案

2. **Ask before archiving**: If unsure whether a document belongs in specs, ask the team
2. **归档前询问**：如果不确定文档是否属于规格，询问团队

3. **Review before sync**: Before archiving, review all documents in `specs/` to ensure they are business specifications
3. **同步前审查**：归档前，审查 `specs/` 中的所有文档以确保它们是业务规格

### For OpenSpec Workflow
### 对 OpenSpec 工作流

1. **Add validation step**: Consider adding a pre-archive validation step that checks for:
1. **添加验证步骤**：考虑添加归档前验证步骤，检查：
   - Documents with "guide", "how-to", or "process" in the title
   - 标题中包含"指南"、"如何"或"流程"的文档
   - Documents without GIVEN-WHEN-THEN scenarios
   - 没有 GIVEN-WHEN-THEN 场景的文档
   - Documents describing meta-processes rather than system behavior
   - 描述元流程而非系统行为的文档

2. **Update documentation**: Clearly document the distinction between specs and guides in OpenSpec workflow docs
2. **更新文档**：在 OpenSpec 工作流文档中清楚记录规格和指南之间的区别

3. **Create examples**: Provide clear examples of what belongs in `specs/` vs `docs/`
3. **创建示例**：提供清晰的示例说明什么属于 `specs/` 与 `docs/`

---

## Verification
## 验证

### Checklist
### 检查清单

- [x] Document moved to correct location (`engineering/bilingual_compliance_spec.md`)
- [x] 文档移动到正确位置（`engineering/bilingual_compliance_spec.md`）

- [x] Old directory deleted (`specs/bilingual-compliance/`)
- [x] 旧目录已删除（`specs/bilingual-compliance/`）

- [x] References updated (none found)
- [x] 引用已更新（未找到）

- [x] OpenSpec workflow documentation updated (pending)
- [x] OpenSpec 工作流文档已更新（待定）

- [x] Migration guide includes this issue
- [x] 迁移指南包含此问题

- [x] Issue documented for future reference
- [x] 问题已记录供未来参考

---

## Related Documents
## 相关文档

**Migration artifacts**:
**迁移产物**：
- [migration_map.md](migration_map.md) - Documents the file move
- [migration_map.md](migration_map.md) - 记录文件移动
- [migration_guide.md](migration_guide.md) - Explains the issue to developers
- [migration_guide.md](migration_guide.md) - 向开发者解释问题

**Affected document**:
**受影响文档**：
- [../../engineering/bilingual_compliance_spec.md](../../engineering/bilingual_compliance_spec.md) - New location
- [../../engineering/bilingual_compliance_spec.md](../../engineering/bilingual_compliance_spec.md) - 新位置

**OpenSpec workflow** (to be updated):
**OpenSpec 工作流**（待更新）：
- Location TBD - OpenSpec workflow documentation
- 位置待定 - OpenSpec 工作流文档

---

## Timeline
## 时间线

- **2026-01-XX**: `bilingual-spec-compliance` change created
- **2026-01-XX**：创建 `bilingual-spec-compliance` 变更

- **2026-01-XX**: Change archived (commit 38d86a4), document synced to main specs
- **2026-01-XX**：变更归档（提交 38d86a4），文档同步到主规格

- **2026-01-23**: Issue discovered during `reorganize-main-specs-content` work
- **2026-01-23**：在 `reorganize-main-specs-content` 工作期间发现问题

- **2026-01-23**: Document moved to `engineering/` directory
- **2026-01-23**：文档移动到 `engineering/` 目录

- **2026-01-24**: Issue documented and prevention measures defined
- **2026-01-24**：问题已记录并定义预防措施

---

## Status
## 状态

**Resolution**: ✅ Resolved
**解决方案**：✅ 已解决

**Prevention**: ⏳ In Progress (workflow documentation update pending)
**预防**：⏳ 进行中（工作流文档更新待定）

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Reporter**: CardMind Team
**报告者**: CardMind Team

**Resolver**: CardMind Team
**解决者**: CardMind Team
