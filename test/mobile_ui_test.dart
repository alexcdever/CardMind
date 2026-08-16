import 'dart:async';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/main.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:cardmind/ui/design_system/cardmind_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup failure is visible and retryable', (tester) async {
    final attempts = <Completer<void>>[];
    Future<void> initialize() {
      final attempt = Completer<void>();
      attempts.add(attempt);
      return attempt.future;
    }

    await tester.pumpWidget(CardMindBootstrap(initialize: initialize));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(attempts, hasLength(1));

    attempts.single.completeError(StateError('backend unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(attempts, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    attempts.last.completeError(StateError('backend still unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('启动失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile controls meet the 48dp touch target', (tester) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardMindIconButton(
                icon: Icons.save_outlined,
                tooltip: '保存',
                onPressed: () {},
              ),
              SizedBox(
                width: 320,
                child: CardMindSearchField(
                  controller: searchController,
                  onChanged: (_) {},
                  onClear: searchController.clear,
                  mobile: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(IconButton)).height,
      CardMindLayout.mobileTouchTarget,
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
    );
  });

  testWidgets('mobile editor fits a small screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              size: const Size(375, 812),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          );
        },
        home: const Scaffold(body: EditorPage(embedded: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('保存'), findsOneWidget);
    expect(find.byType(EditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile editor exposes a recoverable load error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: const Scaffold(
          body: EditorPage(noteId: 'missing-note', embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法打开笔记'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile list renders and searches repository notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryNoteRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('通勤时想到的产品改进方向'), findsOneWidget);
    expect(find.text('工作'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.enterText(find.byType(TextField), '周末');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('周末采购清单'), findsOneWidget);
    expect(find.text('通勤时想到的产品改进方向'), findsNothing);
    expect(repository.lastSearchQuery, '周末');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop and mobile share the same note repository seam', (
    tester,
  ) async {
    final repository = _MemoryNoteRepository();

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部笔记'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('通勤时想到的产品改进方向'), findsWidgets);
    expect(repository.requestedNoteIds, contains('commute-note'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile note opens the full-screen editor through the seam', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryNoteRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('通勤时想到的产品改进方向'));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.byTooltip('关闭编辑器'), findsOneWidget);
    expect(repository.requestedNoteIds, contains('commute-note'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile shell remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CardMindApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('新建笔记'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryNoteRepository implements NoteRepository {
  final notes = const [
    NoteRow(
      id: 'commute-note',
      title: '通勤时想到的产品改进方向',
      contentPreview: '减少打开应用后的操作，让记录动作更快。',
      tags: '工作,灵感',
      updatedAt: '2026-07-21 08:30:00',
    ),
    NoteRow(
      id: 'weekend-note',
      title: '周末采购清单',
      contentPreview: '咖啡豆、牛奶和水果。',
      tags: '生活',
      updatedAt: '2026-07-20 18:20:00',
    ),
  ];

  final requestedNoteIds = <String>[];
  String? lastSearchQuery;

  @override
  Future<void> createNote(String id, String content) async {}

  @override
  Future<String> generateNoteId() async => 'generated-note';

  @override
  Future<void> updateMetadata(String id, List<String> tags) async {}

  @override
  Future<String?> getNote(String id) async {
    requestedNoteIds.add(id);
    return switch (id) {
      'commute-note' => '# 通勤时想到的产品改进方向\n\n减少打开应用后的操作。',
      'weekend-note' => '# 周末采购清单\n\n咖啡豆、牛奶和水果。',
      _ => null,
    };
  }

  @override
  Future<List<NoteRow>> listNotes() async => notes;

  @override
  Future<List<NoteRow>> search(String query) async {
    lastSearchQuery = query;
    return notes.where((note) {
      return note.title.contains(query) ||
          note.contentPreview.contains(query) ||
          note.tags.contains(query);
    }).toList();
  }

  @override
  Future<List<NoteRow>> searchNotes(String query) => search(query);

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async => [];

  @override
  Future<List<LinkRow>> getBacklinks(String id) async => [];

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async => [];

  @override
  Future<List<String>> getAllTags() async => [];

  @override
  Future<List<NoteRow>> searchByTag(String tag) async => [];

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> purge(String id) async {}

  @override
  Future<int> purgeExpired(DateTime cutoff) async => 0;

  @override
  Future<List<NoteRow>> trashList() async => [];

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
  Future<void> acceptAndImportPush() =>
      throw UnimplementedError('pairing not supported by memory fake');

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() async => [];

  @override
  Future<void> removePairedDevice(String peerId) async {}
}
