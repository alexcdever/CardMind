import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/main.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('new note and save slice', () {
    testWidgets('focuses a new editor and saves non-empty content', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(rows: [], contents: {});
      await _pumpEditor(tester, repository: repository);

      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editor.autoFocus, isTrue);

      await _replaceEditorMarkdown(tester, '# 第一篇笔记\n\n正文');
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents.values.single, '# 第一篇笔记\n\n正文');
      expect(find.text('已保存'), findsWidgets);
    });

    testWidgets('does not persist a blank note', (tester) async {
      final repository = MemoryNoteRepository(rows: [], contents: {});
      await _pumpEditor(tester, repository: repository);

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents, isEmpty);
      expect(find.text('空白笔记无需保存'), findsOneWidget);
    });
  });

  group('list and open slice', () {
    testWidgets('cleans title, marker and duplicate preview before opening', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        rows: const [
          NoteRow(
            id: 'clean-note',
            title: '<!--tags:Work--># Clean title',
            contentPreview: '<!--tags:Work--># Clean title\n\nVisible preview',
            tags: 'Work',
            updatedAt: '2026-07-22 05:00:00',
          ),
        ],
        contents: {
          'clean-note': '<!--tags:Work--># Clean title\n\nVisible preview',
        },
      );
      await _pumpList(tester, repository);

      expect(find.text('Clean title'), findsOneWidget);
      expect(find.text('Visible preview'), findsOneWidget);
      expect(find.textContaining('<!--tags:'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('note-clean-note')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-editor')), findsOneWidget);
      expect(find.text('Clean title'), findsOneWidget);
    });
  });

  group('editing and autosave slice', () {
    testWidgets('embedded editor autosaves the latest edit', (tester) async {
      final repository = MemoryNoteRepository(
        contents: {'existing': '# Before\n\nOld'},
      );
      await _pumpEditor(
        tester,
        repository: repository,
        noteId: 'existing',
        embedded: true,
      );

      await _replaceEditorMarkdown(tester, '# After\n\nNewest');
      await tester.pump(const Duration(milliseconds: 701));
      await tester.pumpAndSettle();

      expect(repository.contents['existing'], '# After\n\nNewest');
      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('save failure stays recoverable and a retry succeeds', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(rows: [], contents: {})
        ..saveError = StateError('disk');
      await _pumpEditor(tester, repository: repository);
      await _replaceEditorMarkdown(tester, '# Retry me');

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('保存失败'), findsOneWidget);

      repository.saveError = null;
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(repository.contents.values.single, '# Retry me');
    });
  });

  group('Markdown round-trip slice', () {
    testWidgets('keeps canonical Markdown through load and save', (
      tester,
    ) async {
      const canonical = '''# 标题

**粗体** 和 *斜体*

- 项目一
- 项目二

> 引用

```
final value = 1;
```''';
      final repository = MemoryNoteRepository(
        contents: {'markdown': canonical},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'markdown');

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(repository.contents['markdown'], canonical);
    });
  });

  group('tags slice', () {
    testWidgets('adds, trims, renames, deletes and cancels tag edits', (
      tester,
    ) async {
      final repository = MemoryNoteRepository(
        contents: {'tagged': '# Tagged\n\nBody'},
      );
      await _pumpEditor(tester, repository: repository, noteId: 'tagged');

      await _addTag(tester, '  Work  ');
      expect(find.text('Work'), findsOneWidget);
      await _addTag(tester, 'work');
      expect(find.text('Work'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('editor-tag-work')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-action-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-name-input')),
        'Focus',
      );
      await tester.tap(find.byKey(const ValueKey('tag-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Focus'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      // 标签走元数据 API：正文保持干净，标签写入 meta。
      expect(repository.contents['tagged'], '# Tagged\n\nBody');
      expect(repository.tagsById['tagged'], ['Focus']);

      await tester.tap(find.byKey(const ValueKey('editor-add-tag')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-name-input')),
        'Cancelled',
      );
      await tester.tap(find.byKey(const ValueKey('tag-dialog-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('editor-tag-focus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Focus'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();
      expect(repository.contents['tagged'], isNot(contains('<!--tags:')));
      expect(repository.tagsById['tagged'], isEmpty);
    });

    testWidgets('filters the list by tag without case sensitivity', (
      tester,
    ) async {
      final repository = MemoryNoteRepository();
      await _pumpList(tester, repository);

      await tester.tap(find.byKey(const ValueKey('tag-filter-work')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-life-note')), findsNothing);
    });
  });

  group('search slice', () {
    testWidgets('debounces, clears and shows no-result and error states', (
      tester,
    ) async {
      final repository = MemoryNoteRepository();
      await _pumpList(tester, repository);
      final search = find.byKey(const ValueKey('note-search-input'));

      await tester.enterText(search, 'life');
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byKey(const ValueKey('note-life-note')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);

      await tester.enterText(search, 'missing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('没有匹配结果'), findsOneWidget);

      repository.searchError = StateError('index unavailable');
      await tester.enterText(search, 'broken');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('搜索失败'), findsOneWidget);

      await tester.enterText(search, '   ');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);
    });

    testWidgets('ignores stale async search results', (tester) async {
      final repository = MemoryNoteRepository();
      final oldResult = Completer<List<NoteRow>>();
      final newestResult = Completer<List<NoteRow>>();
      repository.searchResults['old'] = oldResult;
      repository.searchResults['new'] = newestResult;
      await _pumpList(tester, repository);
      final search = find.byKey(const ValueKey('note-search-input'));

      await tester.enterText(search, 'old');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(search, 'new');
      await tester.pump(const Duration(milliseconds: 300));

      newestResult.complete([repository.rows.last]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);

      oldResult.complete([repository.rows.first]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-life-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-work-note')), findsNothing);
    });
  });

  testWidgets('CardMindApp injects the repository into its workspace', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(CardMindApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-work-note')), findsOneWidget);
  });
}

Future<void> _pumpList(
  WidgetTester tester,
  MemoryNoteRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: NoteListPage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required MemoryNoteRepository repository,
  String? noteId,
  bool embedded = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CardMindTheme.light,
      home: Scaffold(
        body: EditorPage(
          noteId: noteId,
          embedded: embedded,
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _replaceEditorMarkdown(
  WidgetTester tester,
  String markdown,
) async {
  final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
  final state = editor.editorState;
  final replacement = markdownToDocument(markdown);
  final transaction = state.transaction
    ..deleteNodes(List.of(state.document.root.children))
    ..insertNodes([0], replacement.root.children.reversed.toList());
  await state.apply(transaction);
  await tester.pump();
}

Future<void> _addTag(WidgetTester tester, String tag) async {
  await tester.tap(find.byKey(const ValueKey('editor-add-tag')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('tag-name-input')), tag);
  await tester.tap(find.byKey(const ValueKey('tag-dialog-confirm')));
  await tester.pumpAndSettle();
}

class MemoryNoteRepository implements NoteRepository {
  MemoryNoteRepository({List<NoteRow>? rows, Map<String, String>? contents})
    : rows = List.of(rows ?? _defaultRows),
      contents = Map<String, String>.of(contents ?? _defaultContents);

  static const _defaultRows = [
    NoteRow(
      id: 'work-note',
      title: 'Work note',
      contentPreview: 'Work body',
      tags: 'Work',
      updatedAt: '2026-07-22 05:00:00',
    ),
    NoteRow(
      id: 'life-note',
      title: 'Life note',
      contentPreview: 'Life body',
      tags: 'Life',
      updatedAt: '2026-07-21 05:00:00',
    ),
  ];

  static const _defaultContents = {
    'work-note': '<!--tags:Work--># Work note\n\nWork body',
    'life-note': '<!--tags:Life--># Life note\n\nLife body',
  };

  final List<NoteRow> rows;
  final Map<String, String> contents;

  /// 标签元数据记录（updateMetadata 写入）。
  final Map<String, List<String>> tagsById = {};

  /// 回收站里的笔记（deleteNote 移入，restore/purge 移出）。
  final List<NoteRow> trashed = [];

  /// 反链/出链注入数据。
  List<LinkRow> backlinks = [];
  List<LinkRow> outgoing = [];

  final Map<String, Completer<List<NoteRow>>> searchResults = {};
  Object? saveError;
  Object? searchError;
  int _generatedIdSeq = 0;

  @override
  Future<void> createNote(String id, String content) async {
    if (saveError case final error?) throw error;
    contents[id] = content;
  }

  @override
  Future<String> generateNoteId() async => 'generated-${++_generatedIdSeq}';

  @override
  Future<void> updateMetadata(String id, List<String> tags) async {
    tagsById[id] = List.of(tags);
  }

  @override
  Future<String?> getNote(String id) async => contents[id];

  @override
  Future<List<NoteRow>> listNotes() async => rows;

  @override
  Future<List<NoteRow>> search(String query) => _searchImpl(query);

  @override
  Future<List<NoteRow>> searchNotes(String query) => _searchImpl(query);

  Future<List<NoteRow>> _searchImpl(String query) async {
    if (searchError case final error?) throw error;
    final pending = searchResults[query];
    if (pending != null) return pending.future;
    final normalized = query.toLowerCase();
    return rows.where((note) {
      return note.title.toLowerCase().contains(normalized) ||
          note.contentPreview.toLowerCase().contains(normalized) ||
          note.tags.toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Future<List<LinkRow>> getBacklinks(String id) async => backlinks;

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async => outgoing;

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async {
    final normalized = prefix.toLowerCase();
    return rows
        .where((note) => note.title.toLowerCase().startsWith(normalized))
        .toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    final tagSet = <String>{};
    for (final note in rows) {
      tagSet.addAll(_splitTags(note.tags));
    }
    return tagSet.toList()..sort();
  }

  @override
  Future<List<NoteRow>> searchByTag(String tag) async {
    return rows
        .where(
          (note) => _splitTags(note.tags).any(
            (item) => item.toLowerCase() == tag.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final index = rows.indexWhere((note) => note.id == id);
    if (index >= 0) {
      final note = rows.removeAt(index);
      trashed.add(
        NoteRow(
          id: note.id,
          title: note.title,
          contentPreview: note.contentPreview,
          tags: note.tags,
          updatedAt: note.updatedAt,
          deletedAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }

  @override
  Future<void> restore(String id) async {
    final index = trashed.indexWhere((note) => note.id == id);
    if (index >= 0) rows.add(trashed.removeAt(index));
  }

  @override
  Future<void> purge(String id) async {
    trashed.removeWhere((note) => note.id == id);
  }

  @override
  Future<int> purgeExpired(DateTime cutoff) async {
    final before = trashed.length;
    trashed.removeWhere((note) {
      final deletedAt = note.deletedAt;
      if (deletedAt == null) return false;
      final time = DateTime.tryParse(deletedAt);
      return time != null && time.isBefore(cutoff);
    });
    return before - trashed.length;
  }

  @override
  Future<List<NoteRow>> trashList() async => List.of(trashed);

  // ━━ 配对（任务 G）— 测试 fake 不涉及配对，接口占位 ━━

  @override
  Future<String> deviceId() async => 'fake-device-id';

  @override
  Future<String> deviceName() async => 'Fake Device';

  @override
  Future<void> setDeviceName(String name) async {}

  @override
  Future<List<String>> localAddrs() async => [];

  @override
  Future<String> beginPairingAccept() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<String> beginPairingAcceptAndAdvertise() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<void> stopPairingAdvertising() async {}

  @override
  Future<List<PeerInfo>> discoverPeers() async => [];

  @override
  Future<PairingRequest> acceptPairingRequest() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(Duration timeout) =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<PairingResult> confirmPairing(String code, PairingRequest requester) =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<PairingResult> beginPairingConnect(String code, PairingTarget target) =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<ParsedPairingCredential> parsePairingCredential(String credential) =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<PairingResult> beginPairingConnectWithCredential(String credential) =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<void> acceptAndImportPush() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];

  @override
  Future<void> removePairedDevice(String peerId) async {}

  List<String> _splitTags(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}
