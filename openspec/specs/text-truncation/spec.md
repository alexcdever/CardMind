# text-truncation Specification

## Purpose
TBD - created by archiving change note-card-ui-design. Update Purpose after archive.
## Requirements
### Requirement: System shall truncate single-line text with ellipsis
The system SHALL truncate text that exceeds single line width with proper ellipsis.

#### Scenario: Truncate long title text
- **WHEN** a note card title text exceeds the available single line width
- **THEN** the system truncates the text and adds ellipsis (...) at the end
- **AND** the truncated text fits within the available width

#### Scenario: Handle short title text
- **WHEN** a note card title text fits within the available single line width
- **THEN** the system displays the full text without truncation
- **AND** no ellipsis is added

#### Scenario: Handle empty title text
- **WHEN** a note card title is empty or null
- **THEN** the system displays the placeholder text "无标题"
- **AND** no truncation is applied

### Requirement: System shall truncate multi-line text with ellipsis
The system SHALL truncate text that exceeds specified line count with proper ellipsis.

#### Scenario: Truncate content on desktop (4 lines)
- **WHEN** a note card content exceeds 4 lines on desktop platform
- **THEN** the system truncates after exactly 4 lines and adds ellipsis
- **AND** the ellipsis appears at the end of the 4th line

#### Scenario: Truncate content on mobile (3 lines)
- **WHEN** a note card content exceeds 3 lines on mobile platform
- **THEN** the system truncates after exactly 3 lines and adds ellipsis
- **AND** the ellipsis appears at the end of the 3rd line

#### Scenario: Handle short content text
- **WHEN** a note card content fits within the line limit for the platform
- **THEN** the system displays the full content without truncation
- **AND** no ellipsis is added

#### Scenario: Handle empty content text
- **WHEN** a note card content is empty or null
- **THEN** the system displays the placeholder text "点击添加内容..."
- **AND** no truncation is applied

### Requirement: System shall handle mixed content and whitespace
The system SHALL properly truncate text containing various characters and whitespace.

#### Scenario: Handle content with line breaks
- **WHEN** note card content contains multiple line breaks
- **THEN** the system counts actual rendered lines for truncation
- **AND** line breaks are preserved in the truncated result

#### Scenario: Handle content with special characters
- **WHEN** note card content contains special Unicode characters or emojis
- **THEN** the system correctly measures text width and line height
- **AND** truncation works correctly with special characters

#### Scenario: Handle content with excessive whitespace
- **WHEN** note card content contains excessive spaces or tabs
- **THEN** the system normalizes whitespace for proper rendering
- **AND** truncation works on the normalized content

### Requirement: System shall provide platform-aware text truncation
The system SHALL apply different truncation rules based on the platform.

#### Scenario: Desktop platform truncation
- **WHEN** running on desktop platform
- **THEN** the system applies desktop-specific line limits (4 lines for content)
- **AND** uses desktop-appropriate font metrics for calculations

#### Scenario: Mobile platform truncation
- **WHEN** running on mobile platform
- **THEN** the system applies mobile-specific line limits (3 lines for content)
- **AND** uses mobile-appropriate font metrics for calculations

#### Scenario: Platform detection
- **WHEN** determining truncation rules
- **THEN** the system uses reliable platform detection
- **AND** applies the correct rules for the current platform

### Requirement: System shall support internationalized text truncation
The system SHALL handle text truncation correctly for different languages.

#### Scenario: Chinese text truncation
- **WHEN** truncating Chinese text
- **THEN** the system correctly measures character width
- **AND** ellipsis appears in appropriate position without breaking characters

#### Scenario: Mixed language text truncation
- **WHEN** truncating text containing multiple languages
- **THEN** the system handles mixed character sets correctly
- **AND** maintains proper text flow in the truncated result

#### Scenario: Right-to-left text truncation
- **WHEN** truncating right-to-left language text
- **THEN** the system maintains correct text direction
- **AND** ellipsis appears in the appropriate position

### Requirement: Text truncation shall validate input data models
The system SHALL properly handle and validate Card data model fields before truncation.

#### Scenario: Validate title field before truncation
- **WHEN** preparing to truncate note card title
- **THEN** the system validates that title field is a valid String
- **AND** handles null or undefined values by using placeholder text
- **AND** ensures title length is within reasonable bounds (≤ 10,000 characters)

#### Scenario: Validate content field before truncation
- **WHEN** preparing to truncate note card content
- **THEN** the system validates that content field is a valid String
- **AND** handles null or undefined values by using placeholder text
- **AND** ensures content length is within reasonable bounds (≤ 1,000,000 characters)

#### Scenario: Handle malformed Unicode content
- **WHEN** note card contains invalid Unicode sequences
- **THEN** the system gracefully falls back to displaying placeholder text
- **AND** logs the malformed content for debugging
- **AND** does not crash the card rendering process

#### Scenario: Validate Card model serialization
- **WHEN** receiving Card data from backend or storage
- **THEN** the system validates that required fields (id, title, content, updated_at) are present
- **AND** rejects or fixes malformed Card objects before rendering
- **AND** ensures proper error handling for corrupted data

