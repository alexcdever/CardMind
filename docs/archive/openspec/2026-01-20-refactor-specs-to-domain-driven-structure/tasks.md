# Tasks: Refactor OpenSpec Structure to Domain-Driven Organization

## Phase 1: Preparation (Create New Structure)

- [x] Create new top-level directories
  - [x] `openspec/specs/engineering/`
  - [x] `openspec/specs/domain/`
  - [x] `openspec/specs/api/`
  - [x] `openspec/specs/features/`
  - [x] `openspec/specs/ui_system/`

- [x] Create feature subdirectories
  - [x] `features/card_editor/`
  - [x] `features/card_list/`
  - [x] `features/search/`
  - [x] `features/onboarding/`
  - [x] `features/home_screen/`
  - [x] `features/sync_feedback/`
  - [x] `features/navigation/`
  - [x] `features/gestures/`
  - [x] `features/fab/`
  - [x] `features/toolbar/`
  - [x] `features/context_menu/`

- [x] Create configuration files
  - [x] `.openspec/config.json`
  - [x] `engineering/directory_conventions.md`

## Phase 2: Migrate Files

### Engineering Specs
- [x] Copy `SPEC_CODING_GUIDE.md` → `engineering/guide.md`
- [x] Copy `SPEC_CODING_SUMMARY.md` → `engineering/summary.md`
- [x] Copy `rust/architecture_patterns_spec.md` → `engineering/architecture_patterns.md`
- [x] Copy `adr/0003-tech-constraints.md` → `engineering/tech_stack.md`

### Domain Specs
- [x] Copy `rust/common_types_spec.md` → `domain/common_types.md`
- [x] Copy `rust/single_pool_model_spec.md` → `domain/pool_model.md`
- [x] Copy `rust/device_config_spec.md` → `domain/device_config.md`
- [x] Copy `rust/card_store_spec.md` → `domain/card_store.md`
- [x] Copy `rust/sync_spec.md` → `domain/sync_protocol.md`

### API Specs
- [x] Copy `rust/api_spec.md` → `api/api_spec.md`

### Feature Specs - Card Editor
- [x] Copy `flutter/mobile/SP-FLT-MOB-002-card-editor.md` → `features/card_editor/ui_mobile.md`
- [x] Copy `flutter/desktop/SP-FLT-DSK-002-inline-editor.md` → `features/card_editor/ui_desktop.md`

### Feature Specs - Card List
- [x] Copy `flutter/mobile/SP-FLT-MOB-001-card-list.md` → `features/card_list/ui_mobile.md`
- [x] Copy `flutter/desktop/SP-FLT-DSK-001-card-grid.md` → `features/card_list/ui_desktop.md`

### Feature Specs - Search
- [x] Copy `flutter/mobile/SP-FLT-MOB-005-search.md` → `features/search/ui_mobile.md`
- [x] Copy `flutter/desktop/SP-FLT-DSK-005-search.md` → `features/search/ui_desktop.md`

### Feature Specs - Onboarding
- [x] Copy `flutter/shared/onboarding.md` → `features/onboarding/ui_shared.md`

### Feature Specs - Home Screen
- [x] Copy `flutter/shared/home-screen.md` → `features/home_screen/ui_shared.md`

### Feature Specs - Sync Feedback
- [x] Copy `rust/sync_status_stream_spec.md` → `features/sync_feedback/logic.md`
- [x] Copy `flutter/shared/sync-feedback.md` → `features/sync_feedback/ui_shared.md`

### Feature Specs - Mobile Only
- [x] Copy `flutter/mobile/SP-FLT-MOB-004-navigation.md` → `features/navigation/ui_mobile.md`
- [x] Copy `flutter/mobile/SP-FLT-MOB-003-gestures.md` → `features/gestures/ui_mobile.md`
- [x] Copy `flutter/mobile/SP-FLT-MOB-006-fab.md` → `features/fab/ui_mobile.md`

### Feature Specs - Desktop Only
- [x] Copy `flutter/desktop/SP-FLT-DSK-003-toolbar.md` → `features/toolbar/ui_desktop.md`
- [x] Copy `flutter/desktop/SP-FLT-DSK-004-context-menu.md` → `features/context_menu/ui_desktop.md`

### UI System Specs
- [x] Copy `adr/0004-ui-design.md` → `ui_system/design_tokens.md`
- [x] Copy `flutter/desktop/SP-FLT-DSK-006-layout.md` → `ui_system/responsive_layout.md`
- [x] Create `ui_system/shared_widgets.md` (placeholder)

## Phase 3: Update Documentation

- [x] Update `openspec/specs/README.md`
  - [x] Update directory structure section
  - [x] Update file count statistics
  - [x] Add migration notice
  - [x] Mark old structure as deprecated

- [x] Update `CLAUDE.md`
  - [x] Update "规范中心" section (line 40-52)
  - [x] Update quick reference paths
  - [x] Add note about deprecated directories

- [x] Update `AGENTS.md`
  - [x] Update "关键文件" section
  - [x] Update "规格文档" paths
  - [x] Add migration timeline

- [x] Update `openspec/specs/flutter/README.md`
  - [x] Add deprecation notice at top
  - [x] Point to new structure

## Phase 4: Add Deprecation Notices

- [x] Create `openspec/specs/rust/DEPRECATED.md`
- [x] Create `openspec/specs/flutter/DEPRECATED.md`

## Phase 5: Validation

- [x] Verify directory structure
  - [x] All 5 top-level directories exist
  - [x] All 11 feature directories exist

- [x] Verify file migration
  - [x] Count files in new structure (should be 38)
  - [x] Verify no tech stack prefixes in features/

- [x] Test OpenSpec CLI
  - [x] Create test change
  - [x] Verify status command works

- [x] Validate documentation
  - [x] Check for broken links
  - [x] Verify all paths updated

## Phase 6: Cleanup (Optional)

- [x] Review old structure after 3-6 months
- [x] Optionally remove old directories
- [x] Update git history documentation
