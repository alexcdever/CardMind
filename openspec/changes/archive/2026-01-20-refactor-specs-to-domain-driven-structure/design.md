# Design: Refactor OpenSpec Structure to Domain-Driven Organization

## Overview

This design document details the technical approach for refactoring the OpenSpec specification structure from technology-stack-based organization to domain/feature-based organization.

## Current State Analysis

### Existing Directory Structure

```
openspec/specs/
├── README.md (333 lines, comprehensive index)
├── SPEC_CODING_GUIDE.md (301 lines)
├── SPEC_CODING_SUMMARY.md
├── adr/ (5 ADRs)
│   ├── 0001-single-pool-ownership.md
│   ├── 0002-dual-layer-architecture.md
│   ├── 0003-tech-constraints.md
│   ├── 0004-ui-design.md
│   └── 0005-logging.md
├── rust/ (9 specs)
│   ├── common_types_spec.md
│   ├── architecture_patterns_spec.md
│   ├── single_pool_model_spec.md
│   ├── device_config_spec.md
│   ├── pool_model_spec.md
│   ├── card_store_spec.md
│   ├── api_spec.md
│   ├── sync_spec.md
│   └── sync_status_stream_spec.md
└── flutter/
    ├── README.md
    ├── shared/ (3 specs)
    │   ├── onboarding.md
    │   ├── home-screen.md
    │   └── sync-feedback.md
    ├── mobile/ (6 specs)
    │   ├── SP-FLT-MOB-001-card-list.md
    │   ├── SP-FLT-MOB-002-card-editor.md
    │   ├── SP-FLT-MOB-003-gestures.md
    │   ├── SP-FLT-MOB-004-navigation.md
    │   ├── SP-FLT-MOB-005-search.md
    │   └── SP-FLT-MOB-006-fab.md
    └── desktop/ (6 specs)
        ├── SP-FLT-DSK-001-card-grid.md
        ├── SP-FLT-DSK-002-inline-editor.md
        ├── SP-FLT-DSK-003-toolbar.md
        ├── SP-FLT-DSK-004-context-menu.md
        ├── SP-FLT-DSK-005-search.md
        └── SP-FLT-DSK-006-layout.md
```

### OpenSpec Configuration

- **Current**: Each change has `.openspec.yaml` with minimal config (`schema: spec-driven`)
- **No global config**: No `.openspec/config.json` exists yet
- **Changes directory**: `openspec/changes/` with archive subdirectory

## Target State Design

### New Directory Structure

```
openspec/specs/
├── README.md (updated index)
├── engineering/
│   ├── guide.md (from SPEC_CODING_GUIDE.md)
│   ├── summary.md (from SPEC_CODING_SUMMARY.md)
│   ├── tech_stack.md (from adr/0003-tech-constraints.md)
│   ├── architecture_patterns.md (from rust/architecture_patterns_spec.md)
│   └── directory_conventions.md (NEW)
├── adr/ (keep 3 ADRs)
│   ├── 0001-single-pool-ownership.md
│   ├── 0002-dual-layer-architecture.md
│   └── 0005-logging.md
├── domain/
│   ├── common_types.md (from rust/common_types_spec.md)
│   ├── pool_model.md (from rust/single_pool_model_spec.md + pool_model_spec.md)
│   ├── device_config.md (from rust/device_config_spec.md)
│   ├── card_store.md (from rust/card_store_spec.md)
│   └── sync_protocol.md (from rust/sync_spec.md)
├── api/
│   └── api_spec.md (from rust/api_spec.md)
├── features/
│   ├── card_editor/
│   │   ├── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-002-card-editor.md)
│   │   └── ui_desktop.md (from flutter/desktop/SP-FLT-DSK-002-inline-editor.md)
│   ├── card_list/
│   │   ├── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-001-card-list.md)
│   │   └── ui_desktop.md (from flutter/desktop/SP-FLT-DSK-001-card-grid.md)
│   ├── search/
│   │   ├── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-005-search.md)
│   │   └── ui_desktop.md (from flutter/desktop/SP-FLT-DSK-005-search.md)
│   ├── onboarding/
│   │   └── ui_shared.md (from flutter/shared/onboarding.md)
│   ├── home_screen/
│   │   └── ui_shared.md (from flutter/shared/home-screen.md)
│   ├── sync_feedback/
│   │   ├── logic.md (from rust/sync_status_stream_spec.md)
│   │   └── ui_shared.md (from flutter/shared/sync-feedback.md)
│   ├── navigation/
│   │   └── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-004-navigation.md)
│   ├── gestures/
│   │   └── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-003-gestures.md)
│   ├── fab/
│   │   └── ui_mobile.md (from flutter/mobile/SP-FLT-MOB-006-fab.md)
│   ├── toolbar/
│   │   └── ui_desktop.md (from flutter/desktop/SP-FLT-DSK-003-toolbar.md)
│   └── context_menu/
│       └── ui_desktop.md (from flutter/desktop/SP-FLT-DSK-004-context-menu.md)
└── ui_system/
    ├── design_tokens.md (from adr/0004-ui-design.md)
    ├── responsive_layout.md (from flutter/desktop/SP-FLT-DSK-006-layout.md)
    └── shared_widgets.md (NEW - placeholder)
```

## Detailed Migration Mapping

### Phase 1: Engineering Specs

| Source | Destination | Action |
|--------|-------------|--------|
| `SPEC_CODING_GUIDE.md` | `engineering/guide.md` | Copy |
| `SPEC_CODING_SUMMARY.md` | `engineering/summary.md` | Copy |
| `rust/architecture_patterns_spec.md` | `engineering/architecture_patterns.md` | Copy |
| `adr/0003-tech-constraints.md` | `engineering/tech_stack.md` | Copy |
| N/A | `engineering/directory_conventions.md` | Create new |

### Phase 2: Domain Specs

| Source | Destination | Action |
|--------|-------------|--------|
| `rust/common_types_spec.md` | `domain/common_types.md` | Copy |
| `rust/single_pool_model_spec.md` | `domain/pool_model.md` | Copy (merge with pool_model_spec.md if needed) |
| `rust/pool_model_spec.md` | `domain/pool_model.md` | Merge into above |
| `rust/device_config_spec.md` | `domain/device_config.md` | Copy |
| `rust/card_store_spec.md` | `domain/card_store.md` | Copy |
| `rust/sync_spec.md` | `domain/sync_protocol.md` | Copy |

### Phase 3: API Specs

| Source | Destination | Action |
|--------|-------------|--------|
| `rust/api_spec.md` | `api/api_spec.md` | Copy |

### Phase 4: Feature Specs

#### Card Editor
- `flutter/mobile/SP-FLT-MOB-002-card-editor.md` → `features/card_editor/ui_mobile.md`
- `flutter/desktop/SP-FLT-DSK-002-inline-editor.md` → `features/card_editor/ui_desktop.md`

#### Card List
- `flutter/mobile/SP-FLT-MOB-001-card-list.md` → `features/card_list/ui_mobile.md`
- `flutter/desktop/SP-FLT-DSK-001-card-grid.md` → `features/card_list/ui_desktop.md`

#### Search
- `flutter/mobile/SP-FLT-MOB-005-search.md` → `features/search/ui_mobile.md`
- `flutter/desktop/SP-FLT-DSK-005-search.md` → `features/search/ui_desktop.md`

#### Onboarding
- `flutter/shared/onboarding.md` → `features/onboarding/ui_shared.md`

#### Home Screen
- `flutter/shared/home-screen.md` → `features/home_screen/ui_shared.md`

#### Sync Feedback
- `rust/sync_status_stream_spec.md` → `features/sync_feedback/logic.md`
- `flutter/shared/sync-feedback.md` → `features/sync_feedback/ui_shared.md`

#### Mobile-only Features
- `flutter/mobile/SP-FLT-MOB-004-navigation.md` → `features/navigation/ui_mobile.md`
- `flutter/mobile/SP-FLT-MOB-003-gestures.md` → `features/gestures/ui_mobile.md`
- `flutter/mobile/SP-FLT-MOB-006-fab.md` → `features/fab/ui_mobile.md`

#### Desktop-only Features
- `flutter/desktop/SP-FLT-DSK-003-toolbar.md` → `features/toolbar/ui_desktop.md`
- `flutter/desktop/SP-FLT-DSK-004-context-menu.md` → `features/context_menu/ui_desktop.md`

### Phase 5: UI System Specs

| Source | Destination | Action |
|--------|-------------|--------|
| `adr/0004-ui-design.md` | `ui_system/design_tokens.md` | Copy |
| `flutter/desktop/SP-FLT-DSK-006-layout.md` | `ui_system/responsive_layout.md` | Copy |
| N/A | `ui_system/shared_widgets.md` | Create placeholder |

## Configuration Files

### `.openspec/config.json` (NEW)

```json
{
  "paths": {
    "specs": "openspec/specs/",
    "changes": "openspec/changes/",
    "archive": "openspec/changes/archive/"
  },
  "conventions": {
    "feature_path": "openspec/specs/features/{{feature_name}}/",
    "domain_path": "openspec/specs/domain/",
    "api_path": "openspec/specs/api/",
    "engineering_path": "openspec/specs/engineering/",
    "ui_system_path": "openspec/specs/ui_system/",
    "naming": "snake_case",
    "deprecated_paths": [
      "openspec/specs/rust/",
      "openspec/specs/flutter/"
    ]
  },
  "rules": {
    "forbid_tech_stack_prefixes": true,
    "require_semantic_naming": true,
    "enforce_feature_grouping": true
  }
}
```

### `engineering/directory_conventions.md` (NEW)

Content will specify:
- New directory structure rules
- Naming conventions (snake_case, semantic names)
- Forbidden patterns (tech stack prefixes)
- Examples of correct placement

## Documentation Updates

### Files to Update

1. **`openspec/specs/README.md`**
   - Update directory structure section
   - Update file count statistics
   - Add migration notice
   - Keep old structure links with "deprecated" markers

2. **`CLAUDE.md`**
   - Update "规范中心" section with new paths
   - Update quick reference table
   - Add note about deprecated directories

3. **`AGENTS.md`**
   - Update "关键文件" section
   - Update "规格文档" paths
   - Add migration timeline

4. **`openspec/specs/flutter/README.md`**
   - Add deprecation notice at top
   - Point to new structure

## Backward Compatibility Strategy

### Phase 1: Dual Structure (Weeks 1-2)

- Keep both old and new structures
- New files go to new structure only
- Old files remain accessible

### Phase 2: Deprecation Notices (Weeks 3-4)

- Add `DEPRECATED.md` in `rust/` and `flutter/` directories
- Update all documentation to reference new paths
- Add warnings in old spec files pointing to new locations

### Phase 3: Cleanup (Optional, Months 3-6)

- After 3-6 months, optionally remove old directories
- Ensure all references updated first

## Implementation Order

1. **Create new directories** (no risk)
2. **Copy files to new locations** (no risk, old files remain)
3. **Create new documentation** (`directory_conventions.md`, config files)
4. **Update indexes** (`README.md` files)
5. **Update related docs** (`CLAUDE.md`, `AGENTS.md`)
6. **Add deprecation notices** to old directories
7. **Test OpenSpec CLI** with new structure
8. **(Optional) Remove old files** after 3-6 months

## Testing Strategy

### Validation Steps

1. **Directory structure validation**
   ```bash
   # Verify all new directories exist
   ls -la openspec/specs/{engineering,domain,api,features,ui_system}
   ```

2. **File migration validation**
   ```bash
   # Count files in new structure
   find openspec/specs/features -name "*.md" | wc -l
   # Should match count from old structure
   ```

3. **OpenSpec CLI validation**
   ```bash
   # Test creating new change
   openspec new change "test-new-structure"
   # Test status command
   openspec status --change "test-new-structure"
   ```

4. **Documentation link validation**
   ```bash
   # Check for broken links in README.md
   grep -r "openspec/specs/rust/" openspec/specs/README.md
   # Should return no results after migration
   ```

## Rollback Plan

If issues arise:

1. **Keep old structure intact** during migration
2. **Revert documentation changes** via git
3. **Remove new directories** if needed
4. **No data loss** since we copy, not move

## Success Metrics

- [ ] All 38 spec files migrated to new structure
- [ ] New directory structure created (5 top-level dirs)
- [ ] Configuration files created and tested
- [ ] 3 documentation files updated (README.md, CLAUDE.md, AGENTS.md)
- [ ] Deprecation notices added to old directories
- [ ] OpenSpec CLI works with new structure
- [ ] No broken links in documentation

## Timeline Estimate

- **Phase 1** (Create directories + config): 30 minutes
- **Phase 2** (Copy files): 1 hour
- **Phase 3** (Update documentation): 1 hour
- **Phase 4** (Testing): 30 minutes
- **Total**: ~3 hours

## Dependencies

- OpenSpec CLI (already installed)
- Git (for file operations)
- Text editor (for documentation updates)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Broken links in docs | Medium | Keep old files, add redirects |
| OpenSpec CLI incompatibility | High | Test early, use config file |
| Team confusion | Medium | Clear deprecation notices |
| Git history loss | Low | Use `git mv` or document mapping |

## Open Questions

1. Should we use `git mv` or `cp` for file migration?
   - **Recommendation**: Use `cp` first, then `git rm` old files after validation
2. When to remove old directories?
   - **Recommendation**: After 3-6 months, or never (keep as archive)
3. Should we update test file paths?
   - **Recommendation**: No, test files stay in `test/specs/`
