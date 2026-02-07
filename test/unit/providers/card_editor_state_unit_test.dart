import 'package:cardmind/providers/card_editor_state.dart';
import 'package:cardmind/services/mock_card_api.dart';
import 'package:flutter_test/flutter_test.dart';

String _repeat(String char, int count) {
  return List.filled(count, char).join();
}

void main() {
  testWidgets('it_should_update_title_and_clear_error', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    expect(await state.manualSave(), isFalse);
    expect(state.errorMessage, isNotNull);

    state.updateTitle('Title');
    expect(state.title, 'Title');
    expect(state.errorMessage, isNull);
    state.dispose();
  });

  testWidgets('it_should_validate_title_rules', (tester) async {
    final state = CardEditorState(cardApi: MockCardApi());

    final emptyMessage = (state..updateTitle('')).validate();
    expect(emptyMessage, '标题不能为空');

    final tooLongMessage = (state..updateTitle(_repeat('a', 201))).validate();
    expect(tooLongMessage, '标题不能超过 200 字符');

    final validMessage = (state..updateTitle('Valid')).validate();
    expect(validMessage, isNull);
    state.dispose();
  });

  testWidgets('it_should_manual_save_create_and_update', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    final created =
        await (state
              ..updateTitle('Title')
              ..updateContent('Content'))
            .manualSave();
    expect(created, isTrue);
    expect(mockApi.createCardCallCount, 1);

    final updated = await (state..updateContent('Updated')).manualSave();
    expect(updated, isTrue);
    expect(mockApi.updateCardCallCount, 1);
    state.dispose();
  });

  testWidgets('it_should_auto_save_with_debounce', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    final editor = state
      ..updateTitle('Title')
      ..updateContent('Content');

    await tester.pump(const Duration(milliseconds: 600));

    expect(mockApi.createCardCallCount, 1);
    expect(editor.showSuccessIndicator, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(editor.showSuccessIndicator, isFalse);
    editor.dispose();
  });

  testWidgets('it_should_retry_save_after_error', (tester) async {
    final mockApi = MockCardApi()..shouldThrowError = true;
    final state = CardEditorState(cardApi: mockApi);

    final created = await (state..updateTitle('Title')).manualSave();
    expect(created, isFalse);
    expect(state.errorMessage, isNotNull);

    mockApi.shouldThrowError = false;
    await state.retrySave();

    expect(mockApi.createCardCallCount, 2);
    expect(state.errorMessage, isNull);
    state.dispose();
  });

  testWidgets('it_should_isTitleValid_reflects_title_state', (tester) async {
    final state = CardEditorState(cardApi: MockCardApi());

    expect(state.isTitleValid, isFalse);

    state.updateTitle('Valid');
    expect(state.isTitleValid, isTrue);
    state.dispose();
  });

  testWidgets('it_should_hasUnsavedChanges_reflects_updates', (tester) async {
    final state = CardEditorState(cardApi: MockCardApi());

    expect(state.hasUnsavedChanges, isFalse);

    state.updateContent('Content');
    expect(state.hasUnsavedChanges, isTrue);
    state.dispose();
  });

  testWidgets('it_should_clearError_resets_error_message', (tester) async {
    final state = CardEditorState(cardApi: MockCardApi());

    final saved = await state.manualSave();
    expect(saved, isFalse);
    expect(state.errorMessage, isNotNull);

    state.clearError();
    expect(state.errorMessage, isNull);
    state.dispose();
  });
}
