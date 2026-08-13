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

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_store.isDisposed) _store.dispose();
    if (!_sync.isDisposed) _sync.dispose();
  }
}
