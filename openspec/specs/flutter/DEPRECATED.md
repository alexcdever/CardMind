# ⚠️ DEPRECATED

**迁移日期**: 2026-01-20
**新位置**: 已迁移到领域驱动结构

---

## 此目录已弃用

本目录（`openspec/specs/flutter/`）中的规格文档已迁移到新的领域驱动组织结构。

### 迁移映射

#### Mobile 规格
| 旧文件 | 新位置 | 功能 |
|--------|--------|------|
| `mobile/SP-FLT-MOB-001-card-list.md` | `../features/card_list/ui_mobile.md` | Card List |
| `mobile/SP-FLT-MOB-002-card-editor.md` | `../features/card_editor/ui_mobile.md` | Card Editor |
| `mobile/SP-FLT-MOB-003-gestures.md` | `../features/gestures/ui_mobile.md` | Gestures |
| `mobile/SP-FLT-MOB-004-navigation.md` | `../features/navigation/ui_mobile.md` | Navigation |
| `mobile/SP-FLT-MOB-005-search.md` | `../features/search/ui_mobile.md` | Search |
| `mobile/SP-FLT-MOB-006-fab.md` | `../features/fab/ui_mobile.md` | FAB |

#### Desktop 规格
| 旧文件 | 新位置 | 功能 |
|--------|--------|------|
| `desktop/SP-FLT-DSK-001-card-grid.md` | `../features/card_list/ui_desktop.md` | Card List |
| `desktop/SP-FLT-DSK-002-inline-editor.md` | `../features/card_editor/ui_desktop.md` | Card Editor |
| `desktop/SP-FLT-DSK-003-toolbar.md` | `../features/toolbar/ui_desktop.md` | Toolbar |
| `desktop/SP-FLT-DSK-004-context-menu.md` | `../features/context_menu/ui_desktop.md` | Context Menu |
| `desktop/SP-FLT-DSK-005-search.md` | `../features/search/ui_desktop.md` | Search |
| `desktop/SP-FLT-DSK-006-layout.md` | `../ui_system/responsive_layout.md` | UI System |

#### Shared 规格
| 旧文件 | 新位置 | 功能 |
|--------|--------|------|
| `shared/onboarding.md` | `../features/onboarding/ui_shared.md` | Onboarding |
| `shared/home-screen.md` | `../features/home_screen/ui_shared.md` | Home Screen |
| `shared/sync-feedback.md` | `../features/sync_feedback/ui_shared.md` | Sync Feedback |

### 为什么迁移？

**旧结构问题**:
- 按技术栈组织（rust / flutter）
- 技术栈前缀冗长（SP-FLT-MOB-001）
- 功能分散在 mobile / desktop / shared

**新结构优势**:
- 按功能能力组织（features/）
- 简洁的文件名（ui_mobile.md, ui_desktop.md）
- 相关规格集中在一个功能目录下

### 使用新结构

```bash
# 查看某个功能的所有平台规格
ls ../features/card_editor/
# ui_mobile.md  ui_desktop.md

# 查看移动端专属功能
cat ../features/navigation/ui_mobile.md
cat ../features/gestures/ui_mobile.md

# 查看桌面端专属功能
cat ../features/toolbar/ui_desktop.md
cat ../features/context_menu/ui_desktop.md

# 查看跨平台共享功能
cat ../features/onboarding/ui_shared.md
cat ../features/home_screen/ui_shared.md
```

### 新的命名约定

- 功能目录: `lowercase_with_underscores/`（如 `card_editor/`, `sync_feedback/`）
- 后端逻辑: `logic.md`
- 移动端 UI: `ui_mobile.md`
- 桌面端 UI: `ui_desktop.md`
- 共享 UI: `ui_shared.md`

### 详细说明

查看完整的目录结构约定：
```bash
cat ../engineering/directory_conventions.md
```

查看规格索引：
```bash
cat ../README.md
```

---

**注意**: 此目录将在 2026 年 Q2 移除。请更新所有引用。
