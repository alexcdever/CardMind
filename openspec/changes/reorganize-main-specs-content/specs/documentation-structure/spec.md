# Documentation Structure Reorganization Specification

## ADDED Requirements

### Requirement: Four-layer documentation architecture

The documentation system SHALL organize main specifications into four distinct layers: domain, features, ui, and architecture.

#### Scenario: Domain layer contains only domain models and business rules
- **WHEN** a developer navigates to the domain/ directory
- **THEN** the system SHALL contain only domain model definitions and business rules
- **AND** SHALL NOT contain technical implementation details

#### Scenario: Features layer contains user-facing functionality
- **WHEN** a developer navigates to the features/ directory
- **THEN** the system SHALL contain business功能规格 from user perspective
- **AND** SHALL NOT contain UI component specifications

#### Scenario: UI layer separates mobile and desktop platforms
- **WHEN** a developer navigates to the ui/ directory
- **THEN** the system SHALL organize UI specifications by platform (mobile/desktop/shared)
- **AND** SHALL clearly distinguish platform-specific interaction patterns

#### Scenario: Architecture layer contains technical implementation
- **WHEN** a developer navigates to the architecture/ directory
- **THEN** the system SHALL contain technical architecture and implementation details
- **AND** SHALL include storage, sync, security, and bridge specifications

### Requirement: Platform-specific UI documentation

The documentation system SHALL separate mobile and desktop UI specifications to reflect different interaction patterns.

#### Scenario: Mobile UI specifications in dedicated directory
- **WHEN** a developer looks for mobile UI specifications
- **THEN** the system SHALL provide ui/screens/mobile/ and ui/components/mobile/ directories
- **AND** SHALL document mobile-specific patterns (gestures, bottom navigation, full-screen editing)

#### Scenario: Desktop UI specifications in dedicated directory
- **WHEN** a developer looks for desktop UI specifications
- **THEN** the system SHALL provide ui/screens/desktop/ and ui/components/desktop/ directories
- **AND** SHALL document desktop-specific patterns (multi-column layout, inline editing, context menus)

#### Scenario: Shared UI components in common directory
- **WHEN** a UI component is used on both platforms
- **THEN** the system SHALL place its specification in ui/components/shared/
- **AND** SHALL document platform-agnostic behavior

### Requirement: Engineering guides in engineering directory

The documentation system SHALL place engineering guides and meta-specifications in the engineering/ directory, not in the main specs/ directory.

#### Scenario: Bilingual compliance guide in engineering directory
- **WHEN** a developer looks for documentation writing guidelines
- **THEN** the system SHALL provide the guide in engineering/bilingual_compliance_spec.md
- **AND** SHALL NOT place it in specs/bilingual-compliance/

#### Scenario: No engineering guides in main specs directory
- **WHEN** scanning the specs/ directory
- **THEN** the system SHALL contain only business and technical specifications
- **AND** SHALL NOT contain meta-specifications or engineering guides

### Requirement: Document migration with preserved history

The documentation system SHALL migrate documents while preserving Git history using git mv.

#### Scenario: Git history preserved during migration
- **WHEN** a document is migrated to a new location
- **THEN** the system SHALL use git mv command
- **AND** SHALL preserve the document's Git history

#### Scenario: Migration mapping table maintained
- **WHEN** documents are migrated
- **THEN** the system SHALL maintain a migration_map.md file
- **AND** SHALL document old path, new path, migration type, and platform

### Requirement: Cross-reference updates

The documentation system SHALL update all cross-references when documents are migrated.

#### Scenario: ADR references updated
- **WHEN** a specification document is moved
- **THEN** the system SHALL update all references in docs/adr/ directory
- **AND** SHALL ensure all links remain valid

#### Scenario: Test file references updated
- **WHEN** a specification document is moved
- **THEN** the system SHALL update test file comments referencing the spec
- **AND** SHALL maintain traceability between tests and specs

#### Scenario: Inter-document references updated
- **WHEN** a specification document is moved
- **THEN** the system SHALL update "Related Documents" sections in other specs
- **AND** SHALL ensure all internal links remain valid

### Requirement: Redirect documents for old paths

The documentation system SHALL create redirect documents at old paths to guide users to new locations.

#### Scenario: Redirect document at old location
- **WHEN** a document is migrated to a new location
- **THEN** the system SHALL create a redirect document at the old path
- **AND** SHALL contain a link to the new location with clear migration message

### Requirement: Platform-aware document splitting

The documentation system SHALL split documents that mix mobile and desktop concerns into platform-specific versions.

#### Scenario: Home screen split by platform
- **WHEN** migrating home_screen.md that contains both mobile and desktop specifications
- **THEN** the system SHALL create ui/screens/mobile/home_screen.md
- **AND** SHALL create ui/screens/desktop/home_screen.md
- **AND** SHALL document platform-specific layouts and interactions

#### Scenario: Card list item split by platform
- **WHEN** migrating card_list_item.md that contains platform-specific UI
- **THEN** the system SHALL create ui/components/mobile/card_list_item.md
- **AND** SHALL create ui/components/desktop/card_list_item.md
- **AND** SHALL preserve platform-specific interaction patterns

### Requirement: Content reorganization by layer

The documentation system SHALL reorganize document content to match the semantic meaning of its target layer.

#### Scenario: Domain documents use business language
- **WHEN** a document is placed in the domain/ layer
- **THEN** the system SHALL use business terminology
- **AND** SHALL NOT include technical implementation details

#### Scenario: Feature documents use user perspective
- **WHEN** a document is placed in the features/ layer
- **THEN** the system SHALL describe functionality from user perspective
- **AND** SHALL focus on what users can do, not how it's implemented

#### Scenario: UI documents use technical language
- **WHEN** a document is placed in the ui/ layer
- **THEN** the system SHALL describe UI implementation details
- **AND** SHALL include component structure, props, and interactions

#### Scenario: Architecture documents include implementation details
- **WHEN** a document is placed in the architecture/ layer
- **THEN** the system SHALL include technical architecture decisions
- **AND** SHALL document implementation patterns and trade-offs

### Requirement: Bilingual format compliance

The documentation system SHALL maintain bilingual (English-Chinese) format compliance for all migrated documents.

#### Scenario: All section headings remain bilingual
- **WHEN** documents are migrated and reorganized
- **THEN** the system SHALL preserve bilingual section headings
- **AND** SHALL follow the format defined in engineering/bilingual_spec_guide.md

#### Scenario: Metadata format preserved
- **WHEN** documents are migrated
- **THEN** the system SHALL maintain metadata in **Key** | **键**: value format
- **AND** SHALL ensure all required metadata fields are present

## MODIFIED Requirements

### Requirement: Main specs directory structure

The main specifications directory SHALL be organized into domain, features, ui, architecture, api, and ui_system layers.

**Previous structure**:
```
specs/
├── domain/           # Mixed domain models and technical implementation
├── features/         # Mixed UI components and screens
├── api/
├── ui_system/
└── bilingual-compliance/
```

**New structure**:
```
specs/
├── domain/           # Pure domain models and business rules
├── features/         # Business功能规格 (user perspective)
├── ui/               # UI specifications (platform-separated)
├── architecture/     # Technical architecture and implementation
├── api/              # Public API specifications
└── ui_system/        # UI design system
```

#### Scenario: Domain layer contains only domain concerns
- **WHEN** a developer navigates to specs/domain/
- **THEN** the system SHALL contain only domain model definitions
- **AND** SHALL organize by domain entity (card/, pool/, sync/)
- **AND** SHALL NOT contain storage implementation or technical protocols

#### Scenario: Features layer contains business功能
- **WHEN** a developer navigates to specs/features/
- **THEN** the system SHALL contain business功能规格
- **AND** SHALL organize by功能 area (card_management/, pool_management/, p2p_sync/)
- **AND** SHALL NOT contain UI component specifications

#### Scenario: UI layer organized by platform
- **WHEN** a developer navigates to specs/ui/
- **THEN** the system SHALL contain platform-separated UI specifications
- **AND** SHALL organize by screens/, components/, and adaptive/
- **AND** SHALL separate mobile/, desktop/, and shared/ concerns

#### Scenario: Architecture layer contains technical specs
- **WHEN** a developer navigates to specs/architecture/
- **THEN** the system SHALL contain technical implementation specifications
- **AND** SHALL organize by storage/, sync/, security/, and bridge/
- **AND** SHALL include implementation details and architectural decisions

#### Scenario: Engineering guides not in main specs
- **WHEN** scanning the specs/ directory
- **THEN** the system SHALL NOT contain bilingual-compliance/ directory
- **AND** SHALL place engineering guides in engineering/ directory instead
