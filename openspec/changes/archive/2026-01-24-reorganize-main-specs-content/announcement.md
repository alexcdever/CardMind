# Documentation Reorganization Announcement
# 文档重组公告

**Date**: 2026-01-24
**日期**: 2026-01-24

**To**: CardMind Development Team
**收件人**: CardMind 开发团队

**From**: CardMind Team
**发件人**: CardMind Team

**Subject**: Main Specification Documentation Reorganization Complete
**主题**: 主规格文档重组完成

---

## Summary
## 摘要

We have completed a major reorganization of the CardMind specification documentation. The main specs have been restructured into four clear layers: Domain, Features, UI, and Architecture. This change improves clarity, maintainability, and separation of concerns.

我们已完成 CardMind 规格文档的重大重组。主规格已重构为四个清晰的层次：领域、功能、UI 和架构。此变更提高了清晰度、可维护性和关注点分离。

---

## What Changed
## 变更内容

### New Four-Layer Structure
### 新的四层结构

The specifications are now organized into four distinct layers:

规格现在组织为四个不同的层次：

1. **Domain Layer** (`specs/domain/`)
1. **领域层** (`specs/domain/`)
   - Business rules and domain models
   - 业务规则和领域模型
   - Uses business language, no technical details
   - 使用业务语言，无技术细节
   - Example: Pool ownership model, Card business rules
   - 示例：池所有权模型、卡片业务规则

2. **Features Layer** (`specs/features/`)
2. **功能层** (`specs/features/`)
   - User-facing features and workflows
   - 面向用户的功能和工作流
   - Describes what users can do
   - 描述用户能做什么
   - Example: Card management, P2P sync
   - 示例：卡片管理、P2P 同步

3. **UI Layer** (`specs/ui/`)
3. **UI 层** (`specs/ui/`)
   - UI components, screens, and layouts
   - UI 组件、屏幕和布局
   - Separated by platform (mobile/desktop/shared)
   - 按平台分离（移动端/桌面端/共享）
   - Example: Home screen, Card list item
   - 示例：主屏幕、卡片列表项

4. **Architecture Layer** (`specs/architecture/`)
4. **架构层** (`specs/architecture/`)
   - Technical implementation details
   - 技术实现细节
   - Storage, sync, security, bridges
   - 存储、同步、安全、桥接
   - Uses pseudocode, not detailed implementation
   - 使用伪代码，而非详细实现

---

## Why This Matters
## 为什么这很重要

### Benefits for Developers
### 对开发者的好处

1. **Easier Navigation**: Know which layer to look in based on your question
1. **更容易导航**：根据问题知道查看哪一层

2. **Clear Separation**: Business rules, user features, UI, and technical implementation are clearly separated
2. **清晰分离**：业务规则、用户功能、UI 和技术实现清晰分离

3. **Independent Evolution**: Change one layer without affecting others
3. **独立演进**：改变一层而不影响其他层

4. **Platform Clarity**: Mobile and desktop UI patterns are clearly separated
4. **平台清晰度**：移动端和桌面端 UI 模式清晰分离

5. **Better Maintainability**: Related documents are grouped together
5. **更好的可维护性**：相关文档组织在一起

---

## What You Need to Do
## 你需要做什么

### 1. Update Your Bookmarks
### 1. 更新你的书签

Many documents have moved. Use the migration guide to find new locations:

许多文档已移动。使用迁移指南查找新位置：

- **Migration Guide**: `openspec/changes/reorganize-main-specs-content/migration_guide.md`
- **迁移指南**: `openspec/changes/reorganize-main-specs-content/migration_guide.md`

- **File Mapping**: `openspec/changes/reorganize-main-specs-content/migration_map.md`
- **文件映射**: `openspec/changes/reorganize-main-specs-content/migration_map.md`

### 2. Update Code References
### 2. 更新代码引用

If your code comments reference old spec locations, update them:

如果你的代码注释引用旧的规格位置，请更新它们：

**Before**:
**之前**：
```rust
// See specs/domain/pool_model.md
```

**After**:
**之后**：
```rust
// See specs/domain/pool/model.md
```

### 3. Use Redirect Documents
### 3. 使用重定向文档

Old document locations have been converted to redirects. If you open an old location, follow the link to the new location.

旧文档位置已转换为重定向。如果你打开旧位置，跟随链接到新位置。

### 4. Follow New Guidelines
### 4. 遵循新指南

When creating new specs, follow the layer guidelines:

创建新规格时，遵循层次指南：

- **Business rules** → `domain/`
- **业务规则** → `domain/`
- **User features** → `features/`
- **用户功能** → `features/`
- **UI components** → `ui/`
- **UI 组件** → `ui/`
- **Technical implementation** → `architecture/`
- **技术实现** → `architecture/`

**Important**: Architecture specs should use pseudocode, not detailed implementation code. See `openspec/engineering/spec_writing_guide.md` section 5.

**重要**：架构规格应使用伪代码，而非详细实现代码。参见 `openspec/engineering/spec_writing_guide.md` 第 5 节。

---

## Key Documents to Read
## 需要阅读的关键文档

### Must Read
### 必读

1. **Migration Guide**: `openspec/changes/reorganize-main-specs-content/migration_guide.md`
1. **迁移指南**: `openspec/changes/reorganize-main-specs-content/migration_guide.md`
   - Complete guide to the new structure
   - 新结构的完整指南
   - How to find migrated documents
   - 如何查找已迁移文档
   - Best practices
   - 最佳实践

2. **Structure Diagram**: `openspec/changes/reorganize-main-specs-content/structure_diagram.md`
2. **结构图**: `openspec/changes/reorganize-main-specs-content/structure_diagram.md`
   - Visual representation of new structure
   - 新结构的可视化表示
   - Layer relationships
   - 层次关系

### Recommended
### 推荐

3. **Layer READMEs**: Each layer has a README explaining its purpose
3. **层次 README**: 每层都有 README 解释其目的
   - `specs/domain/README.md`
   - `specs/features/README.md`
   - `specs/ui/README.md`
   - `specs/architecture/README.md`

4. **Spec Writing Guide**: `openspec/engineering/spec_writing_guide.md`
4. **规格编写指南**: `openspec/engineering/spec_writing_guide.md`
   - Updated with pseudocode guidelines
   - 更新了伪代码指南
   - Two-line bilingual format
   - 两行双语格式

---

## Examples
## 示例

### Finding Card-Related Specs
### 查找卡片相关规格

Card specifications are now split across layers:

卡片规格现在分布在各层：

- **Business rules**: `specs/domain/card/rules.md`
- **业务规则**: `specs/domain/card/rules.md`

- **User features**: `specs/features/card_management/spec.md`
- **用户功能**: `specs/features/card_management/spec.md`

- **Storage implementation**: `specs/architecture/storage/card_store.md`
- **存储实现**: `specs/architecture/storage/card_store.md`

- **UI components**: `specs/ui/components/shared/note_card.md`
- **UI 组件**: `specs/ui/components/shared/note_card.md`

### Platform-Specific UI
### 平台特定 UI

UI specs are now separated by platform:

UI 规格现在按平台分离：

- **Mobile home screen**: `specs/ui/screens/mobile/home_screen.md`
- **移动端主屏幕**: `specs/ui/screens/mobile/home_screen.md`

- **Desktop home screen**: `specs/ui/screens/desktop/home_screen.md`
- **桌面端主屏幕**: `specs/ui/screens/desktop/home_screen.md`

---

## Timeline
## 时间线

- **2026-01-23**: Migration started
- **2026-01-23**：迁移开始

- **2026-01-24**: Migration completed, announcement sent
- **2026-01-24**：迁移完成，公告发送

- **Next week**: Team review and feedback period
- **下周**：团队审查和反馈期

- **Ongoing**: Update code references as you work
- **持续**：工作时更新代码引用

---

## Questions and Feedback
## 问题和反馈

### Common Questions
### 常见问题

**Q: Where do I find the old documents?**
**问：在哪里找到旧文档？**

A: Old locations have redirect documents pointing to new locations. See `migration_map.md` for complete mapping.

答：旧位置有重定向文档指向新位置。参见 `migration_map.md` 获取完整映射。

**Q: Do I need to update my code immediately?**
**问：我需要立即更新代码吗？**

A: No rush. Update code references as you work on related files. Redirect documents will help you find new locations.

答：不急。在处理相关文件时更新代码引用。重定向文档将帮助你找到新位置。

**Q: What if I find a broken link?**
**问：如果我发现损坏的链接怎么办？**

A: Please report it to the team. We've verified all links, but may have missed some.

答：请向团队报告。我们已验证所有链接，但可能遗漏了一些。

### Feedback
### 反馈

We welcome your feedback on the new structure:

我们欢迎你对新结构的反馈：

- Is it easier to navigate?
- 是否更容易导航？

- Are the layer boundaries clear?
- 层次边界是否清晰？

- Any suggestions for improvement?
- 有改进建议吗？

Please share your thoughts with the team.

请与团队分享你的想法。

---

## Special Notes
## 特别说明

### Bilingual-Compliance Issue
### Bilingual-Compliance 问题

During this reorganization, we discovered and fixed an issue where an engineering guide (`bilingual-compliance/spec.md`) was incorrectly placed in the main specs directory. It has been moved to `openspec/engineering/bilingual_compliance_spec.md`.

在此重组期间，我们发现并修复了一个问题：工程指南（`bilingual-compliance/spec.md`）被错误地放置在主规格目录中。它已移动到 `openspec/engineering/bilingual_compliance_spec.md`。

**Lesson**: Engineering guides should not be in the main specs directory. See `bilingual-compliance-issue.md` for details.

**教训**：工程指南不应在主规格目录中。详见 `bilingual-compliance-issue.md`。

### Git History Preserved
### Git 历史已保留

All document migrations used `git mv` to preserve file history. You can still use `git log --follow` to see the full history of migrated files.

所有文档迁移都使用 `git mv` 来保留文件历史。你仍然可以使用 `git log --follow` 查看已迁移文件的完整历史。

---

## Resources
## 资源

**Migration artifacts**:
**迁移产物**：
- Migration guide: `openspec/changes/reorganize-main-specs-content/migration_guide.md`
- 迁移指南: `openspec/changes/reorganize-main-specs-content/migration_guide.md`

- File mapping: `openspec/changes/reorganize-main-specs-content/migration_map.md`
- 文件映射: `openspec/changes/reorganize-main-specs-content/migration_map.md`

- Structure diagram: `openspec/changes/reorganize-main-specs-content/structure_diagram.md`
- 结构图: `openspec/changes/reorganize-main-specs-content/structure_diagram.md`

- Issue report: `openspec/changes/reorganize-main-specs-content/bilingual-compliance-issue.md`
- 问题报告: `openspec/changes/reorganize-main-specs-content/bilingual-compliance-issue.md`

**Engineering guides**:
**工程指南**：
- Spec writing guide: `openspec/engineering/spec_writing_guide.md`
- 规格编写指南: `openspec/engineering/spec_writing_guide.md`

**Layer guides**:
**层次指南**：
- Domain: `openspec/specs/domain/README.md`
- 领域: `openspec/specs/domain/README.md`

- Features: `openspec/specs/features/README.md`
- 功能: `openspec/specs/features/README.md`

- UI: `openspec/specs/ui/README.md`
- Architecture: `openspec/specs/architecture/README.md`
- 架构: `openspec/specs/architecture/README.md`

---

## Thank You
## 感谢

Thank you for your patience during this reorganization. We believe this new structure will make our documentation more maintainable and easier to navigate.

感谢你在此重组期间的耐心。我们相信这个新结构将使我们的文档更易维护和导航。

If you have any questions or concerns, please reach out to the team.

如果你有任何问题或疑虑，请联系团队。

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Contact**: CardMind Team
**联系**: CardMind Team
