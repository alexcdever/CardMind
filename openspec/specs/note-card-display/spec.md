# note-card-display Specification

## Purpose
TBD - created by archiving change note-card-ui-design. Update Purpose after archive.
## Requirements
### Requirement: Note card shall display title, content preview, and update time
The system SHALL display a note card with title, content preview, and update time in both desktop and mobile platforms.

#### Scenario: Display complete note card
- **WHEN** a note card is rendered with valid title, content, and update time
- **THEN** the card displays the title at the top, content preview in the middle, and update time at the bottom

#### Scenario: Display note card on desktop platform
- **WHEN** a note card is rendered on desktop platform
- **THEN** the card shows up to 4 lines of content preview with proper desktop styling

#### Scenario: Display note card on mobile platform
- **WHEN** a note card is rendered on mobile platform
- **THEN** the card shows up to 3 lines of content preview with proper mobile styling

### Requirement: Note card shall handle empty content gracefully
The system SHALL display appropriate placeholder text when title or content is empty.

#### Scenario: Display card with empty title
- **WHEN** a note card has an empty title
- **THEN** the system displays "无标题" (No Title) in gray color as placeholder

#### Scenario: Display card with empty content
- **WHEN** a note card has empty content
- **THEN** the system displays "点击添加内容..." (Click to add content...) in gray color as placeholder

### Requirement: Note card shall truncate long text properly
The system SHALL truncate long title and content text with ellipsis.

#### Scenario: Truncate long title
- **WHEN** a note card title exceeds single line width
- **THEN** the title is truncated with ellipsis (...) at the end

#### Scenario: Truncate long content on desktop
- **WHEN** a note card content exceeds 4 lines on desktop platform
- **THEN** the content is truncated after 4 lines with ellipsis

#### Scenario: Truncate long content on mobile
- **WHEN** a note card content exceeds 3 lines on mobile platform
- **THEN** the content is truncated after 3 lines with ellipsis

### Requirement: Note card shall adapt to different screen sizes
The system SHALL adjust layout and styling based on available screen space.

#### Scenario: Responsive width adjustment
- **WHEN** the screen width changes
- **THEN** the note card width adapts accordingly while maintaining readability

#### Scenario: Platform-specific styling
- **WHEN** the app runs on different platforms
- **THEN** the note card applies platform-appropriate styling (hover effects for desktop, touch-friendly spacing for mobile)

### Requirement: Note card shall support complete internationalization
The system SHALL display all user-visible text in the user's preferred language.

#### Scenario: Localized placeholder text
- **WHEN** displaying cards with empty title or content
- **THEN** placeholder text uses the current application language
- **AND** "无标题" displays as "No Title" in English locale
- **AND** "点击添加内容..." displays as "Click to add content..." in English locale

#### Scenario: Localized context menu items
- **WHEN** user opens context menu on note card
- **THEN** all menu items display in the current application language
- **AND** "编辑" displays as "Edit" in English locale
- **AND** "删除" displays as "Delete" in English locale
- **AND** "查看详情" displays as "View Details" in English locale
- **AND** "复制内容" displays as "Copy Content" in English locale
- **AND** "分享" displays as "Share" in English locale (mobile)

#### Scenario: Localized confirmation dialogs
- **WHEN** user initiates delete action for note card
- **THEN** confirmation dialog displays in the current application language
- **AND** success/error messages display in the correct language

#### Scenario: Localized time formatting
- **WHEN** displaying relative or absolute time
- **THEN** time format respects the current locale settings
- **AND** uses appropriate date/time separators for the locale
- **AND** respects 12/24 hour format preferences if available

