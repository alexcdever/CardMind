# note-card-interaction Specification

## Purpose
TBD - created by archiving change note-card-ui-design. Update Purpose after archive.
## Requirements
### Requirement: Note card shall support click to edit
The system SHALL allow users to open the editor when clicking on a note card.

#### Scenario: Desktop click to edit
- **WHEN** user clicks on a note card on desktop platform
- **THEN** the system opens a modal dialog with the card editor
- **AND** the dialog displays full title and content for editing

#### Scenario: Mobile click to edit
- **WHEN** user clicks on a note card on mobile platform
- **THEN** the system opens a full-screen editor
- **AND** the editor displays full title and content for editing

### Requirement: Note card shall support context menu
The system SHALL provide context menu operations for note cards.

#### Scenario: Desktop right-click context menu
- **WHEN** user right-clicks on a note card on desktop platform
- **THEN** the system shows a context menu at cursor position
- **AND** the menu contains options: Edit, Delete, View Details, Copy Content

#### Scenario: Desktop keyboard trigger context menu
- **WHEN** user presses Menu key or Shift+F10 while a note card is focused
- **THEN** the system shows a context menu near the focused card
- **AND** the menu contains options: Edit, Delete, View Details, Copy Content
- **AND** the menu position auto-adjusts to stay within screen bounds

#### Scenario: Mobile long-press context menu
- **WHEN** user long-presses on a note card for 500ms on mobile platform
- **THEN** the system shows a bottom sheet menu
- **AND** the menu contains options: Edit, Delete, Share, Copy Content
- **AND** the system provides haptic feedback if supported

#### Scenario: Context menu edit action
- **WHEN** user selects "Edit" from context menu
- **THEN** the system opens the appropriate editor for the platform

#### Scenario: Context menu delete action
- **WHEN** user selects "Delete" from context menu
- **THEN** the system shows a confirmation dialog
- **AND** upon confirmation, the card is deleted

### Requirement: Note card shall support keyboard navigation
The system SHALL provide keyboard navigation for accessibility.

#### Scenario: Tab focus navigation
- **WHEN** user presses Tab key
- **THEN** focus moves to the next note card
- **AND** focused card shows visible focus indicator

#### Scenario: Enter key to edit
- **WHEN** user presses Enter key while a note card is focused
- **THEN** the system opens the editor for that card

#### Scenario: Arrow key navigation
- **WHEN** user presses arrow keys while a note card is focused
- **THEN** focus moves to the adjacent card in the arrow direction

### Requirement: Note card shall support desktop hover effects
The system SHALL provide visual feedback on desktop hover.

#### Scenario: Mouse hover effect
- **WHEN** user hovers mouse over a note card on desktop platform
- **THEN** the card displays subtle shadow and border highlight
- **AND** the cursor changes to pointer

#### Scenario: Hover stop effect
- **WHEN** user moves mouse away from note card
- **THEN** the hover effects are removed
- **AND** the card returns to normal appearance

### Requirement: Note card shall support mobile swipe gestures
The system SHALL support swipe gestures for common actions.

#### Scenario: Swipe to delete (optional)
- **WHEN** user swipes left on a note card on mobile platform
- **THEN** the system shows delete confirmation
- **AND** upon confirmation, the card is deleted

#### Scenario: Swipe to share (optional)
- **WHEN** user swipes right on a note card on mobile platform
- **THEN** the system opens the native share dialog

### Requirement: Note card shall support ESC key to close editors
The system SHALL allow users to close editors using ESC key on desktop platform.

#### Scenario: ESC key closes desktop edit dialog
- **WHEN** user presses ESC key while desktop edit dialog is open
- **THEN** the system closes the edit dialog without saving changes
- **AND** the focus returns to the parent note card

#### Scenario: ESC key cancels pending changes
- **WHEN** user has unsaved changes in edit dialog and presses ESC key
- **THEN** the system shows confirmation dialog asking to save or discard changes
- **AND** the edit dialog closes only after user confirms action

#### Scenario: ESC key closes context menu
- **WHEN** user presses ESC key while context menu is open
- **THEN** the system closes the context menu
- **AND** the focus returns to the parent note card

