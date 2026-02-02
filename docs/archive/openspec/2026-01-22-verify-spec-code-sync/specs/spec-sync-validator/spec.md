## ADDED Requirements

### Requirement: Extract API signatures from specifications

The system SHALL parse specification documents to extract declared API signatures, data structures, and behavioral contracts.

#### Scenario: Extract function signatures from spec
- **WHEN** the validator reads a spec containing code blocks with function signatures
- **THEN** it SHALL extract function names, parameter types, and return types

#### Scenario: Extract struct definitions from spec
- **WHEN** the validator reads a spec containing data structure definitions
- **THEN** it SHALL extract struct/class names and their primary fields

#### Scenario: Handle multiple language specs
- **WHEN** the validator processes specs in `domain/` (Rust) and `features/` (Flutter)
- **THEN** it SHALL apply language-specific parsing rules for each

### Requirement: Extract API signatures from code

The system SHALL parse Rust and Dart source files to extract actual implemented API signatures and data structures.

#### Scenario: Extract Rust public functions
- **WHEN** the validator scans a Rust file
- **THEN** it SHALL extract all `pub fn` declarations with their signatures

#### Scenario: Extract Rust public structs
- **WHEN** the validator scans a Rust file
- **THEN** it SHALL extract all `pub struct` definitions with their fields

#### Scenario: Extract Dart widget classes
- **WHEN** the validator scans a Dart file
- **THEN** it SHALL extract all public widget classes and their constructors

#### Scenario: Ignore private implementations
- **WHEN** the validator encounters private functions or internal structs
- **THEN** it SHALL exclude them from comparison (only validate public API)

### Requirement: Compare spec declarations with code implementations

The system SHALL compare extracted API signatures from specs against actual code implementations to identify mismatches.

#### Scenario: Detect signature mismatch
- **WHEN** a spec declares `fn create_card(title: String, content: String) -> Result<CardId>`
- **AND** code implements `fn create_card(title: String, content: String, timestamp: i64) -> Result<CardId>`
- **THEN** the system SHALL report "Signature mismatch: parameter count differs (expected 2, found 3)"

#### Scenario: Detect return type mismatch
- **WHEN** a spec declares function returning `Result<CardId, Error>`
- **AND** code implements function returning `CardId` (no Result wrapper)
- **THEN** the system SHALL report "Return type mismatch: expected Result<CardId>, found CardId"

#### Scenario: Detect missing field in struct
- **WHEN** a spec declares struct with fields `id`, `title`, `content`
- **AND** code implements struct with fields `id`, `title`, `content`, `created_at`
- **THEN** the system SHALL report "Additional field in code: created_at (not in spec)"

#### Scenario: Accept compatible changes
- **WHEN** a spec declares `fn get_card(id: CardId)` and code adds optional parameter with default
- **THEN** the system SHALL NOT report as mismatch (backward compatible)

### Requirement: Report consistency issues

The system SHALL generate a report of all detected inconsistencies between specs and code, categorized by severity.

#### Scenario: Report critical inconsistencies
- **WHEN** a public API exists in code but is completely missing from spec
- **THEN** the system SHALL report it as CRITICAL priority

#### Scenario: Report warnings for signature differences
- **WHEN** an API exists in both spec and code but signatures differ
- **THEN** the system SHALL report it as WARNING priority with detailed comparison

#### Scenario: Group issues by module
- **WHEN** generating the report
- **THEN** it SHALL group issues by module/capability for easier review

### Requirement: Support incremental validation

The system SHALL allow validation of specific modules or capabilities instead of the entire codebase.

#### Scenario: Validate single domain module
- **WHEN** user runs `dart tool/verify_spec_sync.dart --module=card_store`
- **THEN** it SHALL only validate `rust/src/card_store.rs` against `openspec/specs/domain/card_store.md`

#### Scenario: Validate all domain modules
- **WHEN** user runs `dart tool/verify_spec_sync.dart --scope=domain`
- **THEN** it SHALL validate all modules in `rust/src/` against their domain specs

### Requirement: Generate actionable sync recommendations

The system SHALL provide specific recommendations for each inconsistency to guide spec or code updates.

#### Scenario: Recommend spec update
- **WHEN** code has additional parameters not in spec
- **THEN** the system SHALL recommend "Update spec to add parameter: timestamp: i64"

#### Scenario: Recommend code review
- **WHEN** spec declares API but code doesn't implement it
- **THEN** the system SHALL recommend "Implement missing function: create_card()"

#### Scenario: Provide file and line references
- **WHEN** reporting an inconsistency
- **THEN** the system SHALL include file path and line number for both spec and code locations
