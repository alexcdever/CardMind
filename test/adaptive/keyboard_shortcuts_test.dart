import 'package:cardmind/adaptive/keyboard_shortcuts.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyboardShortcuts', () {
    testWidgets('it_should_not_enable_shortcuts_on_mobile', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts on mobile
      bool createCardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCreateCard: () => createCardCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      // When: Pressing Ctrl+N on mobile
      if (PlatformDetector.isMobile) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Callback should not be called on mobile
        expect(createCardCalled, isFalse);
      }
    });

    testWidgets('it_should_enable_shortcuts_on_desktop', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts on desktop
      bool createCardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCreateCard: () => createCardCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      // When: Pressing Ctrl+N on desktop
      if (PlatformDetector.isDesktop) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Callback should be called on desktop
        expect(createCardCalled, isTrue);
      }
    });

    testWidgets('it_should_trigger_save_card_with_ctrl_s', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with save callback
      bool saveCardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onSaveCard: () => saveCardCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      // When: Pressing Ctrl+S on desktop
      if (PlatformDetector.isDesktop) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Save callback should be called
        expect(saveCardCalled, isTrue);
      }
    });

    testWidgets('it_should_trigger_close_editor_with_escape', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with close callback
      bool closeEditorCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCloseEditor: () => closeEditorCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      // When: Pressing Escape on desktop
      if (PlatformDetector.isDesktop) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Then: Close callback should be called
        expect(closeEditorCalled, isTrue);
      }
    });

    testWidgets('it_should_trigger_search_with_ctrl_f', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with search callback
      bool searchCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onSearch: () => searchCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      // When: Pressing Ctrl+F on desktop
      if (PlatformDetector.isDesktop) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Search callback should be called
        expect(searchCalled, isTrue);
      }
    });

    testWidgets('it_should_not_interfere_with_text_input', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with text field
      final controller = TextEditingController();
      bool createCardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCreateCard: () => createCardCalled = true,
            child: Scaffold(body: TextField(controller: controller)),
          ),
        ),
      );

      // When: Typing in text field
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // Then: Text should be entered normally
      expect(controller.text, equals('Hello'));
      // And shortcuts should not interfere
      expect(createCardCalled, isFalse);
    });

    testWidgets('it_should_support_multiple_shortcuts', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with multiple callbacks
      bool createCardCalled = false;
      bool saveCardCalled = false;
      bool closeEditorCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCreateCard: () => createCardCalled = true,
            onSaveCard: () => saveCardCalled = true,
            onCloseEditor: () => closeEditorCalled = true,
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      if (PlatformDetector.isDesktop) {
        // When: Pressing Ctrl+N
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Create card should be called
        expect(createCardCalled, isTrue);

        // When: Pressing Ctrl+S
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Save card should be called
        expect(saveCardCalled, isTrue);

        // When: Pressing Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Then: Close editor should be called
        expect(closeEditorCalled, isTrue);
      }
    });

    testWidgets('it_should_only_call_registered_callbacks', (
      WidgetTester tester,
    ) async {
      // Given: Keyboard shortcuts with only create card callback
      // ignore: unused_local_variable
      bool createCardCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardShortcuts(
            onCreateCard: () => createCardCalled = true,
            // No save card callback
            child: const Scaffold(body: Text('Test')),
          ),
        ),
      );

      if (PlatformDetector.isDesktop) {
        // When: Pressing Ctrl+S (no callback registered)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        // Then: Should not crash (no callback to call)
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Intent Classes', () {
    test('it_should_create_intent_instances', () {
      // Given: Intent classes
      // When: Creating instances
      const createCard = CreateCardIntent();
      const saveCard = SaveCardIntent();
      const closeEditor = CloseEditorIntent();
      const search = SearchIntent();
      const settings = SettingsIntent();
      const deleteCard = DeleteCardIntent();
      const selectAll = SelectAllIntent();
      const undo = UndoIntent();
      const redo = RedoIntent();

      // Then: All instances should be created
      expect(createCard, isA<Intent>());
      expect(saveCard, isA<Intent>());
      expect(closeEditor, isA<Intent>());
      expect(search, isA<Intent>());
      expect(settings, isA<Intent>());
      expect(deleteCard, isA<Intent>());
      expect(selectAll, isA<Intent>());
      expect(undo, isA<Intent>());
      expect(redo, isA<Intent>());
    });
  });
}
