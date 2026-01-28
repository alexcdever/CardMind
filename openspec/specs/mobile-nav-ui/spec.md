# mobile-nav-ui Specification

## Purpose
TBD - created by archiving change mobile-nav-ui-design. Update Purpose after archive.
## Requirements
### Requirement: MobileNav component shall render bottom navigation bar
The system SHALL provide a MobileNav component that renders a bottom navigation bar with three tabs: Notes, Devices, and Settings.

#### Scenario: Basic rendering
- **WHEN** MobileNav component is rendered with currentTab, notesCount, devicesCount, and onTabChange parameters
- **THEN** system shall display a navigation bar with three evenly spaced tab items
- **AND** each tab shall contain an icon and text label
- **AND** the navigation bar shall have a height of 64px plus SafeArea bottom padding

### Requirement: NavTabItem shall display tab content correctly
The system SHALL provide NavTabItem components that display icons, text, badges, and activation states according to specifications.

#### Scenario: Tab content display
- **WHEN** NavTabItem is rendered with tab parameter
- **THEN** Notes tab shall show notes icon and "笔记" text
- **AND** Devices tab shall show devices icon and "设备" text
- **AND** Settings tab shall show settings icon and "设置" text

#### Scenario: Activation state visual feedback
- **WHEN** NavTabItem isActive is true
- **THEN** icon and text color SHALL be theme color (#007AFF)
- **AND** top indicator SHALL be visible with 32px width, 3px height, and 1.5px border radius
- **WHEN** NavTabItem isActive is false
- **THEN** icon and text color SHALL be gray (#666666)
- **AND** top indicator SHALL be hidden

### Requirement: Badge notification system shall count and display items
The system SHALL provide badge functionality that displays item counts with proper formatting and positioning.

#### Scenario: Badge display logic
- **WHEN** badgeCount is null or 0
- **THEN** badge SHALL not be displayed
- **WHEN** badgeCount is between 1 and 99
- **THEN** badge SHALL display the exact number in a 16x16px circle
- **WHEN** badgeCount is greater than 99
- **THEN** badge SHALL display "99+" in a 28x16px rounded rectangle

#### Scenario: Badge styling and positioning
- **WHEN** badge is displayed
- **THEN** badge SHALL be positioned at top-right corner of icon
- **AND** background color SHALL be red (#FF3B30)
- **AND** text SHALL be white, 10px, bold font
- **AND** single-digit badges SHALL be 16x16px circles
- **AND** double-digit badges SHALL be 20x16px rounded rectangles with 8px radius
- **AND** "99+" badges SHALL be 28x16px rounded rectangles with 8px radius

### Requirement: Tab switching shall trigger callbacks with proper validation
The system SHALL handle tab switching interactions with callback triggers and input validation.

#### Scenario: Valid tab switching
- **WHEN** user taps on inactive tab
- **THEN** onTabChange callback SHALL be triggered with corresponding NavTab enum value
- **AND** visual feedback SHALL show new tab as active
- **AND** previous tab SHALL become inactive

#### Scenario: Invalid tab switching
- **WHEN** user taps on currently active tab
- **THEN** onTabChange callback SHALL NOT be triggered
- **AND** tab SHALL remain active without visual changes

#### Scenario: Rapid tap handling
- **WHEN** user taps multiple times rapidly on same tab
- **THEN** onTabChange callback SHALL be triggered only once
- **AND** subsequent taps SHALL be debounced and ignored

### Requirement: Animation system shall provide smooth transitions
The system SHALL implement animations for tab switching, touch feedback, and badge updates with specified durations.

#### Scenario: Tab switching animation
- **WHEN** user switches between tabs
- **THEN** icon SHALL perform scale animation (1.0 → 1.1 → 1.0) over 200ms
- **AND** top indicator SHALL fade in/out over 200ms
- **AND** color transitions SHALL animate over 200ms

#### Scenario: Touch feedback animation
- **WHEN** user presses down on tab
- **THEN** background SHALL change to light gray (#F0F0F0) over 100ms
- **AND** background SHALL return to original color when released over 100ms

#### Scenario: Badge update animation
- **WHEN** badge count changes from non-zero to non-zero
- **THEN** badge SHALL perform scale animation (1.0 → 1.2 → 1.0) over 200ms
- **WHEN** badge appears (from 0 to non-zero)
- **THEN** badge SHALL fade in with scale animation over 200ms
- **WHEN** badge disappears (from non-zero to 0)
- **THEN** badge SHALL fade out over 200ms

### Requirement: Layout adaptation shall handle different screen sizes
The system SHALL adapt layout for different screen dimensions and SafeArea configurations.

#### Scenario: SafeArea handling
- **WHEN** device has SafeArea.bottom = 0
- **THEN** navigation bar height SHALL be exactly 64px
- **WHEN** device has SafeArea.bottom > 0
- **THEN** navigation bar height SHALL be 64px + SafeArea.bottom
- **AND** content SHALL be positioned above the SafeArea

#### Scenario: Narrow screen adaptation
- **WHEN** screen width is less than 320px
- **THEN** tab items SHALL scale proportionally
- **AND** layout SHALL remain centered and evenly distributed

### Requirement: Accessibility support shall provide semantic labels
The system SHALL provide proper accessibility labels and touch targets for screen readers.

#### Scenario: Semantic labels
- **WHEN** screen reader encounters Notes tab with count > 0
- **THEN** semantic label SHALL be "笔记，当前有 {count} 条笔记"
- **WHEN** screen reader encounters Devices tab with count > 0
- **THEN** semantic label SHALL be "设备，当前有 {count} 台设备"
- **WHEN** screen reader encounters Settings tab
- **THEN** semantic label SHALL be "设置"

#### Scenario: Touch target compliance
- **WHEN** user interacts with any tab item
- **THEN** touch area SHALL be at least 48x48px
- **AND** entire tab width x 64px height SHALL be tappable

### Requirement: Data boundary handling shall prevent invalid states
The system SHALL handle edge cases and invalid data inputs gracefully.

#### Scenario: Negative count handling
- **WHEN** notesCount is negative
- **THEN** system SHALL treat it as 0 and not display badge
- **WHEN** devicesCount is negative
- **THEN** system SHALL treat it as 0 and not display badge

#### Scenario: Extremely large count handling
- **WHEN** notesCount exceeds 999
- **THEN** system SHALL display "99+" badge
- **WHEN** devicesCount exceeds 999
- **THEN** system SHALL display "99+" badge

### Requirement: Theme adaptation shall support light and dark modes
The system SHALL automatically adapt colors and visual styles based on current theme.

#### Scenario: Light mode theme
- **WHEN** app is in light mode
- **THEN** navigation bar background SHALL be white
- **AND** top border SHALL be 1px light gray separator

#### Scenario: Dark mode theme
- **WHEN** app is in dark mode
- **THEN** navigation bar background SHALL be dark theme color
- **AND** top border SHALL be 1px dark separator
- **AND** system SHALL use Theme.of(context) to get theme colors dynamically

