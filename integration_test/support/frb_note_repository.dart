import 'dart:io';

import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/src/rust/api.dart' as api;
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:path/path.dart' as p;

/// A real FRB-backed repository with an isolated SQLite projection.
///
/// This adapter intentionally lives in integration tests until production
/// startup accepts an injected [NoteRepository] and database location.
class FrbNoteRepository implements NoteRepository {
  FrbNoteRepository._(this.directory, this._sync, this._store);

  final Directory directory;
  final SyncService _sync;
  final NoteStore _store;
  bool _disposed = false;

  static Future<FrbNoteRepository> create() async {
    final root = await Directory.systemTemp.createTemp(
      'cardmind_integration_',
    );
    SyncService? sync;
    try {
      sync = await api.createSyncService();
      final store = await api.createNoteStore(
        path: p.join(root.path, 'cardmind.db'),
      );
      return FrbNoteRepository._(root, sync, store);
    } catch (_) {
      sync?.dispose();
      await root.delete(recursive: true);
      rethrow;
    }
  }

  @override
  Future<void> createNote(String id, String content) async {
    _ensureOpen();
    await api.noteCreate(svc: _sync, id: id, content: content);
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _store.dispose();
    _sync.dispose();
    await directory.delete(recursive: true);
  }

  void _ensureOpen() {
    if (_disposed) {
      throw StateError('FrbNoteRepository has already been disposed');
    }
  }
}
