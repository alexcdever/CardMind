import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v2/src/rust/api.dart' as api;
import 'package:v2/src/rust/frb_generated.dart';

void main() {
  late Directory tempDir;

  // FRB 只在首次测试前初始化一次
  setUpAll(() async {
    await RustLib.init();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cardmind_test_');
  });

  tearDown(() {
    // 清理临时 SQLite 文件
    for (final entity in tempDir.listSync(recursive: true)) {
      if (entity is File) {
        entity.deleteSync();
      }
    }
    tempDir.deleteSync(recursive: true);
  });

  group('CRUD operations', () {
    test('create and read note via FRB API', () async {
      final svc = await api.createSyncService();
      await api.noteCreate(svc: svc, id: 'test-1', content: '# Hello\n\nWorld');

      final content = await api.noteGet(svc: svc, id: 'test-1');
      expect(content, '# Hello\n\nWorld');
    });

    test('create multiple notes and read each', () async {
      final svc = await api.createSyncService();
      await api.noteCreate(svc: svc, id: 'a', content: 'Note A');
      await api.noteCreate(svc: svc, id: 'b', content: 'Note B');
      await api.noteCreate(svc: svc, id: 'c', content: 'Note C');

      expect(await api.noteGet(svc: svc, id: 'a'), 'Note A');
      expect(await api.noteGet(svc: svc, id: 'b'), 'Note B');
      expect(await api.noteGet(svc: svc, id: 'c'), 'Note C');
    });

    test('return null for non-existent note', () async {
      final svc = await api.createSyncService();

      final content = await api.noteGet(svc: svc, id: 'non-existent');
      expect(content, isNull);
    });
  });

  group('Export and Import', () {
    test('export and import all notes between services', () async {
      final svcA = await api.createSyncService();
      final svcB = await api.createSyncService();

      await api.noteCreate(svc: svcA, id: 'n1', content: 'Note 1');
      await api.noteCreate(svc: svcA, id: 'n2', content: 'Note 2');

      final data = await api.noteExportAll(svc: svcA);
      await api.noteImportAll(svc: svcB, data: data);

      expect(await api.noteGet(svc: svcB, id: 'n1'), 'Note 1');
      expect(await api.noteGet(svc: svcB, id: 'n2'), 'Note 2');
    });

    test('import does not affect original service', () async {
      final svcA = await api.createSyncService();
      final svcB = await api.createSyncService();

      await api.noteCreate(svc: svcA, id: 'x', content: 'Original');

      final data = await api.noteExportAll(svc: svcA);
      await api.noteImportAll(svc: svcB, data: data);

      // svcB should have the note now
      expect(await api.noteGet(svc: svcB, id: 'x'), 'Original');

      // Modify svcA - should not affect svcB
      await api.noteCreate(svc: svcA, id: 'y', content: 'New in A');
      expect(await api.noteGet(svc: svcB, id: 'x'), 'Original');
      expect(await api.noteGet(svc: svcB, id: 'y'), isNull);
    });
  });

  group('Store operations', () {
    test('store list and search', () async {
      final svc = await api.createSyncService();
      final dbPath = '${tempDir.path}/test.db';
      final store = await api.createNoteStore(path: dbPath);

      await api.noteCreate(svc: svc, id: 'a', content: '# Apple\n\nFruit');
      await api.noteCreate(svc: svc, id: 'b', content: '# Banana\n\nYellow');

      await api.syncNotesToStore(svc: svc, store: store);

      final rows = await api.storeList(store: store);
      expect(rows.length, 2);

      final results = await api.storeSearch(store: store, query: 'Apple');
      expect(results.length, 1);
      expect(results.first.id, 'a');
    });

    test('store search across multiple fields', () async {
      final svc = await api.createSyncService();
      final dbPath = '${tempDir.path}/search.db';
      final store = await api.createNoteStore(path: dbPath);

      await api.noteCreate(
        svc: svc,
        id: 'note1',
        content: '<!--tags:fruit-->Apple is red',
      );
      await api.noteCreate(
        svc: svc,
        id: 'note2',
        content: '<!--tags:color-->Banana is yellow',
      );
      await api.noteCreate(
        svc: svc,
        id: 'note3',
        content: 'Cherry is also red',
      );

      await api.syncNotesToStore(svc: svc, store: store);

      final redResults = await api.storeSearch(store: store, query: 'red');
      expect(redResults.length, 2);

      final fruitResults = await api.storeSearch(store: store, query: 'fruit');
      expect(fruitResults.length, 1);
      expect(fruitResults.first.id, 'note1');
    });

    test('empty store list returns empty', () async {
      final svc = await api.createSyncService();
      final dbPath = '${tempDir.path}/empty.db';
      final store = await api.createNoteStore(path: dbPath);

      await api.syncNotesToStore(svc: svc, store: store);

      final rows = await api.storeList(store: store);
      expect(rows, isEmpty);
    });
  });
}
