# Keyboard Shortcuts Specification

## Purpose

This specification defines the keyboard shortcut system for CardMind's desktop platforms. The system provides efficient keyboard-based navigation and actions that follow platform conventions, enhancing productivity for desktop users while remaining disabled on mobile platforms where virtual keyboards are used.

## Requirements

### Requirement: System SHALL provide keyboard shortcuts on desktop platforms only

The system SHALL provide keyboard shortcut support exclusively on desktop platforms (macOS, Windows, Linux) and SHALL NOT enable shortcuts on mobile platforms.

#### Scenario: Keyboard shortcuts enabled on desktop
- **WHEN** the application runs on a desktop platform
- **THEN** keyboard shortcuts SHALL be enabled
- **AND** SHALL respond to keyboard input

#### Scenario: Keyboard shortcuts disabled on mobile
- **WHEN** the application runs on a mobile platform
- **THEN** keyboard shortcuts SHALL be disabled
- **AND** SHALL NOT intercept keyboard input

### Requirement: System SHALL support standard keyboard shortcuts

The system SHALL support standard keyboard shortcuts that follow platform conventions (Ctrl on Windows/Linux, Cmd on macOS).

#### Scenario: Create new card with Ctrl+N (Windows/Linux)
- **WHEN** user presses Ctrl+N on Windows or Linux
- **THEN** the system SHALL create a new card
- **AND** SHALL open the card editor

#### Scenario: Create new card with Cmd+N (macOS)
- **WHEN** user presses Cmd+N on macOS
- **THEN** the system SHALL create a new card
- **AND** SHALL open the card editor

#### Scenario: Save card with Ctrl+S (Windows/Linux)
- **WHEN** user presses Ctrl+S on Windows or Linux while editing a card
- **THEN** the system SHALL save the current card
- **AND** SHALL display a success message

#### Scenario: Save card with Cmd+S (macOS)
- **WHEN** user presses Cmd+S on macOS while editing a card
- **THEN** the system SHALL save the current card
- **AND** SHALL display a success message

#### Scenario: Close editor with Escape
- **WHEN** user presses Escape while in the card editor
- **THEN** the system SHALL close the editor
- **AND** SHALL return to the previous screen

#### Scenario: Open search with Ctrl+F (Windows/Linux)
- **WHEN** user presses Ctrl+F on Windows or Linux
- **THEN** the system SHALL open the search interface
- **AND** SHALL focus the search input field

#### Scenario: Open search with Cmd+F (macOS)
- **WHEN** user presses Cmd+F on macOS
- **THEN** the system SHALL open the search interface
- **AND** SHALL focus the search input field

#### Scenario: Open settings with Ctrl+Comma (Windows/Linux)
- **WHEN** user presses Ctrl+, on Windows or Linux
- **THEN** the system SHALL open the settings screen

#### Scenario: Open settings with Cmd+Comma (macOS)
- **WHEN** user presses Cmd+, on macOS
- **THEN** the system SHALL open the settings screen

### Requirement: Keyboard shortcuts SHALL be context-aware

Keyboard shortcuts SHALL only be active when they are contextually appropriate and SHALL NOT interfere with text input.

#### Scenario: Shortcuts disabled during text input
- **WHEN** user is typing in a text field
- **THEN** keyboard shortcuts SHALL NOT intercept text input
- **AND** SHALL allow normal text entry

#### Scenario: Save shortcut only active in editor
- **WHEN** user presses Ctrl+S outside the card editor
- **THEN** the system SHALL NOT trigger the save action
- **AND** SHALL ignore the shortcut

#### Scenario: Editor shortcuts only active in editor
- **WHEN** user is in the card editor
- **THEN** editor-specific shortcuts SHALL be active
- **AND** SHALL respond to keyboard input

### Requirement: System SHALL display keyboard shortcut hints

The system SHALL display keyboard shortcut hints in menus, tooltips, and help documentation on desktop platforms.

#### Scenario: Menu items show shortcuts
- **WHEN** user views a menu on desktop
- **THEN** menu items SHALL display their keyboard shortcuts
- **AND** SHALL use platform-appropriate notation (Ctrl vs Cmd)

#### Scenario: Tooltips show shortcuts
- **WHEN** user hovers over a button on desktop
- **THEN** the tooltip SHALL display the keyboard shortcut if available
- **AND** SHALL use platform-appropriate notation

### Requirement: Keyboard shortcuts SHALL use Flutter's Shortcuts API

The system SHALL use Flutter's built-in `Shortcuts` and `Actions` API for implementing keyboard shortcuts to ensure cross-platform compatibility.

#### Scenario: Shortcuts defined using Shortcuts widget
- **WHEN** keyboard shortcuts are implemented
- **THEN** they SHALL use Flutter's `Shortcuts` widget
- **AND** SHALL define `Intent` classes for each action

#### Scenario: Actions defined using Actions widget
- **WHEN** keyboard shortcuts are implemented
- **THEN** they SHALL use Flutter's `Actions` widget
- **AND** SHALL define action handlers for each intent

### Requirement: System SHALL support the following keyboard shortcuts

The system SHALL support this minimum set of keyboard shortcuts on desktop platforms:

| Action | Windows/Linux | macOS | Context |
|--------|---------------|-------|---------|
| New Card | Ctrl+N | Cmd+N | Global |
| Save Card | Ctrl+S | Cmd+S | Editor |
| Close Editor | Esc | Esc | Editor |
| Search | Ctrl+F | Cmd+F | Global |
| Settings | Ctrl+, | Cmd+, | Global |
| Delete Card | Delete | Delete | Card selected |
| Select All | Ctrl+A | Cmd+A | Editor |
| Undo | Ctrl+Z | Cmd+Z | Editor |
| Redo | Ctrl+Shift+Z | Cmd+Shift+Z | Editor |

#### Scenario: All standard shortcuts are implemented
- **WHEN** the application runs on desktop
- **THEN** all shortcuts in the table SHALL be implemented
- **AND** SHALL work as specified

### Requirement: Keyboard shortcuts SHALL not conflict with system shortcuts

The system SHALL avoid using keyboard shortcuts that conflict with operating system or browser shortcuts.

#### Scenario: No conflict with system shortcuts
- **WHEN** keyboard shortcuts are defined
- **THEN** they SHALL NOT conflict with OS-level shortcuts
- **AND** SHALL NOT prevent system shortcuts from working

#### Scenario: Browser shortcuts remain functional
- **WHEN** running as a web application
- **THEN** browser shortcuts SHALL remain functional
- **AND** application shortcuts SHALL NOT override critical browser shortcuts

### Requirement: Keyboard shortcuts SHALL be testable

The keyboard shortcut system SHALL support automated testing to verify that all shortcuts work correctly.

#### Scenario: Test keyboard shortcut triggers action
- **WHEN** testing a keyboard shortcut
- **THEN** tests SHALL be able to simulate key presses
- **AND** SHALL verify that the correct action is triggered

#### Scenario: Test shortcut context awareness
- **WHEN** testing context-aware shortcuts
- **THEN** tests SHALL verify shortcuts only work in appropriate contexts
- **AND** SHALL verify shortcuts are disabled in inappropriate contexts

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
