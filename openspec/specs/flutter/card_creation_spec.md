# Card Creation Interaction Specification

## 📋 规格编号: SP-FLUT-009
**版本**: 1.0.0
**状态**: 已实现
**依赖**: SP-FLUT-008 (主页交互规格), SP-CARD-004 (CardStore 规格)

---

## ADDED Requirements

### Requirement: User can initiate card creation from home screen
The system SHALL provide a floating action button (FAB) on the home screen that allows users to initiate card creation.

#### Scenario: FAB button is visible on home screen
- **WHEN** user is on the home screen
- **THEN** system displays a FAB button at the bottom-right corner

#### Scenario: Tapping FAB navigates to card editor
- **WHEN** user taps the FAB button
- **THEN** system navigates to the card editor screen

#### Scenario: FAB is accessible within 1 second
- **WHEN** home screen loads
- **THEN** FAB button becomes interactive within 1 second

---

### Requirement: User can input card title and content
The system SHALL provide input fields for card title and content with Markdown support.

#### Scenario: Title input field is available
- **WHEN** user enters card editor screen
- **THEN** system displays a title input field with focus

#### Scenario: Content input field is available
- **WHEN** user enters card editor screen
- **THEN** system displays a content input field below the title

#### Scenario: Title input accepts text
- **WHEN** user types in the title field
- **THEN** system captures the input text

#### Scenario: Content input accepts Markdown
- **WHEN** user types Markdown syntax in the content field
- **THEN** system captures the Markdown text

#### Scenario: Empty title shows placeholder
- **WHEN** title field is empty
- **THEN** system displays placeholder text "卡片标题"

#### Scenario: Empty content shows placeholder
- **WHEN** content field is empty
- **THEN** system displays placeholder text "输入内容（支持 Markdown）"

---

### Requirement: System auto-saves card after input
The system SHALL automatically save the card 500ms after the user stops typing.

#### Scenario: Auto-save triggers after 500ms of inactivity
- **WHEN** user stops typing for 500ms
- **THEN** system calls the save API

#### Scenario: Auto-save debounces rapid typing
- **WHEN** user types continuously
- **THEN** system does NOT call save API until 500ms after last keystroke

#### Scenario: Auto-save shows saving indicator
- **WHEN** auto-save is in progress
- **THEN** system displays "自动保存中..." indicator

#### Scenario: Auto-save shows success indicator
- **WHEN** auto-save completes successfully
- **THEN** system displays "已保存" indicator for 2 seconds

#### Scenario: Auto-save persists to Rust API
- **WHEN** auto-save triggers
- **THEN** system calls `CardApi.createCard(title, content)`

---

### Requirement: User can manually complete card creation
The system SHALL provide a "完成" button that allows users to manually save and exit.

#### Scenario: Complete button is visible
- **WHEN** user is in card editor
- **THEN** system displays a "完成" button in the app bar

#### Scenario: Tapping complete saves and exits
- **WHEN** user taps "完成" button
- **THEN** system saves the card and navigates back to home screen

#### Scenario: Complete button is disabled when title is empty
- **WHEN** title field is empty
- **THEN** "完成" button is disabled

#### Scenario: Complete button is enabled when title is not empty
- **WHEN** title field has text
- **THEN** "完成" button is enabled

---

### Requirement: System validates card input
The system SHALL validate card input before saving.

#### Scenario: Empty title prevents save
- **WHEN** user attempts to save with empty title
- **THEN** system displays error "标题不能为空"

#### Scenario: Title with only whitespace is invalid
- **WHEN** user attempts to save with whitespace-only title
- **THEN** system displays error "标题不能为空"

#### Scenario: Empty content is allowed
- **WHEN** user saves with empty content
- **THEN** system saves the card successfully

#### Scenario: Title exceeds 200 characters
- **WHEN** user inputs title longer than 200 characters
- **THEN** system displays error "标题不能超过 200 字符"

---

### Requirement: System handles save errors gracefully
The system SHALL display clear error messages when save fails and allow retry.

#### Scenario: Network error shows error message
- **WHEN** save fails due to network error
- **THEN** system displays SnackBar with "保存失败，请检查网络连接"

#### Scenario: API error shows error message
- **WHEN** save fails due to API error
- **THEN** system displays SnackBar with error details

#### Scenario: Error message includes retry button
- **WHEN** save fails
- **THEN** SnackBar includes a "重试" button

#### Scenario: Retry button triggers save again
- **WHEN** user taps "重试" button
- **THEN** system attempts to save the card again

#### Scenario: Editor state is preserved on error
- **WHEN** save fails
- **THEN** user's input (title and content) remains in the editor

---

### Requirement: System updates home screen after card creation
The system SHALL update the home screen card list after successful card creation.

#### Scenario: New card appears at top of list
- **WHEN** user completes card creation
- **THEN** new card appears at the top of the home screen list

#### Scenario: Card list refreshes automatically
- **WHEN** user returns to home screen after creating card
- **THEN** system refreshes the card list without manual action

#### Scenario: Card displays correct title and preview
- **WHEN** new card appears in list
- **THEN** card shows the entered title and content preview

---

### Requirement: System meets performance constraints
The system SHALL complete the card creation flow within 30 seconds.

#### Scenario: Card creation completes within 30 seconds
- **WHEN** user creates a card from start to finish
- **THEN** entire flow (open editor → input → save → return) completes within 30 seconds

#### Scenario: Save API responds within 2 seconds
- **WHEN** system calls `CardApi.createCard()`
- **THEN** API responds within 2 seconds

#### Scenario: Navigation transitions are smooth
- **WHEN** system navigates between screens
- **THEN** transitions complete within 300ms

---

### Requirement: User can cancel card creation
The system SHALL allow users to cancel card creation and discard changes.

#### Scenario: Back button is available
- **WHEN** user is in card editor
- **THEN** system displays a back button in the app bar

#### Scenario: Tapping back shows confirmation dialog
- **WHEN** user taps back button with unsaved changes
- **THEN** system displays confirmation dialog "放弃更改？"

#### Scenario: Confirming discard returns to home screen
- **WHEN** user confirms discard in dialog
- **THEN** system navigates back to home screen without saving

#### Scenario: Canceling discard keeps editor open
- **WHEN** user cancels discard in dialog
- **THEN** system keeps the card editor open with content preserved

#### Scenario: Back with no changes returns immediately
- **WHEN** user taps back button with no input
- **THEN** system returns to home screen without confirmation dialog

---

## MODIFIED Requirements

### Requirement: Home screen displays FAB for card creation
**Modified from**: SP-FLUT-008 - Home screen displays card list

The home screen SHALL display a floating action button (FAB) at the bottom-right corner that initiates card creation.

**Changes**:
- ADDED: FAB button for card creation
- ADDED: FAB click handler that navigates to card editor

#### Scenario: FAB is visible on home screen
- **WHEN** user is on the home screen
- **THEN** FAB button is visible at bottom-right corner

#### Scenario: FAB has correct icon
- **WHEN** FAB is displayed
- **THEN** FAB shows a "+" (add) icon

#### Scenario: FAB has correct color
- **WHEN** FAB is displayed
- **THEN** FAB uses primary color from theme

#### Scenario: Tapping FAB navigates to card editor
- **WHEN** user taps FAB
- **THEN** system navigates to `/create-card` route

---

## Test Coverage

### Unit Tests
- `it_should_display_fab_button_on_home_screen()`
- `it_should_navigate_to_editor_when_fab_tapped()`
- `it_should_focus_title_field_on_editor_load()`
- `it_should_trigger_autosave_after_500ms_inactivity()`
- `it_should_debounce_autosave_during_rapid_typing()`
- `it_should_validate_empty_title()`
- `it_should_validate_title_length()`
- `it_should_allow_empty_content()`
- `it_should_disable_complete_button_when_title_empty()`
- `it_should_enable_complete_button_when_title_not_empty()`

### Widget Tests
- `it_should_render_card_editor_screen()`
- `it_should_show_title_and_content_fields()`
- `it_should_show_complete_button_in_appbar()`
- `it_should_show_back_button_in_appbar()`
- `it_should_show_saving_indicator_during_save()`
- `it_should_show_success_indicator_after_save()`
- `it_should_show_error_snackbar_on_save_failure()`
- `it_should_show_discard_confirmation_dialog()`

### Integration Tests
- `it_should_complete_card_creation_flow_within_30_seconds()`
- `it_should_save_card_to_rust_api()`
- `it_should_update_home_screen_after_creation()`
- `it_should_preserve_editor_state_on_error()`
- `it_should_retry_save_after_failure()`

---

## Implementation Notes

### State Management
- Use `Provider` with `ChangeNotifier` for `CardEditorState`
- State includes: `title`, `content`, `isSaving`, `errorMessage`, `lastSaved`

### Debounce Implementation
```dart
Timer? _debounceTimer;

void onTextChanged(String text) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 500), () {
    _autoSave();
  });
}
```

### Navigation
- Route name: `/create-card`
- Return value: `Card?` (null if cancelled)

### API Integration
```dart
final card = await api.createCard(
  title: title.trim(),
  content: content,
);
```

---

## Acceptance Criteria

- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] All integration tests pass
- [ ] Performance test passes (< 30 seconds)
- [ ] Code review approved
- [ ] Documentation updated
- [ ] Spec Coding checklist complete

---

**最后更新**: 2026-01-16
**作者**: CardMind Team

---

## Test Implementation

### Test File
`test/specs/card_creation_spec_test.dart`

### Test Coverage
- ✅ FAB Button Tests (3 tests)
- ✅ Input Field Tests (6 tests)
- ✅ Auto-save Tests (5 tests)
- ✅ Validation Tests (4 tests)
- ✅ Error Handling Tests (5 tests)
- ✅ Navigation Tests (6 tests)
- ✅ Performance Tests (1 test)

### Running Tests
```bash
flutter test test/specs/card_creation_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 30/30 (100%)
- Test cases: 30
- All tests passing: ✅

### Test Examples
```dart
testWidgets('it_should_display_fab_button_on_home_screen', (WidgetTester tester) async {
  // Given: 用户在主页
  await tester.pumpWidget(createTestWidget(HomeScreen()));
  
  // When: 主页加载完成
  await tester.pumpAndSettle();
  
  // Then: FAB 按钮显示在右下角
  expect(find.byType(FloatingActionButton), findsOneWidget);
});
```

### Related Specs
- SP-FLUT-008: [home_screen_spec.md](./home_screen_spec.md)
- SP-UI-004: [fullscreen_editor_spec_test.dart](../../test/specs/fullscreen_editor_spec_test.dart)
