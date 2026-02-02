# Proposal: Split UI Interaction Specs by Platform

## Problem Statement

当前的 UI 交互规格（SP-FLUT-009 卡片创建交互规格）混合了移动端和桌面端的交互模式，导致：

1. **规格不清晰**：同一个规格文档中混合了两种完全不同的交互模式
2. **实现不完整**：桌面端创建卡片后没有自动进入编辑状态，用户体验不佳
3. **测试覆盖不足**：缺少针对桌面端特定交互的测试场景
4. **维护困难**：修改一个平台的规格时，容易影响另一个平台

### 当前问题示例

**SP-FLUT-009 当前结构**：
```markdown
### Requirement: User can initiate card creation from home screen
- Scenario: FAB button is visible on home screen  ← 移动端
- Scenario: Tapping FAB navigates to card editor  ← 移动端

### Requirement: User can input card title and content
- Scenario: Title input field is available  ← 通用
- Scenario: Content input field is available  ← 通用
```

**问题**：
- FAB 按钮只在移动端显示，但规格没有明确说明
- 桌面端使用工具栏按钮，但规格中没有描述
- 桌面端创建卡片后的行为没有定义

## Proposed Solution

将 UI 交互规格按平台拆分为两个独立的规格文档：

### 新的规格结构

```
openspec/specs/flutter/
├── ui_interaction_spec.md              (保留，作为总览)
├── mobile_ui_interaction_spec.md       (新增，移动端交互)
├── desktop_ui_interaction_spec.md      (新增，桌面端交互)
├── card_creation_spec.md               (废弃，拆分到上面两个文档)
├── home_screen_spec.md                 (保留，通用主页规格)
├── onboarding_spec.md                  (保留)
└── sync_feedback_spec.md               (保留)
```

### 规格编号调整

| 旧编号 | 新编号 | 文档 | 描述 |
|--------|--------|------|------|
| SP-FLUT-009 | **SP-FLUT-011** | mobile_ui_interaction_spec.md | 移动端 UI 交互规格 |
| - | **SP-FLUT-012** | desktop_ui_interaction_spec.md | 桌面端 UI 交互规格 |
| SP-FLUT-009 | ~~废弃~~ | card_creation_spec.md | 内容拆分到 011 和 012 |

## Benefits

1. **清晰的职责分离**：每个规格文档只关注一个平台的交互模式
2. **完整的场景覆盖**：为每个平台定义完整的交互流程
3. **更好的可维护性**：修改一个平台的规格不影响另一个平台
4. **更精确的测试**：每个平台有独立的测试用例
5. **符合自适应 UI 架构**：与 SP-ADAPT-004 (移动端 UI 模式) 和 SP-ADAPT-005 (桌面端 UI 模式) 对齐

## Scope

### In Scope

1. ✅ 创建 `mobile_ui_interaction_spec.md` (SP-FLUT-011)
   - 移动端卡片创建流程（FAB → 全屏编辑器）
   - 移动端卡片编辑流程（点击卡片 → 全屏编辑器）
   - 移动端导航模式（底部导航栏）
   - 移动端手势交互（滑动、长按）

2. ✅ 创建 `desktop_ui_interaction_spec.md` (SP-FLUT-012)
   - 桌面端卡片创建流程（工具栏按钮 → 内联编辑）
   - 桌面端卡片编辑流程（右键菜单 → 内联编辑）
   - 桌面端键盘快捷键（Cmd/Ctrl+N, Cmd/Ctrl+Enter, Escape）
   - 桌面端鼠标交互（悬停、右键菜单）

3. ✅ 更新 `ui_interaction_spec.md` (SP-FLUT-003)
   - 作为总览文档，引用 SP-FLUT-011 和 SP-FLUT-012
   - 定义通用的交互原则
   - 说明平台特定规格的位置

4. ✅ 废弃 `card_creation_spec.md` (SP-FLUT-009)
   - 添加废弃说明
   - 指向新的规格文档

5. ✅ 更新 `openspec/specs/README.md`
   - 更新规格索引
   - 标记 SP-FLUT-009 为已废弃
   - 添加 SP-FLUT-011 和 SP-FLUT-012

### Out of Scope

- ❌ 修改现有代码实现（本次只重组规格）
- ❌ 添加新的测试用例（规格重组后再添加）
- ❌ 修改其他规格文档（如 home_screen_spec.md）

## Implementation Plan

### Phase 1: 创建新规格文档

1. 创建 `mobile_ui_interaction_spec.md`
   - 从 `card_creation_spec.md` 提取移动端场景
   - 添加移动端特定的交互场景
   - 定义移动端的完整用户流程

2. 创建 `desktop_ui_interaction_spec.md`
   - 从 `card_creation_spec.md` 提取桌面端场景
   - 添加桌面端特定的交互场景（**重点：自动进入编辑模式**）
   - 定义桌面端的完整用户流程

### Phase 2: 更新现有文档

3. 更新 `ui_interaction_spec.md`
   - 重写为总览文档
   - 添加对新规格的引用

4. 废弃 `card_creation_spec.md`
   - 添加废弃标记
   - 添加迁移指南

5. 更新 `openspec/specs/README.md`
   - 更新规格索引表
   - 更新状态标记

### Phase 3: 验证和清理

6. 验证所有引用
   - 检查其他文档中对 SP-FLUT-009 的引用
   - 更新为新的规格编号

7. 更新测试文件映射
   - 更新 `test-spec-mapping/spec.md`
   - 确保测试用例对应到正确的规格

## Success Criteria

- [ ] 新规格文档创建完成且内容完整
- [ ] 移动端和桌面端的交互场景完全分离
- [ ] 桌面端创建卡片的完整流程有明确定义
- [ ] 所有规格文档的交叉引用正确
- [ ] README.md 索引更新完成
- [ ] 没有遗漏的场景或需求

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 规格拆分后出现重复内容 | 中 | 在总览文档中明确定义通用规则，平台规格只描述差异 |
| 现有测试用例需要重新映射 | 低 | 更新 test-spec-mapping 文档 |
| 其他文档引用旧规格编号 | 中 | 全局搜索 SP-FLUT-009 并更新引用 |

## Timeline

- **Day 1**: 创建新规格文档（Phase 1）
- **Day 1**: 更新现有文档（Phase 2）
- **Day 1**: 验证和清理（Phase 3）

**Total**: 1 day

## Related Specs

- SP-FLUT-003: UI 交互规格（总览）
- SP-FLUT-008: 主页交互规格
- SP-FLUT-009: 卡片创建交互规格（将被废弃）
- SP-ADAPT-004: 移动端 UI 模式规格
- SP-ADAPT-005: 桌面端 UI 模式规格

## Open Questions

1. ❓ 是否需要同时更新测试文件？
   - **建议**：本次只重组规格，测试文件在下一个 change 中更新

2. ❓ 其他 UI 交互（如删除、搜索）是否也需要拆分？
   - **建议**：先完成卡片创建/编辑的拆分，其他交互在后续 change 中处理

3. ❓ 是否需要创建迁移指南文档？
   - **建议**：在废弃的 `card_creation_spec.md` 中添加简短的迁移说明即可

---

**Status**: Draft
**Author**: CardMind Team
**Date**: 2026-01-19
