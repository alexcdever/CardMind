import 'dart:async';

import 'package:cardmind/src/rust/store.dart';

import 'note_repository_stub.dart';

/// 跨文件复用的内存版笔记仓储 fake：笔记、标签、回收站与反链全部驻留内存，
/// 供编辑页 / 列表页 / 回收站页的 widget 测试注入。
class MemoryNoteRepository extends NoteRepositoryStub {
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

  /// 挂起 createNote：把编辑页 `_saving` 钉在 true，便于断言保存态 UI。
  Completer<void>? createNoteGate;
  int _generatedIdSeq = 0;

  @override
  Future<void> createNote(String id, String content) async {
    await createNoteGate?.future;
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
          (note) => _splitTags(
            note.tags,
          ).any((item) => item.toLowerCase() == tag.toLowerCase()),
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

  @override
  Future<String> deviceId() async => 'fake-device-id';

  @override
  Future<String> deviceName() async => 'Fake Device';

  List<String> _splitTags(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}
