# Directory Conventions
# 目录约定

## Overview | 概述

This document describes the directory structure and naming conventions for the CardMind OpenSpec documentation.

本文档描述 CardMind OpenSpec 文档的目录结构和命名约定。

**Migration Date**: 2026-01-20
**Structure Version**: 1.0.0 (Domain-Driven)

---

## Directory Structure | 目录结构

```
openspec/specs/
├── engineering/       # Engineering practices & architecture patterns
├── domain/            # Domain models & business logic
├── api/               # Public APIs & FFI interfaces
├── features/          # User-facing features
├── ui_system/         # Design tokens & shared UI components
└── adr/               # Architecture Decision Records
```

---

## Top-Level Directories | 顶层目录

### 📐 `engineering/`
**Purpose**: How we build software
**Contains**: Coding guides, architecture patterns, tech stack documentation

**Example files**:
- `guide.md` - Spec Coding guide
- `summary.md` - Quick reference
- `architecture_patterns.md` - Common patterns
- `tech_stack.md` - Technology constraints

---

### 🏗️ `domain/`
**Purpose**: What the system does
**Contains**: Domain models, core types, business logic specifications

**Example files**:
- `common_types.md` - Shared types (UUID, timestamps)
- `pool_model.md` - Single pool architecture
- `card_store.md` - Card storage logic
- `sync_protocol.md` - Sync algorithm
- `device_config.md` - Device configuration

**Naming**: `snake_case.md`

---

### 🔌 `api/`
**Purpose**: How components communicate
**Contains**: Public APIs, FFI interfaces, external contracts

**Example files**:
- `api_spec.md` - Main Rust API specification

**Naming**: `snake_case.md`

---

### ✨ `features/`
**Purpose**: What users can do
**Contains**: User-facing features organized by capability

**Structure**:
```
features/
├── card_editor/
│   ├── logic.md          # Rust/backend logic (optional)
│   ├── ui_mobile.md      # Flutter mobile UI
│   ├── ui_desktop.md     # Flutter desktop UI
│   └── ui_shared.md      # Shared UI logic (optional)
├── card_list/
│   └── ...
└── ...
```

**Naming Conventions**:
- Feature directories: `lowercase_with_underscores`
- Logic files: `logic.md` (Rust/backend)
- UI files: `ui_mobile.md`, `ui_desktop.md`, `ui_shared.md`

**Example features**:
- `card_editor/` - Card editing interface
- `card_list/` - Card list/grid views
- `search/` - Search functionality
- `onboarding/` - First-time user experience
- `sync_feedback/` - Sync status UI

**Rules**:
- ✅ Organize by user capability, not by tech stack
- ✅ Use descriptive names (card_editor, not editor)
- ✅ Split by platform when UI differs (ui_mobile.md vs ui_desktop.md)
- ✅ Use ui_shared.md when UI is identical across platforms
- ❌ Don't prefix with tech stack (SP-FLT-MOB-001)

---

### 🎨 `ui_system/`
**Purpose**: Consistent UI foundations
**Contains**: Design tokens, layout system, shared widgets

**Example files**:
- `design_tokens.md` - Colors, typography, spacing
- `responsive_layout.md` - Responsive layout system
- `shared_widgets.md` - Reusable UI components

**Naming**: `snake_case.md`

---

### 📝 `adr/`
**Purpose**: Why we made key decisions
**Contains**: Architecture Decision Records

**Naming**: `NNNN-kebab-case.md` (e.g., `0001-dual-layer-architecture.md`)

**Status**: Not deprecated (still active)

---

## File Naming Conventions | 文件命名约定

### General Rules | 通用规则
- **Format**: `snake_case.md`
- **Language**: English
- **Encoding**: UTF-8
- **Line endings**: Unix (LF), not Windows (CRLF)

### Feature Files | 功能文件
- Backend logic: `logic.md`
- Mobile UI: `ui_mobile.md`
- Desktop UI: `ui_desktop.md`
- Shared UI: `ui_shared.md`

### Spec Files | 规格文件
- Domain specs: Descriptive names (e.g., `card_store.md`, `sync_protocol.md`)
- No tech stack prefixes in file names

---

## Migration from Old Structure | 从旧结构迁移

### Old Structure (Deprecated) | 旧结构（已废弃）
```
openspec/specs/
├── rust/           # ❌ Deprecated → Migrated to domain/ and api/
└── flutter/        # ❌ Deprecated → Migrated to features/ and ui_system/
```

### Migration Mapping | 迁移映射

| Old Path | New Path |
|----------|----------|
| `rust/api_spec.md` | `api/api_spec.md` |
| `rust/card_store_spec.md` | `domain/card_store.md` |
| `rust/sync_spec.md` | `domain/sync_protocol.md` |
| `flutter/mobile/SP-FLT-MOB-002-card-editor.md` | `features/card_editor/ui_mobile.md` |
| `flutter/desktop/SP-FLT-DSK-001-card-grid.md` | `features/card_list/ui_desktop.md` |
| `adr/0004-ui-design.md` | `ui_system/design_tokens.md` |

---

## Validation | 验证

### Directory Structure | 目录结构
```bash
# Verify all top-level directories exist
ls -d openspec/specs/{engineering,domain,api,features,ui_system,adr}

# Count feature directories (should be 11)
ls -d openspec/specs/features/*/ | wc -l
```

### File Migration | 文件迁移
```bash
# Count files in new structure
find openspec/specs/{engineering,domain,api,features,ui_system} -name "*.md" | wc -l

# Verify no tech stack prefixes in features/
grep -r "SP-FLT-" openspec/specs/features/
```

---

## Best Practices | 最佳实践

### ✅ Do
- Organize by user capability (features/)
- Use descriptive, domain-focused names
- Split by platform only when UI differs
- Keep backend logic separate (logic.md)
- Document architectural decisions (adr/)

### ❌ Don't
- Organize by tech stack (no rust/, flutter/ at top level)
- Use tech stack prefixes (SP-FLT-MOB-001)
- Mix platform-specific and shared UI in one file
- Create feature directories for internal utilities

---

## References | 参考

- Configuration: `openspec/.openspec/config.json`
- Spec Coding Guide: `openspec/specs/engineering/guide.md`
- ADR Index: `openspec/specs/adr/README.md`
