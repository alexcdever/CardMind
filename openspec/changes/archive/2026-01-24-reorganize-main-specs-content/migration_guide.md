# Documentation Reorganization Migration Guide
# 文档重组迁移指南

**Version**: 1.0.0
**版本**: 1.0.0

**Date**: 2026-01-24
**日期**: 2026-01-24

---

## Overview
## 概述

This guide helps developers navigate the reorganized specification structure in the CardMind project. The main specs have been reorganized into four clear layers: Domain, Features, UI, and Architecture.

本指南帮助开发者了解 CardMind 项目中重组后的规格结构。主规格已重组为四个清晰的层次：领域、功能、UI 和架构。

---

## What Changed
## 变更内容

### New Directory Structure
### 新目录结构

```
openspec/specs/
├── domain/           # Business rules and domain models
│   ├── card/        # Card entity and business rules
│   ├── pool/        # Pool ownership model
│   ├── sync/        # Sync domain model
│   └── types.md     # Shared domain types
├── features/        # User-facing features
│   ├── card_management/
│   ├── pool_management/
│   ├── p2p_sync/
│   ├── search_and_filter/
│   └── settings/
├── ui/              # UI components and screens
│   ├── screens/     # Screen specifications
│   │   ├── mobile/
│   │   ├── desktop/
│   │   └── shared/
│   ├── components/  # Component specifications
│   │   ├── mobile/
│   │   ├── desktop/
│   │   └── shared/
│   └── adaptive/    # Adaptive layout system
└── architecture/    # Technical implementation
    ├── storage/     # Storage layer (Loro, SQLite)
    ├── sync/        # Sync service architecture
    ├── security/    # Security implementations
    └── bridge/      # Flutter-Rust bridge
```

---

## Layer Responsibilities
## 层次职责

### Domain Layer (domain/)
### 领域层 (domain/)

**Purpose**: Business rules and domain models using business language.
**目的**：使用业务语言的业务规则和领域模型。

**What belongs here**:
**应包含的内容**：
- Entity definitions (Card, Pool, Device)
- 实体定义（Card、Pool、Device）
- Business rules and constraints
- 业务规则和约束
- Domain relationships
- 领域关系
- Validation rules
- 验证规则

**What does NOT belong here**:
**不应包含的内容**：
- Technical implementation details
- 技术实现细节
- Storage mechanisms
- 存储机制
- API endpoints
- API 端点
- UI components
- UI 组件

**Example**: `domain/pool/model.md` defines the single pool ownership rule without mentioning SQLite or Loro.
**示例**：`domain/pool/model.md` 定义单池所有权规则，不提及 SQLite 或 Loro。

---

### Features Layer (features/)
### 功能层 (features/)

**Purpose**: User-facing features from the user's perspective.
**目的**：从用户视角描述面向用户的功能。

**What belongs here**:
**应包含的内容**：
- User workflows and journeys
- 用户工作流和旅程
- Feature requirements
- 功能需求
- User scenarios (GIVEN-WHEN-THEN)
- 用户场景（GIVEN-WHEN-THEN）
- Feature acceptance criteria
- 功能验收标准

**What does NOT belong here**:
**不应包含的内容**：
- UI layout details
- UI 布局细节
- Technical architecture
- 技术架构
- Implementation code
- 实现代码

**Example**: `features/card_management/spec.md` describes card creation, editing, and deletion from the user's perspective.
**示例**：`features/card_management/spec.md` 从用户视角描述卡片创建、编辑和删除。

---

### UI Layer (ui/)
### UI 层 (ui/)

**Purpose**: UI components, screens, and platform-specific layouts.
**目的**：UI 组件、屏幕和平台特定布局。

**What belongs here**:
**应包含的内容**：
- Screen layouts and navigation
- 屏幕布局和导航
- Component specifications
- 组件规格
- Platform-specific UI patterns
- 平台特定的 UI 模式
- Adaptive layout rules
- 自适应布局规则

**Platform separation**:
**平台分离**：
- `mobile/` - Mobile-specific UI (bottom navigation, gestures)
- `mobile/` - 移动端特定 UI（底部导航、手势）
- `desktop/` - Desktop-specific UI (toolbar, context menus)
- `desktop/` - 桌面端特定 UI（工具栏、右键菜单）
- `shared/` - Platform-agnostic components
- `shared/` - 平台无关组件

**Example**: `ui/screens/mobile/home_screen.md` specifies the mobile home screen layout with bottom navigation.
**示例**：`ui/screens/mobile/home_screen.md` 指定带底部导航的移动端主屏幕布局。

---

### Architecture Layer (architecture/)
### 架构层 (architecture/)

**Purpose**: Technical implementation details and system architecture.
**目的**：技术实现细节和系统架构。

**What belongs here**:
**应包含的内容**：
- Storage implementation (Loro, SQLite)
- 存储实现（Loro、SQLite）
- Sync service architecture
- 同步服务架构
- Security implementations
- 安全实现
- Bridge specifications
- 桥接规格
- Technical patterns and algorithms
- 技术模式和算法

**Important**: Use pseudocode, not detailed implementation code. See `engineering/spec_writing_guide.md` section 5.
**重要**：使用伪代码，而非详细实现代码。参见 `engineering/spec_writing_guide.md` 第 5 节。

**Example**: `architecture/storage/card_store.md` describes CardStore implementation using Loro and SQLite with pseudocode.
**示例**：`architecture/storage/card_store.md` 使用伪代码描述 CardStore 的 Loro 和 SQLite 实现。

---

## Finding Migrated Documents
## 查找已迁移文档

### Quick Reference Table
### 快速参考表

| Old Location | New Location | Type |
|--------------|--------------|------|
| `domain/pool_model.md` | `domain/pool/model.md` | Moved |
| `domain/common_types.md` | `domain/types.md` | Moved |
| `domain/card_store.md` | `architecture/storage/card_store.md` + `domain/card/rules.md` | Split |
| `domain/sync_protocol.md` | `architecture/sync/service.md` | Moved |
| `domain/device_config.md` | `architecture/storage/device_config.md` | Moved |

**Full mapping**: See `migration_map.md` for complete list.
**完整映射**：参见 `migration_map.md` 获取完整列表。

---

## Redirect Documents
## 重定向文档

Old document locations have been converted to redirect documents that point to new locations:
旧文档位置已转换为重定向文档，指向新位置：

**Example redirect**:
**重定向示例**：

```markdown
# DeviceConfig Specification - MOVED
# DeviceConfig 规格 - 已迁移

This document has been moved to the architecture layer:
本文档已迁移到架构层：

**New Location**:
**新位置**:
- [../architecture/storage/device_config.md](../architecture/storage/device_config.md)
```

**How to use redirects**:
**如何使用重定向**：
1. Open the old document location
1. 打开旧文档位置
2. Follow the link to the new location
2. 跟随链接到新位置
3. Update your bookmarks/references
3. 更新你的书签/引用

---

## Updating References
## 更新引用

### In Code Comments
### 在代码注释中

**Before**:
**之前**：
```rust
// See specs/domain/pool_model.md for business rules
```

**After**:
**之后**：
```rust
// See specs/domain/pool/model.md for business rules
```

### In Test Files
### 在测试文件中

**Before**:
**之前**：
```rust
/// Spec: specs/domain/card_store.md
```

**After**:
**之后**：
```rust
/// Spec: specs/architecture/storage/card_store.md
/// Business rules: specs/domain/card/rules.md
```

### In ADR Documents
### 在 ADR 文档中

All ADR documents in `docs/adr/` have been updated with new spec references. No action needed.
`docs/adr/` 中的所有 ADR 文档已更新为新的规格引用。无需操作。

---

## Best Practices
## 最佳实践

### When Creating New Specs
### 创建新规格时

1. **Choose the right layer**:
1. **选择正确的层次**：
   - Business rules → `domain/`
   - 业务规则 → `domain/`
   - User features → `features/`
   - 用户功能 → `features/`
   - UI components → `ui/`
   - UI 组件 → `ui/`
   - Technical implementation → `architecture/`
   - 技术实现 → `architecture/`

2. **Use templates**:
2. **使用模板**：
   - Templates available in `openspec/changes/reorganize-main-specs-content/templates/`
   - 模板位于 `openspec/changes/reorganize-main-specs-content/templates/`

3. **Follow format guide**:
3. **遵循格式指南**：
   - See `openspec/engineering/spec_writing_guide.md`
   - 参见 `openspec/engineering/spec_writing_guide.md`
   - Use two-line bilingual format
   - 使用两行双语格式
   - Use pseudocode in architecture specs
   - 在架构规格中使用伪代码

---

## Common Questions
## 常见问题

### Q: Where do I find card-related specs now?
### 问：现在在哪里找到卡片相关规格？

**A**: Card specs are split across layers:
**答**：卡片规格分布在各层：
- Business rules: `domain/card/rules.md`
- 业务规则：`domain/card/rules.md`
- User features: `features/card_management/spec.md`
- 用户功能：`features/card_management/spec.md`
- Storage implementation: `architecture/storage/card_store.md`
- 存储实现：`architecture/storage/card_store.md`
- UI components: `ui/components/shared/note_card.md`
- UI 组件：`ui/components/shared/note_card.md`

---

### Q: Why were documents split across layers?
### 问：为什么文档要跨层拆分？

**A**: To separate concerns and improve maintainability:
**答**：为了分离关注点并提高可维护性：
- Business rules change independently from implementation
- 业务规则独立于实现变更
- UI can evolve without affecting domain logic
- UI 可以演进而不影响领域逻辑
- Technical architecture can be refactored without changing requirements
- 技术架构可以重构而不改变需求

---

### Q: What happened to bilingual-compliance/spec.md?
### 问：bilingual-compliance/spec.md 发生了什么？

**A**: It was moved to `openspec/engineering/bilingual_compliance_spec.md` because it's an engineering guide, not a business spec.
**答**：它被移动到 `openspec/engineering/bilingual_compliance_spec.md`，因为它是工程指南，而非业务规格。

**Background**: This document was incorrectly synced to main specs during the `bilingual-spec-compliance` change archive. See `migration_map.md` for details.
**背景**：该文档在 `bilingual-spec-compliance` 变更归档时错误地同步到主规格。详见 `migration_map.md`。

---

### Q: Should I update old feature/ documents?
### 问：我应该更新旧的 feature/ 文档吗？

**A**: Old feature documents have been kept as redirects. Use the new structure:
**答**：旧的 feature 文档已保留为重定向。使用新结构：
- For user features: `features/<feature-name>/spec.md`
- 用户功能：`features/<feature-name>/spec.md`
- For UI screens: `ui/screens/<platform>/<screen-name>.md`
- UI 屏幕：`ui/screens/<platform>/<screen-name>.md`
- For UI components: `ui/components/<platform>/<component-name>.md`
- UI 组件：`ui/components/<platform>/<component-name>.md`

---

## Migration Timeline
## 迁移时间线

- **2026-01-23**: Migration started
- **2026-01-23**：迁移开始
- **2026-01-24**: Migration completed
- **2026-01-24**：迁移完成
- **Next**: Team review and feedback
- **下一步**：团队审查和反馈

---

## Getting Help
## 获取帮助

**Questions or issues?**
**有问题或疑问？**

1. Check `migration_map.md` for document mappings
1. 查看 `migration_map.md` 了解文档映射
2. Review `openspec/engineering/spec_writing_guide.md` for format guidelines
2. 查看 `openspec/engineering/spec_writing_guide.md` 了解格式指南
3. Look at existing specs in each layer as examples
3. 查看各层现有规格作为示例
4. Contact the CardMind team
4. 联系 CardMind 团队

---

## Related Documents
## 相关文档

**Migration artifacts**:
**迁移产物**：
- [migration_map.md](migration_map.md) - Complete file mapping table
- [migration_map.md](migration_map.md) - 完整文件映射表
- [design.md](design.md) - Reorganization design document
- [design.md](design.md) - 重组设计文档
- [tasks.md](tasks.md) - Implementation task list
- [tasks.md](tasks.md) - 实施任务列表

**Engineering guides**:
**工程指南**：
- [../../engineering/spec_writing_guide.md](../../engineering/spec_writing_guide.md) - Spec writing guide
- [../../engineering/spec_writing_guide.md](../../engineering/spec_writing_guide.md) - 规格编写指南

**Layer READMEs**:
**层次 README**：
- [../../specs/domain/README.md](../../specs/domain/README.md) - Domain layer guide
- [../../specs/domain/README.md](../../specs/domain/README.md) - 领域层指南
- [../../specs/features/README.md](../../specs/features/README.md) - Features layer guide
- [../../specs/features/README.md](../../specs/features/README.md) - 功能层指南
- [../../specs/ui/README.md](../../specs/ui/README.md) - UI layer guide
- [../../specs/ui/README.md](../../specs/ui/README.md) - UI 层指南
- [../../specs/architecture/README.md](../../specs/architecture/README.md) - Architecture layer guide
- [../../specs/architecture/README.md](../../specs/architecture/README.md) - 架构层指南

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Maintainers**: CardMind Team
**维护者**: CardMind Team
