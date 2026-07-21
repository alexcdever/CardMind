import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeFrb);
  tearDownAll(disposeFrb);

  group('Journey 1: open an empty workspace', () {
    testWidgets('shows the empty state and new-note anchor', (tester) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await _pump(tester, repository);

      expect(find.text('还没有笔记'), findsOneWidget);
      expect(find.byTooltip(kNewNoteTooltip), findsOneWidget);
    });
  });

  group('Journey 2: create and reopen a note', () {
    testWidgets('persists a note through the real FRB repository', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await repository.createNote('journey-create', '# 通勤记录\n\n早上的想法。');
      await _pump(tester, repository);

      expect(find.text('通勤记录'), findsOneWidget);
      await tester.tap(find.text('通勤记录'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.byTooltip(kCloseEditorTooltip), findsOneWidget);
      expect(find.text('通勤记录'), findsWidgets);
    });
  });

  group('Journey 3: search notes', () {
    testWidgets('filters the list through SQLite full-text search', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await repository.createNote('journey-search-a', '# 周末采购\n牛奶');
      await repository.createNote('journey-search-b', '# 工作计划\n会议');
      await _pump(tester, repository);

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, '采购');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('周末采购'), findsOneWidget);
      expect(find.text('工作计划'), findsNothing);
    });
  });

  group('Journey 4: filter by tag', () {
    testWidgets('filters notes through the tagged Semantics anchor', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await repository.createNote('journey-tag-a', '<!--tags:工作--># 工作计划\n会议');
      await repository.createNote('journey-tag-b', '<!--tags:生活--># 周末采购\n牛奶');
      await _pump(tester, repository);

      final workTag = _findTagFilter('工作');
      expect(workTag, findsOneWidget);
      await tester.tap(workTag);
      await tester.pumpAndSettle();

      expect(find.text('工作计划'), findsOneWidget);
      expect(find.text('周末采购'), findsNothing);
    });
  });

  group('Journey 5: read an existing note', () {
    testWidgets('opens content and exposes save and close anchors', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await repository.createNote(
        'journey-read',
        '<!--tags:灵感--># 一闪而过的想法\n记录正文。',
      );
      await _pump(tester, repository);
      await tester.tap(find.text('一闪而过的想法'));
      await tester.pumpAndSettle();

      expect(find.byTooltip(kSaveTooltip), findsOneWidget);
      expect(find.byTooltip(kCloseEditorTooltip), findsOneWidget);
      expect(find.bySemanticsLabel('灵感', skipOffstage: false), findsOneWidget);
    });
  });

  group('Journey 6: use the desktop workspace', () {
    testWidgets('selects a note in the shared desktop repository', (
      tester,
    ) async {
      final harness = CardMindIntegrationHarness();
      final repository = await harness.openRepository();
      addTearDown(() => _disposeHarness(tester, harness));

      await repository.createNote('journey-desktop', '# 桌面续写\n\n从手机记录继续整理。');
      await _pump(tester, repository, const Size(1280, 800));

      expect(find.text('全部笔记'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('桌面续写').first);
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  FrbNoteRepository repository, [
  Size surfaceSize = const Size(390, 844),
]) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: NoteListPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeHarness(
  WidgetTester tester,
  CardMindIntegrationHarness harness,
) async {
  await tester.binding.setSurfaceSize(null);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await harness.dispose();
}

Finder _findTagFilter(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.label == label &&
        widget.properties.button == true,
    description: 'interactive tag Semantics labeled "$label"',
    skipOffstage: false,
  );
}
