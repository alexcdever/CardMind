## ADDED Requirements

### Requirement: Scan code files for modules and components

The system SHALL scan Rust source files in `rust/src/` and Flutter source files in `lib/` to identify all modules and components that should have corresponding specification documentation.

#### Scenario: Scan Rust modules
- **WHEN** the coverage checker scans `rust/src/` directory
- **THEN** it SHALL identify all `.rs` files as modules and extract their public API surface (public functions, structs, enums)

#### Scenario: Scan Flutter widgets
- **WHEN** the coverage checker scans `lib/widgets/` and `lib/screens/` directories
- **THEN** it SHALL identify all widget files and extract their public interfaces

#### Scenario: Ignore test and generated files
- **WHEN** the coverage checker encounters files in `test/` or files with `.g.dart` extension
- **THEN** it SHALL exclude them from coverage analysis

### Requirement: Map code modules to specification documents

The system SHALL map identified code modules to their expected specification locations in the new domain-driven structure (`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`).

#### Scenario: Map Rust domain module to spec
- **WHEN** the system finds `rust/src/card_store.rs`
- **THEN** it SHALL look for a corresponding spec at `openspec/specs/domain/card_store.md`

#### Scenario: Map Flutter feature to spec
- **WHEN** the system finds `lib/widgets/note_card.dart`
- **THEN** it SHALL look for a corresponding spec at `openspec/specs/features/*/ui_*.md` matching the component name

#### Scenario: Map adaptive UI to spec
- **WHEN** the system finds `lib/adaptive/layouts/three_column_layout.dart`
- **THEN** it SHALL look for a corresponding spec at `openspec/specs/ui_system/*.md`

### Requirement: Identify missing specifications

The system SHALL generate a list of code modules that lack corresponding specification documents.

#### Scenario: Report missing spec for domain module
- **WHEN** a Rust module exists in `rust/src/` but no spec exists in `openspec/specs/domain/`
- **THEN** the system SHALL report it as "Missing Spec" with CRITICAL priority

#### Scenario: Report missing spec for UI component
- **WHEN** a Flutter widget exists in `lib/widgets/` but no spec exists in `openspec/specs/features/`
- **THEN** the system SHALL report it as "Missing Spec" with WARNING priority

### Requirement: Identify orphaned specifications

The system SHALL generate a list of specification documents that have no corresponding code implementation.

#### Scenario: Report orphaned spec
- **WHEN** a spec exists in `openspec/specs/features/search/logic.md` but no implementation found in Rust code
- **THEN** the system SHALL report it as "Orphaned Spec" with WARNING priority

#### Scenario: Ignore deprecated specs
- **WHEN** checking for orphaned specs
- **THEN** the system SHALL NOT report specs in `openspec/specs/rust/` or `openspec/specs/flutter/` directories (marked DEPRECATED)

### Requirement: Generate coverage report

The system SHALL generate a coverage report in both Markdown and JSON formats showing the percentage of code modules with specifications.

#### Scenario: Calculate coverage percentage
- **WHEN** the coverage checker completes scanning
- **THEN** it SHALL calculate coverage as: (modules with specs / total modules) × 100%

#### Scenario: Generate Markdown report
- **WHEN** the coverage checker finishes analysis
- **THEN** it SHALL write a report to `SPEC_SYNC_REPORT.md` with sections: Summary, Missing Specs, Orphaned Specs

#### Scenario: Generate JSON report
- **WHEN** the coverage checker finishes analysis
- **THEN** it SHALL write machine-readable data to `spec_sync_report.json` for automation

### Requirement: Support selective scanning

The system SHALL allow users to scan specific directories or modules instead of the entire codebase.

#### Scenario: Scan only domain modules
- **WHEN** user runs `dart tool/verify_spec_sync.dart --scope=domain`
- **THEN** it SHALL only check Rust modules and their domain specs

#### Scenario: Scan only UI components
- **WHEN** user runs `dart tool/verify_spec_sync.dart --scope=features`
- **THEN** it SHALL only check Flutter widgets and their feature specs
