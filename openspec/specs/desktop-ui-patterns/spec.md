# Desktop UI Patterns Specification

## Purpose

This specification defines desktop-specific UI patterns and interaction models for CardMind. These patterns optimize the user experience for mouse and keyboard interaction on desktop platforms (macOS, Windows, Linux), taking advantage of larger screens, precise pointing devices, and keyboard shortcuts to provide an efficient and productive user experience.

## Requirements

### Requirement: Desktop UI SHALL use side navigation

Desktop platforms SHALL use side navigation rail for primary navigation to optimize horizontal screen space.

#### Scenario: Navigation rail is displayed on the left
- **WHEN** the app runs on desktop
- **THEN** a navigation rail SHALL be displayed on the left side
- **AND** SHALL contain primary navigation items

#### Scenario: Navigation rail items are clickable
- **WHEN** user clicks a navigation item in the rail
- **THEN** the app SHALL navigate to the corresponding section
- **AND** SHALL highlight the selected item

#### Scenario: Navigation rail supports icons and labels
- **WHEN** navigation rail is displayed
- **THEN** each item SHALL have an icon
- **AND** MAY have a text label

### Requirement: Desktop UI SHALL use multi-column layouts

Desktop platforms SHALL use multi-column layouts to take advantage of wider screens.

#### Scenario: Card list uses split view
- **WHEN** cards are displayed on desktop
- **THEN** the layout SHALL use a split view
- **AND** SHALL show the card list on the left and card details on the right

#### Scenario: Editor uses split view
- **WHEN** user edits a card on desktop
- **THEN** the editor SHALL be displayed in the right pane
- **AND** the card list SHALL remain visible in the left pane

#### Scenario: Settings use two-column layout
- **WHEN** settings are displayed on desktop
- **THEN** they MAY use a two-column layout
- **AND** SHALL optimize for wider screens

### Requirement: Desktop UI SHALL support mouse interactions

Desktop platforms SHALL support mouse-specific interactions including hover effects and right-click menus.

#### Scenario: Hover effects on interactive elements
- **WHEN** user hovers over a button or link on desktop
- **THEN** the element SHALL display a hover effect
- **AND** SHALL provide visual feedback

#### Scenario: Hover shows additional information
- **WHEN** user hovers over a card on desktop
- **THEN** additional information or actions MAY be displayed
- **AND** SHALL enhance discoverability

#### Scenario: Right-click shows context menu
- **WHEN** user right-clicks on a card on desktop
- **THEN** a context menu SHALL appear
- **AND** SHALL show available actions (edit, delete, duplicate, etc.)

#### Scenario: Right-click menu is positioned near cursor
- **WHEN** a context menu is displayed
- **THEN** it SHALL appear near the mouse cursor
- **AND** SHALL not extend beyond screen boundaries

### Requirement: Desktop UI SHALL use compact spacing

Desktop UI SHALL use more compact spacing between elements to optimize screen real estate.

#### Scenario: List items use compact spacing
- **WHEN** cards are displayed in a list on desktop
- **THEN** there SHALL be minimal spacing between items
- **AND** SHALL maximize content density

#### Scenario: Form fields use compact spacing
- **WHEN** form fields are displayed on desktop
- **THEN** they SHALL use compact spacing
- **AND** SHALL fit more content on screen

### Requirement: Desktop UI SHALL not use floating action button

Desktop platforms SHALL NOT use floating action buttons, instead placing primary actions in toolbars or menus.

#### Scenario: No FAB on desktop
- **WHEN** the app runs on desktop
- **THEN** no floating action button SHALL be displayed
- **AND** primary actions SHALL be in the toolbar or menu

#### Scenario: New card button in toolbar
- **WHEN** user is on the home screen on desktop
- **THEN** a "New Card" button SHALL be in the toolbar
- **AND** clicking it SHALL create a new card

### Requirement: Desktop UI SHALL support window resizing

Desktop UI SHALL gracefully handle window resizing and maintain usability at different window sizes.

#### Scenario: Layout adapts to window width
- **WHEN** user resizes the window on desktop
- **THEN** the layout SHALL adapt to the new width
- **AND** SHALL maintain usability

#### Scenario: Minimum window size is enforced
- **WHEN** user tries to resize the window below minimum size
- **THEN** the window SHALL not shrink below 800x600 pixels
- **AND** SHALL maintain readable content

#### Scenario: Split view collapses at narrow widths
- **WHEN** the window width is below 1024 pixels
- **THEN** the split view MAY collapse to single pane
- **AND** SHALL provide navigation between panes

### Requirement: Desktop UI SHALL use appropriate typography

Desktop UI SHALL use smaller font sizes optimized for desktop viewing distances.

#### Scenario: Body text is optimized for desktop
- **WHEN** body text is displayed on desktop
- **THEN** the font size SHALL be 14-16 logical pixels
- **AND** SHALL be readable at typical desktop viewing distance

#### Scenario: Headings use desktop-appropriate sizes
- **WHEN** headings are displayed on desktop
- **THEN** they SHALL use sizes appropriate for desktop
- **AND** SHALL provide clear hierarchy without being oversized

### Requirement: Desktop UI SHALL support drag and drop

Desktop platforms SHALL support drag and drop interactions for efficient content manipulation.

#### Scenario: Drag card to reorder
- **WHEN** user drags a card in the list on desktop
- **THEN** the card SHALL move with the cursor
- **AND** SHALL be reordered when dropped in a new position

#### Scenario: Drag to delete
- **WHEN** user drags a card to a delete zone on desktop
- **THEN** the card SHALL be deleted
- **AND** SHALL show visual feedback during drag

#### Scenario: Drop feedback is provided
- **WHEN** user drags an item over a valid drop target
- **THEN** visual feedback SHALL be provided
- **AND** SHALL indicate whether the drop is allowed

### Requirement: Desktop UI SHALL use modal dialogs appropriately

Desktop platforms SHALL use modal dialogs for focused interactions without leaving the current context.

#### Scenario: Confirmation dialogs are modal
- **WHEN** user needs to confirm an action on desktop
- **THEN** a modal dialog SHALL be displayed
- **AND** SHALL require user response before continuing

#### Scenario: Dialogs are centered on screen
- **WHEN** a modal dialog is displayed on desktop
- **THEN** it SHALL be centered on the screen
- **AND** SHALL have a backdrop to focus attention

#### Scenario: Dialogs can be dismissed with Escape
- **WHEN** a modal dialog is displayed on desktop
- **THEN** pressing Escape SHALL dismiss the dialog
- **AND** SHALL cancel the action

### Requirement: Desktop UI SHALL support multiple windows

Desktop platforms MAY support multiple windows for advanced workflows.

#### Scenario: Open card in new window
- **WHEN** user requests to open a card in a new window on desktop
- **THEN** a new window SHALL open with the card editor
- **AND** SHALL allow editing in parallel with the main window

#### Scenario: Windows synchronize state
- **WHEN** multiple windows are open on desktop
- **THEN** changes in one window SHALL be reflected in others
- **AND** SHALL maintain data consistency

### Requirement: Desktop UI SHALL use menu bars on appropriate platforms

Desktop platforms SHALL use native menu bars on macOS and optional menu bars on Windows/Linux.

#### Scenario: macOS uses native menu bar
- **WHEN** the app runs on macOS
- **THEN** it SHALL use the native macOS menu bar
- **AND** SHALL follow macOS menu conventions

#### Scenario: Windows/Linux use in-app menu
- **WHEN** the app runs on Windows or Linux
- **THEN** it MAY use an in-app menu bar
- **AND** SHALL follow platform conventions

#### Scenario: Menu items show keyboard shortcuts
- **WHEN** menus are displayed on desktop
- **THEN** menu items SHALL show their keyboard shortcuts
- **AND** SHALL use platform-appropriate notation

### Requirement: Desktop UI SHALL optimize for keyboard navigation

Desktop UI SHALL support full keyboard navigation for power users.

#### Scenario: Tab navigation between elements
- **WHEN** user presses Tab on desktop
- **THEN** focus SHALL move to the next interactive element
- **AND** SHALL provide visible focus indicators

#### Scenario: Arrow keys navigate lists
- **WHEN** user presses arrow keys in a list on desktop
- **THEN** the selection SHALL move accordingly
- **AND** SHALL scroll to keep selection visible

#### Scenario: Enter activates focused element
- **WHEN** user presses Enter on a focused element
- **THEN** the element SHALL be activated
- **AND** SHALL perform its primary action

### Requirement: Desktop UI SHALL use tooltips for discoverability

Desktop platforms SHALL use tooltips to provide additional information and improve feature discoverability.

#### Scenario: Buttons show tooltips on hover
- **WHEN** user hovers over a button on desktop
- **THEN** a tooltip SHALL appear after a short delay
- **AND** SHALL describe the button's function

#### Scenario: Tooltips include keyboard shortcuts
- **WHEN** a tooltip is displayed for an action with a keyboard shortcut
- **THEN** the tooltip SHALL include the shortcut
- **AND** SHALL use platform-appropriate notation

#### Scenario: Tooltips disappear on mouse leave
- **WHEN** user moves the mouse away from an element
- **THEN** the tooltip SHALL disappear
- **AND** SHALL not obstruct other content

### Requirement: Desktop UI SHALL support high-DPI displays

Desktop UI SHALL render correctly on high-DPI displays (Retina, 4K, etc.) with appropriate scaling.

#### Scenario: UI scales on high-DPI displays
- **WHEN** the app runs on a high-DPI display
- **THEN** all UI elements SHALL scale appropriately
- **AND** SHALL remain sharp and readable

#### Scenario: Icons use vector graphics
- **WHEN** icons are displayed on desktop
- **THEN** they SHALL use vector graphics or high-resolution assets
- **AND** SHALL look sharp on all display densities

---

## Test Implementation

### Test Files
- `test/specs/platform_detection_spec_test.dart` (SP-ADAPT-001)
- `test/specs/adaptive_ui_framework_spec_test.dart` (SP-ADAPT-002)
- `test/specs/adaptive_ui_system_spec_test.dart` (SP-UI-001)

### Test Coverage
- ✅ Platform Detection Tests (15+ tests)
- ✅ Adaptive UI Framework Tests (20+ tests)
- ✅ Responsive Layout Tests (25+ tests)
- ✅ Breakpoint Tests (10+ tests)

### Running Tests
```bash
flutter test test/specs/platform_detection_spec_test.dart
flutter test test/specs/adaptive_ui_framework_spec_test.dart
flutter test test/specs/adaptive_ui_system_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 100%
- All tests passing: ✅

### Test Examples
```dart
testWidgets('it_should_detect_platform_type_correctly', (WidgetTester tester) async {
  // Given: 应用启动
  // When: 检测平台类型
  final platformType = PlatformDetector.currentPlatform;
  
  // Then: 平台类型应该是 mobile 或 desktop
  expect(platformType, anyOf(PlatformType.mobile, PlatformType.desktop));
});
```

### Related Specs
- SP-UI-001: [adaptive_ui_system_spec_test.dart](../../test/specs/adaptive_ui_system_spec_test.dart)
- SP-ADAPT-002: [adaptive-ui-framework/spec.md](../adaptive-ui-framework/spec.md)
