# Flutter 规格文档索引

> Flutter 前端规格集中管理，按平台分类（shared / mobile / desktop）

---

## 📋 规格分类

> **Spec Coding 原则**：测试代码本身即为可执行规格，无需额外的"测试规格文档"

### Shared 规格（跨平台通用）

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLT-SHR-001 | [onboarding.md](./shared/onboarding.md) | 初始化流程规格 | ✅ 完成 |
| SP-FLT-SHR-002 | [home-screen.md](./shared/home-screen.md) | 主页交互规格 | ✅ 完成 |
| SP-FLT-SHR-003 | [sync-feedback.md](./shared/sync-feedback.md) | 同步反馈交互规格 | ✅ 完成 |

### Mobile 规格（移动端专用）

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLT-MOB-001 | [SP-FLT-MOB-001-card-list.md](./mobile/SP-FLT-MOB-001-card-list.md) | 移动端卡片列表规格 | ✅ 完成 |
| SP-FLT-MOB-002 | [SP-FLT-MOB-002-card-editor.md](./mobile/SP-FLT-MOB-002-card-editor.md) | 移动端卡片编辑器规格 | ✅ 完成 |
| SP-FLT-MOB-003 | [SP-FLT-MOB-003-gestures.md](./mobile/SP-FLT-MOB-003-gestures.md) | 移动端手势交互规格 | ✅ 完成 |
| SP-FLT-MOB-004 | [SP-FLT-MOB-004-navigation.md](./mobile/SP-FLT-MOB-004-navigation.md) | 移动端导航规格 | ✅ 完成 |
| SP-FLT-MOB-005 | [SP-FLT-MOB-005-search.md](./mobile/SP-FLT-MOB-005-search.md) | 移动端搜索规格 | ✅ 完成 |
| SP-FLT-MOB-006 | [SP-FLT-MOB-006-fab.md](./mobile/SP-FLT-MOB-006-fab.md) | 移动端 FAB 规格 | ✅ 完成 |

### Desktop 规格（桌面端专用）

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLT-DSK-001 | [SP-FLT-DSK-001-card-grid.md](./desktop/SP-FLT-DSK-001-card-grid.md) | 桌面端卡片网格规格 | ✅ 完成 |
| SP-FLT-DSK-002 | [SP-FLT-DSK-002-inline-editor.md](./desktop/SP-FLT-DSK-002-inline-editor.md) | 桌面端内联编辑器规格 | ✅ 完成 |
| SP-FLT-DSK-003 | [SP-FLT-DSK-003-toolbar.md](./desktop/SP-FLT-DSK-003-toolbar.md) | 桌面端工具栏规格 | ✅ 完成 |
| SP-FLT-DSK-004 | [SP-FLT-DSK-004-context-menu.md](./desktop/SP-FLT-DSK-004-context-menu.md) | 桌面端右键菜单规格 | ✅ 完成 |
| SP-FLT-DSK-005 | [SP-FLT-DSK-005-search.md](./desktop/SP-FLT-DSK-005-search.md) | 桌面端搜索规格 | ✅ 完成 |
| SP-FLT-DSK-006 | [SP-FLT-DSK-006-layout.md](./desktop/SP-FLT-DSK-006-layout.md) | 桌面端布局规格 | ✅ 完成 |



---

## 🚀 快速开始

### 查看规格文档

```bash
# Shared 规格
cat openspec/specs/flutter/shared/home-screen.md

# Mobile 规格
cat openspec/specs/flutter/mobile/SP-FLT-MOB-001-card-list.md

# Desktop 规格
cat openspec/specs/flutter/desktop/SP-FLT-DSK-001-card-grid.md
```

### 运行测试

```bash
# 运行所有 Flutter 规格测试
flutter test test/specs/

# 运行特定规格测试
flutter test test/specs/home_screen_ui_spec_test.dart
flutter test test/specs/adaptive_ui_system_spec_test.dart
```

---

## 📖 规格编号规则

### Shared 规格（跨平台通用）
```
SP-FLT-SHR-XXX
  │   │   │
  │   │   └─ 序号（001, 002, 003...）
  │   └───── Shared（跨平台）
  └───────── Flutter 模块
```

### Mobile 规格（移动端专用）
```
SP-FLT-MOB-XXX
  │   │   │
  │   │   └─ 序号（001, 002, 003...）
  │   └───── Mobile（移动端）
  └───────── Flutter 模块
```

### Desktop 规格（桌面端专用）
```
SP-FLT-DSK-XXX
  │   │   │
  │   │   └─ 序号（001, 002, 003...）
  │   └───── Desktop（桌面端）
  └───────── Flutter 模块
```

---

## 🔗 相关文档

### 规格文档
- [规格中心索引](../README.md) - 所有规格文档入口
- [Spec Coding 指南](../SPEC_CODING_GUIDE.md) - Spec Coding 方法论
- [Rust 后端规格](../rust/) - Rust 后端规格集合
- [架构决策记录](../adr/) - ADR 集合

### 开发指南
- [AGENTS.md](../../../AGENTS.md) - AI Agent 指南
- [CLAUDE.md](../../../CLAUDE.md) - Claude Code 工作指南

---

## 📊 规格统计

**当前（2026-01-19）**:
- Shared 规格: 3 个
- Mobile 规格: 6 个
- Desktop 规格: 6 个
- **总计**: 15 个规格文档
- 对应测试文件: 18 个（`test/specs/*_spec_test.dart`）

**目标**:
- 规格覆盖率: 100%
- 测试通过率: 100%
- 文档更新率: 实时同步

---

## 📝 重构说明

### 2026-01-19: 规格文档重组

**变更内容**:
- ✅ 删除 `ui-interaction/` 和 `adaptive-ui/` 目录
- ✅ 创建 `shared/`, `mobile/`, `desktop/` 三个新目录
- ✅ 按平台分类重新组织规格文档
- ✅ 统一文件命名规范（使用 `-` 分隔符）

**原因**: 原结构混合了跨平台和平台特定的规格，导致查找困难。新结构按平台清晰分类，便于维护和查找。

**迁移指南**:
- 旧的 `ui-interaction/` 规格 → 拆分到 `shared/`, `mobile/`, `desktop/`
- 旧的 `adaptive-ui/` 规格 → 合并到平台特定规格中
- 所有文件使用新的编号规则（SP-FLT-SHR/MOB/DSK-XXX）

---

**最后更新**: 2026-01-19  
**维护者**: CardMind Team
