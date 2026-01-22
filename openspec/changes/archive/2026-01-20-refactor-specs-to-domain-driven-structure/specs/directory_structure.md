# Specification: Directory Structure Refactoring

## Overview

This specification defines the new directory structure and migration rules for refactoring OpenSpec specifications from technology-stack-based to domain/feature-based organization.

## Directory Structure Specification

### Top-Level Directories

```
openspec/specs/
├── engineering/      # Engineering practices and technical constraints
├── adr/              # Architecture Decision Records (existing)
├── domain/           # Core business domain models
├── api/              # API interface contracts
├── features/         # Feature-specific specifications
└── ui_system/        # Global UI design system
```

### Directory Purposes

#### `engineering/`
**Purpose**: Engineering practices, coding standards, and technical constraints

**Contents**:
- `guide.md` - Spec Coding methodology
- `summary.md` - Implementation summary
- `tech_stack.md` - Technology stack constraints
- `architecture_patterns.md` - Architectural patterns
- `directory_conventions.md` - Directory organization rules

**Rules**:
- All engineering-related documentation goes here
- No feature-specific content
- Focus on "how we build" rather than "what we build"

#### `domain/`
**Purpose**: Core business domain models and protocols

**Contents**:
- `common_types.md` - Shared type definitions
- `pool_model.md` - Pool ownership model
- `device_config.md` - Device configuration
- `card_store.md` - Card storage model
- `sync_protocol.md` - Synchronization protocol

**Rules**:
- Technology-agnostic domain concepts
- No UI-specific content
- No implementation details (Rust/Flutter)
- Focus on "what exists" in the business domain

#### `api/`
**Purpose**: API interface contracts between layers

**Contents**:
- `api_spec.md` - Complete API specification

**Rules**:
- Interface definitions only
- Request/response formats
- Error codes and handling
- No implementation details

#### `features/`
**Purpose**: Feature-specific specifications organized by functionality

**Structure**:
```
features/
├── <feature_name>/
│   ├── logic.md       # Business logic (optional)
│   ├── ui_shared.md   # Cross-platform UI (optional)
│   ├── ui_mobile.md   # Mobile-specific UI (optional)
│   └── ui_desktop.md  # Desktop-specific UI (optional)
```

**Naming Convention**:
- Use `snake_case` for directory names
- Use semantic names: `card_editor`, `search`, `sync_feedback`
- Avoid technical prefixes: ~~`SP-FLT-MOB-001`~~

**Rules**:
- One directory per feature
- Group all related specs (logic + UI) together
- Use `ui_shared.md` for cross-platform UI
- Use `ui_mobile.md` / `ui_desktop.md` for platform-specific UI
- Use `logic.md` for backend/business logic

**Examples**:
- `features/card_editor/` - Card editing functionality
- `features/search/` - Search functionality
- `features/sync_feedback/` - Sync status feedback

#### `ui_system/`
**Purpose**: Global UI design system and shared components

**Contents**:
- `design_tokens.md` - Colors, typography, spacing
- `responsive_layout.md` - Layout system
- `shared_widgets.md` - Reusable UI components

**Rules**:
- Global UI patterns only
- No feature-specific UI
- Cross-platform design principles

## File Naming Specification

### Naming Rules

1. **Use `snake_case`** for all file names
   - ✅ `card_editor.md`
   - ❌ `CardEditor.md`, `card-editor.md`

2. **Use semantic names** that describe functionality
   - ✅ `sync_protocol.md`
   - ❌ `SP-SYNC-006.md`

3. **Avoid technical prefixes**
   - ❌ `SP-FLT-MOB-001-card-list.md`
   - ✅ `card_list/ui_mobile.md`

4. **Use suffixes to indicate scope**
   - `logic.md` - Business logic
   - `ui_shared.md` - Cross-platform UI
   - `ui_mobile.md` - Mobile-specific UI
   - `ui_desktop.md` - Desktop-specific UI

### File Placement Rules

| Content Type | Placement | Example |
|--------------|-----------|---------|
| Domain model | `domain/<model>.md` | `domain/pool_model.md` |
| API contract | `api/<api>.md` | `api/api_spec.md` |
| Feature logic | `features/<feature>/logic.md` | `features/search/logic.md` |
| Cross-platform UI | `features/<feature>/ui_shared.md` | `features/onboarding/ui_shared.md` |
| Mobile UI | `features/<feature>/ui_mobile.md` | `features/card_list/ui_mobile.md` |
| Desktop UI | `features/<feature>/ui_desktop.md` | `features/toolbar/ui_desktop.md` |
| Global UI pattern | `ui_system/<pattern>.md` | `ui_system/design_tokens.md` |
| Engineering practice | `engineering/<practice>.md` | `engineering/guide.md` |

## Migration Specification

### Migration Rules

1. **Copy, don't move** (initially)
   - Keep old files intact during migration
   - Validate new structure before removing old files

2. **Preserve content**
   - No content changes during migration
   - Only change file location and name

3. **Update references**
   - Update all links in documentation
   - Update indexes (README.md files)

4. **Add deprecation notices**
   - Add `DEPRECATED.md` in old directories
   - Point to new locations

### Deprecated Directories

The following directories are deprecated and should not receive new files:

- `openspec/specs/rust/` → Use `domain/`, `api/`, or `features/*/logic.md`
- `openspec/specs/flutter/` → Use `features/*/ui_*.md` or `ui_system/`

## Validation Specification

### Directory Structure Validation

```bash
# All required directories must exist
test -d openspec/specs/engineering
test -d openspec/specs/domain
test -d openspec/specs/api
test -d openspec/specs/features
test -d openspec/specs/ui_system
```

### File Count Validation

```bash
# Total spec files should match (38 files)
find openspec/specs -name "*.md" -type f | wc -l
# Should equal 38 (excluding README.md and DEPRECATED.md)
```

### Naming Convention Validation

```bash
# No files should have tech stack prefixes in new structure
find openspec/specs/features -name "SP-*" | wc -l
# Should equal 0
```

### Link Validation

```bash
# No broken links in main README
grep -r "\[.*\](.*rust/.*)" openspec/specs/README.md
# Should return no results after migration
```

## Configuration Specification

### OpenSpec Configuration

File: `.openspec/config.json`

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

### Directory Conventions Document

File: `engineering/directory_conventions.md`

Must include:
- Directory structure overview
- Placement rules for each content type
- Naming conventions
- Examples of correct placement
- List of deprecated directories
- Migration timeline

## Success Criteria

### Structural Criteria

- [ ] All 5 top-level directories created
- [ ] All 38 spec files migrated to new locations
- [ ] No files remain in deprecated directories (after grace period)
- [ ] All file names follow `snake_case` convention
- [ ] No technical prefixes in new structure

### Documentation Criteria

- [ ] `openspec/specs/README.md` updated with new structure
- [ ] `CLAUDE.md` updated with new paths
- [ ] `AGENTS.md` updated with new paths
- [ ] `engineering/directory_conventions.md` created
- [ ] `DEPRECATED.md` added to old directories

### Functional Criteria

- [ ] OpenSpec CLI works with new structure
- [ ] No broken links in documentation
- [ ] All references updated to new paths
- [ ] Configuration file created and tested

## Acceptance Tests

### Test 1: Directory Structure

```bash
# Verify all required directories exist
for dir in engineering domain api features ui_system; do
  test -d "openspec/specs/$dir" || echo "Missing: $dir"
done
```

### Test 2: File Migration

```bash
# Verify all features have correct structure
for feature in card_editor card_list search onboarding home_screen sync_feedback navigation gestures fab toolbar context_menu; do
  test -d "openspec/specs/features/$feature" || echo "Missing feature: $feature"
done
```

### Test 3: Naming Convention

```bash
# Verify no tech stack prefixes
if find openspec/specs/features -name "SP-*" | grep -q .; then
  echo "FAIL: Found tech stack prefixes"
else
  echo "PASS: No tech stack prefixes"
fi
```

### Test 4: OpenSpec CLI

```bash
# Test OpenSpec CLI with new structure
openspec new change "test-new-structure" && \
openspec status --change "test-new-structure" && \
echo "PASS: OpenSpec CLI works"
```

## Rollback Specification

### Rollback Conditions

Rollback if:
- OpenSpec CLI fails with new structure
- More than 10% of links are broken
- Team consensus to revert

### Rollback Procedure

1. Revert documentation changes via git
2. Remove new directories (if desired)
3. Keep old structure as-is
4. No data loss (old files never deleted)

## Timeline

- **Phase 1** (Preparation): Create directories and config - 30 min
- **Phase 2** (Migration): Copy files to new locations - 1 hour
- **Phase 3** (Documentation): Update docs - 1 hour
- **Phase 4** (Validation): Test and verify - 30 min
- **Phase 5** (Deprecation): Add notices - 15 min
- **Total**: ~3 hours

## Dependencies

- OpenSpec CLI (installed)
- Git (for version control)
- Bash (for validation scripts)

## References

- Original advice: `docs/advice/openspec-doc-advice.md`
- Current structure: `openspec/specs/README.md`
- Spec Coding guide: `openspec/specs/SPEC_CODING_GUIDE.md`
