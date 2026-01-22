# Spec Migration Validator

## Overview

The Spec Migration Validator verifies that the migration from technology-stack-based specification structure (`rust/`, `flutter/`) to domain-driven structure (`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`) is complete and properly documented.

**Purpose**: Ensure the new domain-driven spec structure is complete and old specs are properly deprecated with migration paths.

**Scope**: Validates directory structure, naming conventions, cross-references, and migration documentation.

**Implementation**: `tool/verify_spec_sync.dart` (migration validation layer)

## Requirements

### Requirement: Verify completeness of domain-driven spec structure

The system SHALL verify that all expected specification categories exist in the new domain-driven structure.

#### Scenario: Verify engineering specs exist
- **WHEN** the validator checks the new structure
- **THEN** it SHALL verify that `openspec/specs/engineering/` contains required files: guide.md, summary.md, architecture_patterns.md, tech_stack.md, directory_conventions.md

#### Scenario: Verify domain specs exist
- **WHEN** the validator checks domain coverage
- **THEN** it SHALL verify that core domain models have corresponding specs in `openspec/specs/domain/`

#### Scenario: Verify API specs exist
- **WHEN** the validator checks API coverage
- **THEN** it SHALL verify that `openspec/specs/api/api_spec.md` exists and covers main API surface

#### Scenario: Verify feature specs exist
- **WHEN** the validator checks feature coverage
- **THEN** it SHALL verify that user-facing features have corresponding specs in `openspec/specs/features/`

#### Scenario: Verify UI system specs exist
- **WHEN** the validator checks UI coverage
- **THEN** it SHALL verify that shared UI components and patterns have specs in `openspec/specs/ui_system/`

### Requirement: Verify deprecated specs are properly marked

The system SHALL verify that old technology-stack-based specs are properly marked as deprecated and reference new locations.

#### Scenario: Verify deprecated markers exist
- **WHEN** the validator checks old spec directories
- **THEN** it SHALL verify that `openspec/specs/rust/DEPRECATED.md` and `openspec/specs/flutter/DEPRECATED.md` exist

#### Scenario: Verify migration mappings are documented
- **WHEN** the validator reads deprecated markers
- **THEN** it SHALL verify that each deprecated spec has a documented migration path to new location

#### Scenario: Warn about undocumented old specs
- **WHEN** the validator finds specs in `openspec/specs/rust/` or `openspec/specs/flutter/` without migration notes
- **THEN** it SHALL report them as WARNING: "Old spec missing migration documentation"

### Requirement: Validate spec file naming conventions

The system SHALL verify that all specs in the new structure follow the documented naming conventions.

#### Scenario: Verify snake_case naming
- **WHEN** the validator scans spec filenames
- **THEN** it SHALL verify that all files use snake_case (e.g., `card_store.md`, not `CardStore.md`)

#### Scenario: Verify no technology prefixes
- **WHEN** the validator scans spec filenames
- **THEN** it SHALL verify that no files have technology prefixes (e.g., no `rust_card_store.md` or `flutter_note_card.md`)

#### Scenario: Verify semantic names
- **WHEN** the validator scans feature specs
- **THEN** it SHALL verify that filenames describe domain concepts, not technical implementation (e.g., `card_editor.md` not `text_field_widget.md`)

### Requirement: Verify spec cross-references are valid

The system SHALL verify that all references between specs point to valid locations in the new structure.

#### Scenario: Detect broken spec references
- **WHEN** a spec references another spec (e.g., "See domain/card_store.md")
- **AND** the referenced spec doesn't exist at that path
- **THEN** the system SHALL report "Broken reference: domain/card_store.md not found"

#### Scenario: Detect references to deprecated locations
- **WHEN** a spec references old locations (e.g., "See rust/single_pool_model_spec.md")
- **THEN** the system SHALL report "Reference to deprecated location: update to domain/pool_model.md"

#### Scenario: Validate ADR references
- **WHEN** a spec references an ADR (e.g., "See adr/0002-dual-layer-architecture.md")
- **THEN** it SHALL verify the ADR file exists

### Requirement: Verify spec structure consistency

The system SHALL verify that all specs follow the expected structural conventions.

#### Scenario: Verify required sections exist
- **WHEN** the validator reads a spec file
- **THEN** it SHALL verify that required sections exist: Overview/Summary, Requirements, Examples/Scenarios

#### Scenario: Verify requirement format
- **WHEN** the validator parses requirements
- **THEN** it SHALL verify that requirements use proper markers (### Requirement:, #### Scenario:)

#### Scenario: Warn about missing scenarios
- **WHEN** a requirement exists without any scenarios
- **THEN** the system SHALL report WARNING: "Requirement missing scenarios: <requirement name>"

### Requirement: Generate migration validation report

The system SHALL generate a report showing the migration validation status and any issues found.

#### Scenario: Report migration completeness
- **WHEN** the validator finishes checking
- **THEN** it SHALL report the count of specs successfully migrated vs expected total

#### Scenario: Report structural issues
- **WHEN** naming convention violations or structural issues are found
- **THEN** the system SHALL list them with file paths and recommendations

#### Scenario: Report broken references
- **WHEN** broken or deprecated references are found
- **THEN** the system SHALL list them with old path, expected new path, and file location

#### Scenario: Generate summary scorecard
- **WHEN** validation completes
- **THEN** it SHALL generate a scorecard showing: Structure Completeness (X/Y), Naming Compliance (X/Y), Reference Validity (X/Y), Spec Quality (X/Y)

## Examples

### Usage Example

```bash
# Run migration validation
dart tool/verify_spec_sync.dart

# Check for deprecated spec references
grep -r "rust/" openspec/specs/domain/
grep -r "flutter/" openspec/specs/features/
```

### Validation Report Example

```markdown
## Migration Validation

### Structure Completeness: ✅ 5/5
- ✅ engineering/ directory exists with required files
- ✅ domain/ directory exists with core models
- ✅ api/ directory exists with API specs
- ✅ features/ directory exists with feature specs
- ✅ ui_system/ directory exists with UI specs

### Naming Compliance: ✅ 100%
- All spec files use snake_case naming
- No technology prefixes found
- Semantic names used throughout

### Reference Validity: ✅ 100%
- All cross-references point to valid locations
- No references to deprecated locations
- All ADR references valid
```

## See Also

- [Spec Coverage Checker](spec_coverage_checker.md) - Checks coverage of code modules
- [Directory Conventions](directory_conventions.md) - Specification directory structure
- [Spec Format Standard](spec_format_standard.md) - Specification format requirements
