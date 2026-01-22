# Spec Format Standard

## ADDED Requirements

### Requirement: Main specs describe stable behavior
The system SHALL describe the current, stable behavior of the system in specs under `openspec/specs/`.
It SHALL avoid describing transformation steps or migration history in main specs.

#### Scenario: Write a main spec overview
- **WHEN** a main spec is created or revised
- **THEN** its overview SHALL describe the present-state behavior in active voice
- **AND** it SHALL NOT describe the change process or migration steps

### Requirement: Main specs exclude change-history sections
The system SHALL NOT include change-history sections such as "Core Changes", "Key Changes", or "Behavior Change" in main specs.

#### Scenario: Remove change-history markers
- **WHEN** a main spec contains headings or annotations labeled "Core Changes", "Key Changes", "Behavior Change", or "Transformation"
- **THEN** those sections SHALL be removed from the main spec
- **AND** the change history SHALL be documented in a delta spec under `openspec/changes/<change-name>/specs/`

### Requirement: Main spec titles use stable naming
The system SHALL title main specs as "<Subject> Specification".
It SHALL NOT use "Transformation" or "Migration" wording in main spec titles.

#### Scenario: Name a main spec
- **WHEN** a specification is stored under `openspec/specs/`
- **THEN** its title SHALL use "Specification"
- **AND** it SHALL NOT include "Transformation" or "Migration"

### Requirement: Delta specs capture change narratives
The system SHALL document change narratives and rationale in delta specs under `openspec/changes/<change-name>/specs/`.

#### Scenario: Record a behavior change
- **WHEN** a change introduces new behavior or removes old behavior
- **THEN** the delta spec SHALL capture the change narrative and rationale
- **AND** the corresponding main spec SHALL be updated to describe only the stable end state
