> ⚠️ **DEPRECATED**: This specification has been split into platform-specific documents.
> 
> **Please use instead**:
> - **Mobile**: SP-FLUT-011 [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)
> - **Desktop**: SP-FLUT-012 [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)
> 
> This document is kept for historical reference only.
> 
> **Deprecated on**: 2026-01-19
> **Reason**: Spec reorganization to separate mobile and desktop interaction patterns

---

# Card Creation Interaction Specification (DEPRECATED)

## 📋 规格编号: SP-FLUT-009
**版本**: 1.0.0
**状态**: ⚠️ 已废弃
**依赖**: SP-FLUT-008 (主页交互规格), SP-CARD-004 (CardStore 规格)

---

## Migration Guide

### For Mobile Implementation

**Old**: Reference SP-FLUT-009 for mobile card creation
**New**: Reference **SP-FLUT-011** [mobile_ui_interaction_spec.md](./mobile_ui_interaction_spec.md)

Key sections:
- Section 2: 卡片创建流程
- Section 3: 卡片编辑流程
- Section 4: 底部导航
- Section 5: 手势交互

### For Desktop Implementation

**Old**: Reference SP-FLUT-009 for desktop card creation
**New**: Reference **SP-FLUT-012** [desktop_ui_interaction_spec.md](./desktop_ui_interaction_spec.md)

Key sections:
- Section 2: 卡片创建流程（包含自动进入编辑模式）
- Section 3: 卡片编辑流程
- Section 4: 布局和导航
- Section 6: 键盘快捷键

### What Changed

| Aspect | Old (SP-FLUT-009) | New (SP-FLUT-011/012) |
|--------|-------------------|----------------------|
| **Organization** | Mixed mobile and desktop | Separated by platform |
| **Desktop Creation** | Incomplete (no auto-edit) | Complete (auto-edit specified) |
| **Clarity** | Unclear which scenarios apply | Clear platform markers |
| **Test Coverage** | Mixed test cases | Platform-specific tests |

### Code Impact

If your code references SP-FLUT-009:

```dart
// Before (unclear)
void createCard() {
  // Which behavior should I implement?
  // Mobile or desktop?
}

// After (clear)
void createCard() {
  if (PlatformDetector.isMobile) {
    // Follow SP-FLUT-011, Section 2
    openFullscreenEditor();
  } else {
    // Follow SP-FLUT-012, Section 2
    createAndEditInline();
  }
}
```

---

## Original Content (For Reference)

The original content of this specification has been preserved below for historical reference. 

**⚠️ DO NOT USE FOR NEW IMPLEMENTATION**

Use SP-FLUT-011 (mobile) or SP-FLUT-012 (desktop) instead.

---

[Original content follows...]

