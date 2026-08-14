import 'package:path/path.dart' as p;

import '../src/rust/api.dart' as api;
import '../src/rust/store.dart';
import '../src/rust/sync.dart';
import 'note_repository.dart';

/// FRB-backed repository with an explicit, isolated data directory.
final class FrbNoteRepository implements NoteRepository {
  FrbNoteRepository._({required this._sync, required this._store});

  final SyncService _sync;
  final NoteStore _store;
  bool _closed = false;

  static Future<FrbNoteRepository> open({required String dataDirectory}) async {
    final sync = await api.createPersistentSyncService(path: dataDirectory);
    NoteStore? store;
    try {
      store = await api.createNoteStore(
        path: p.join(dataDirectory, 'cardmind.db'),
      );
      // 启动时清理回收站中删除超过 30 天的笔记（任务 E 验收：30 天自动清理）。
      // 删除状态在 Loro（meta.deleted_at），cutoff = now - 30d。
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      await api.purgeExpiredTrash(svc: sync, cutoff: cutoff);
      await api.syncNotesToStore(svc: sync, store: store);
      return FrbNoteRepository._(sync: sync, store: store);
    } catch (_) {
      if (store != null && !store.isDisposed) store.dispose();
      if (!sync.isDisposed) sync.dispose();
      rethrow;
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('FrbNoteRepository is closed');
  }

  @override
  Future<void> createNote(String id, String content) async {
    _ensureOpen();
    await api.noteCreate(svc: _sync, id: id, content: content);
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<String> generateNoteId() async {
    _ensureOpen();
    return api.generateNoteId();
  }

  @override
  Future<void> updateMetadata(String id, List<String> tags) async {
    _ensureOpen();
    await api.noteUpdateMetadata(svc: _sync, noteId: id, tags: tags);
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<String?> getNote(String id) async {
    _ensureOpen();
    return api.noteGet(svc: _sync, id: id);
  }

  @override
  Future<List<NoteRow>> listNotes() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeList(store: _store);
  }

  @override
  Future<List<NoteRow>> search(String query) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeSearch(store: _store, query: query);
  }

  @override
  Future<List<NoteRow>> searchNotes(String query) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.searchNotes(store: _store, query: query);
  }

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getOutgoingLinks(store: _store, noteId: id);
  }

  @override
  Future<List<LinkRow>> getBacklinks(String id) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getBacklinks(store: _store, noteId: id);
  }

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.autoCompleteLinks(store: _store, prefix: prefix);
  }

  @override
  Future<List<String>> getAllTags() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.getAllTags(store: _store);
  }

  @override
  Future<List<NoteRow>> searchByTag(String tag) async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.searchByTag(store: _store, tag: tag);
  }

  @override
  Future<void> softDelete(String id) async {
    _ensureOpen();
    await api.noteSoftDelete(svc: _sync, id: id);
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<void> restore(String id) async {
    _ensureOpen();
    await api.noteRestore(svc: _sync, id: id);
    // 恢复后重新同步 Loro 内容到投影（meta.deleted_at 清除 → 投影列清空）。
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<void> purge(String id) async {
    _ensureOpen();
    await api.notePurge(svc: _sync, id: id);
    // purge 后同步投影：墓碑 id 对应的投影行由 sync_notes_to_store 清理。
    await api.syncNotesToStore(svc: _sync, store: _store);
  }

  @override
  Future<int> purgeExpired(DateTime cutoff) async {
    _ensureOpen();
    final count = await api.purgeExpiredTrash(
      svc: _sync,
      cutoff: cutoff.toUtc().toIso8601String(),
    );
    await api.syncNotesToStore(svc: _sync, store: _store);
    return count.toInt();
  }

  @override
  Future<List<NoteRow>> trashList() async {
    _ensureOpen();
    await api.syncNotesToStore(svc: _sync, store: _store);
    return api.storeTrashList(store: _store);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_store.isDisposed) _store.dispose();
    if (!_sync.isDisposed) _sync.dispose();
  }
}
