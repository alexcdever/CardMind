# Mobile UI Patterns Specification

## ADDED Requirements

### Requirement: All touch targets SHALL meet minimum size requirements

All interactive elements on mobile platforms SHALL have a minimum touch target size of 44x44 logical pixels to ensure comfortable touch interaction.

#### Scenario: Button meets minimum touch target size
- **WHEN** a button is displayed on mobile
- **THEN** its touch target SHALL be at least 44x44 logical pixels
- **AND** SHALL be easily tappable with a finger

#### Scenario: List item meets minimum touch target size
- **WHEN** a list item is displayed on mobile
- **THEN** its touch target height SHALL be at least 44 logical pixels
- **AND** SHALL be easily tappable

#### Scenario: Icon button meets minimum touch target size
- **WHEN** an icon button is displayed on mobile
- **THEN** its touch target SHALL be at least 44x44 logical pixels
- **AND** the icon MAY be smaller but the touch area SHALL meet the minimum

### Requirement: Mobile UI SHALL use bottom navigation

Mobile platforms SHALL use bottom navigation bar for primary navigation to ensure easy thumb access.

#### Scenario: Bottom navigation bar is displayed
- **WHEN** the app runs on mobile
- **THEN** a bottom navigation bar SHALL be displayed
- **AND** SHALL contain primary navigation items

#### Scenario: Bottom navigation items are accessible
- **WHEN** user taps a navigation item in the bottom bar
- **THEN** the app SHALL navigate to the corresponding section
- **AND** SHALL highlight the selected item

#### Scenario: Bottom navigation supports 3-5 items
- **WHEN** bottom navigation is displayed
- **THEN** it SHALL support between 3 and 5 navigation items
- **AND** SHALL display icons and labels for each item

### Requirement: Mobile UI SHALL use floating action button for primary actions

Mobile platforms SHALL use a floating action button (FAB) for the primary action on each screen.

#### Scenario: FAB for creating new card
- **WHEN** user is on the home screen on mobile
- **THEN** a FAB SHALL be displayed
- **AND** tapping it SHALL create a new card

#### Scenario: FAB is positioned for thumb access
- **WHEN** a FAB is displayed on mobile
- **THEN** it SHALL be positioned in the bottom-right corner
- **AND** SHALL be easily reachable with the thumb

### Requirement: Mobile UI SHALL use full-screen editors

Card editing on mobile platforms SHALL use full-screen editors to maximize content area and minimize distractions.

#### Scenario: Editor opens in full screen
- **WHEN** user opens a card for editing on mobile
- **THEN** the editor SHALL open in full screen
- **AND** SHALL use a new route/page

#### Scenario: Editor has back button
- **WHEN** the full-screen editor is displayed
- **THEN** it SHALL have a back button in the app bar
- **AND** tapping it SHALL close the editor and return to the previous screen

#### Scenario: Editor has save button in app bar
- **WHEN** the full-screen editor is displayed
- **THEN** it SHALL have a save button in the app bar
- **AND** tapping it SHALL save the card

### Requirement: Mobile UI SHALL support touch gestures

Mobile platforms SHALL support common touch gestures for efficient interaction.

#### Scenario: Swipe to delete card
- **WHEN** user swipes left on a card in the list
- **THEN** a delete action SHALL be revealed
- **AND** tapping delete SHALL remove the card

#### Scenario: Pull to refresh
- **WHEN** user pulls down on the card list
- **THEN** the list SHALL refresh
- **AND** SHALL display a loading indicator during refresh

#### Scenario: Long press for context menu
- **WHEN** user long-presses on a card
- **THEN** a context menu SHALL appear
- **AND** SHALL show available actions (edit, delete, share)

### Requirement: Mobile UI SHALL use appropriate spacing

Mobile UI SHALL use larger spacing between elements to accommodate touch interaction and improve readability.

#### Scenario: List items have adequate spacing
- **WHEN** cards are displayed in a list on mobile
- **THEN** there SHALL be at least 8 logical pixels of spacing between items
- **AND** SHALL provide visual separation

#### Scenario: Form fields have adequate spacing
- **WHEN** form fields are displayed on mobile
- **THEN** there SHALL be at least 16 logical pixels of spacing between fields
- **AND** SHALL prevent accidental taps on adjacent fields

### Requirement: Mobile UI SHALL use single-column layouts

Mobile platforms SHALL use single-column layouts to optimize for narrow screens.

#### Scenario: Card list uses single column
- **WHEN** cards are displayed on mobile
- **THEN** they SHALL be arranged in a single column
- **AND** SHALL span the full width of the screen

#### Scenario: Settings use single column
- **WHEN** settings are displayed on mobile
- **THEN** they SHALL be arranged in a single column
- **AND** SHALL be easy to scroll through

### Requirement: Mobile UI SHALL use modal dialogs sparingly

Mobile platforms SHALL use full-screen pages instead of modal dialogs for complex interactions.

#### Scenario: Simple confirmation uses dialog
- **WHEN** user needs to confirm a simple action
- **THEN** a modal dialog MAY be used
- **AND** SHALL have large, touch-friendly buttons

#### Scenario: Complex forms use full-screen page
- **WHEN** user needs to fill out a complex form
- **THEN** a full-screen page SHALL be used instead of a dialog
- **AND** SHALL provide better usability on small screens

### Requirement: Mobile UI SHALL optimize for one-handed use

Mobile UI SHALL be optimized for one-handed use with primary actions accessible in the lower half of the screen.

#### Scenario: Primary actions in thumb zone
- **WHEN** the app is displayed on mobile
- **THEN** primary actions SHALL be positioned in the lower half of the screen
- **AND** SHALL be reachable with the thumb

#### Scenario: Navigation in thumb zone
- **WHEN** bottom navigation is displayed
- **THEN** it SHALL be in the thumb zone
- **AND** SHALL be easily accessible with one hand

### Requirement: Mobile UI SHALL use appropriate typography

Mobile UI SHALL use larger font sizes and line heights for better readability on small screens.

#### Scenario: Body text is readable
- **WHEN** body text is displayed on mobile
- **THEN** the font size SHALL be at least 16 logical pixels
- **AND** SHALL have adequate line height for readability

#### Scenario: Headings are prominent
- **WHEN** headings are displayed on mobile
- **THEN** they SHALL be at least 20 logical pixels
- **AND** SHALL provide clear visual hierarchy

### Requirement: Mobile UI SHALL handle keyboard appearance

Mobile UI SHALL properly handle the appearance and disappearance of the on-screen keyboard.

#### Scenario: Content scrolls when keyboard appears
- **WHEN** user taps a text field and the keyboard appears
- **THEN** the content SHALL scroll to keep the text field visible
- **AND** SHALL not be obscured by the keyboard

#### Scenario: Layout adjusts for keyboard
- **WHEN** the keyboard is displayed
- **THEN** the layout SHALL adjust to accommodate it
- **AND** SHALL restore when the keyboard is dismissed
