# time-formatting Specification

## Purpose
TBD - created by archiving change note-card-ui-design. Update Purpose after archive.
## Requirements
### Requirement: System shall format relative time for recent updates
The system SHALL display relative time for updates within the last 24 hours.

#### Scenario: Display "刚刚" for very recent updates
- **WHEN** a note card was updated 0-10 seconds ago
- **THEN** the system displays "刚刚" (Just now) as the update time

#### Scenario: Display "X秒前" for updates within a minute
- **WHEN** a note card was updated 11-59 seconds ago
- **THEN** the system displays "{seconds}秒前" (X seconds ago) with the actual seconds count

#### Scenario: Display "X分钟前" for updates within an hour
- **WHEN** a note card was updated 1-59 minutes ago
- **THEN** the system displays "{minutes}分钟前" (X minutes ago) with the actual minutes count

#### Scenario: Display "X小时前" for updates within 24 hours
- **WHEN** a note card was updated 1-23 hours ago
- **THEN** the system displays "{hours}小时前" (X hours ago) with the actual hours count

### Requirement: System shall format absolute time for older updates
The system SHALL display absolute time for updates older than 24 hours.

#### Scenario: Display current year date format
- **WHEN** a note card was updated in the current year but more than 24 hours ago
- **THEN** the system displays "MM-DD HH:mm" format (e.g., "01-25 14:30")

#### Scenario: Display previous year date format
- **WHEN** a note card was updated in a previous year
- **THEN** the system displays "YYYY-MM-DD HH:mm" format (e.g., "2025-12-25 09:15")

### Requirement: System shall handle edge cases for time formatting
The system SHALL handle invalid or edge case timestamps gracefully.

#### Scenario: Handle future timestamps
- **WHEN** a note card has an updated timestamp in the future (clock skew)
- **THEN** the system displays "刚刚" (Just now)

#### Scenario: Handle very old timestamps
- **WHEN** a note card has an updated timestamp before 1970-01-01
- **THEN** the system displays "未知时间" (Unknown time)

#### Scenario: Handle invalid timestamps
- **WHEN** a note card has an invalid or unparseable timestamp
- **THEN** the system displays "未知时间" (Unknown time)

#### Scenario: Handle null timestamps
- **WHEN** a note card has a null updated_at field
- **THEN** the system displays "未知时间" (Unknown time)

### Requirement: System shall update relative time automatically
The system SHALL periodically update relative time displays.

#### Scenario: Auto-update relative time
- **WHEN** the app is running and cards show relative time
- **THEN** the system updates the relative time display every 60 seconds
- **AND** only visible cards are updated for performance

### Requirement: System shall handle time zones correctly
The system SHALL handle time zone conversions properly.

#### Scenario: UTC storage with local display
- **WHEN** timestamps are stored in UTC format
- **THEN** the system converts to user's local timezone for display
- **AND** the conversion respects daylight saving time

#### Scenario: Cross-timezone consistency
- **WHEN** cards are synced across different timezones
- **THEN** the relative time displays consistently for all users
- **AND** absolute times show in each user's local timezone

### Requirement: Time formatting shall meet performance benchmarks
The system SHALL format and display time information within specified performance limits.

#### Scenario: Time formatting performance for single card
- **WHEN** formatting time for a single note card
- **THEN** the formatting operation completes within 1ms
- **AND** cached formatting results are reused within 60 seconds

#### Scenario: Batch time formatting for card list
- **WHEN** formatting time for 100 visible note cards
- **THEN** all formatting operations complete within 10ms
- **AND** formatting does not block UI thread

#### Scenario: Auto-update performance impact
- **WHEN** relative time auto-update runs every 60 seconds
- **THEN** update processing for visible cards completes within 5ms
- **AND** no UI stuttering or frame drops occur during update

#### Scenario: Time formatting memory usage
- **WHEN** formatting time for 1000 note cards
- **THEN** memory usage for time formatting cache remains under 1MB
- **AND** cache efficiently evicts old entries to prevent memory leaks

