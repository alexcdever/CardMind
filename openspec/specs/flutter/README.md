# Flutter 规格文档索引

> Flutter 前端规格集中管理，包含 UI 交互、自适应 UI 和测试规格

---

## 📋 规格分类

> **Spec Coding 原则**：测试代码本身即为可执行规格，无需额外的"测试规格文档"

### UI 交互规格

用户界面交互流程和行为规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLUT-003 | [overview.md](./ui-interaction/overview.md) | UI 交互规格总览 | ✅ 完成 |
| SP-FLUT-007 | [onboarding.md](./ui-interaction/onboarding.md) | 初始化流程规格 | ✅ 完成 |
| SP-FLUT-008 | [home-screen.md](./ui-interaction/home-screen.md) | 主页交互规格 | ✅ 完成 |
| SP-FLUT-011 | [mobile.md](./ui-interaction/mobile.md) | 移动端 UI 交互规格 | ✅ 完成 |
| SP-FLUT-012 | [desktop.md](./ui-interaction/desktop.md) | 桌面端 UI 交互规格 | ✅ 完成 |
| ~~SP-FLUT-009~~ | ~~[card-creation.md](./ui-interaction/card-creation.md)~~ | ~~卡片创建交互规格~~ | ⚠️ 已废弃 → SP-FLUT-011/012 |
| SP-FLUT-010 | [sync-feedback.md](./ui-interaction/sync-feedback.md) | 同步反馈交互规格 | ✅ 完成 |

### 自适应 UI 规格

平台自适应和响应式 UI 规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-ADAPT-001 | [platform-detection.md](./adaptive-ui/platform-detection.md) | 平台检测规格 | ✅ 完成 |
| SP-ADAPT-002 | [framework.md](./adaptive-ui/framework.md) | 自适应 UI 框架规格 | ✅ 完成 |
| SP-ADAPT-003 | [keyboard-shortcuts.md](./adaptive-ui/keyboard-shortcuts.md) | 键盘快捷键规格 | ✅ 完成 |
| SP-ADAPT-004 | [mobile-patterns.md](./adaptive-ui/mobile-patterns.md) | 移动端 UI 模式规格 | ✅ 完成 |
| SP-ADAPT-005 | [desktop-patterns.md](./adaptive-ui/desktop-patterns.md) | 桌面端 UI 模式规格 | ✅ 完成 |



---

## 🚀 快速开始

### 查看规格文档

```bash
# UI 交互规格
cat openspec/specs/flutter/ui-interaction/overview.md

# 自适应 UI 规格
cat openspec/specs/flutter/adaptive-ui/framework.md

# 测试规格
cat openspec/specs/flutter/testing/ui-component.md
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

### UI 交互规格
```
SP-FLUT-XXX
  │    │
  │    └─ 序号（001, 002, 003...）
  └────── Flutter UI 模块
```

### 自适应 UI 规格
```
SP-ADAPT-XXX
  │     │
  │     └─ 序号（001, 002, 003...）
  └─────── Adaptive UI 模块
```

### 测试规格
```
SP-TEST-XXX
  │    │
  │    └─ 序号（001, 002, 003...）
  └────── Testing 模块
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
- UI 交互规格: 7 个（1 个已废弃）
- 自适应 UI 规格: 5 个
- 对应测试文件: 18 个（`test/specs/*_spec_test.dart`）

**目标**:
- 规格覆盖率: 100%
- 测试通过率: 100%
- 文档更新率: 实时同步

---

**最后更新**: 2026-01-19  
**维护者**: CardMind Team
