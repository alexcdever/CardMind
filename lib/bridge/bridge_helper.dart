import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../src/rust/api.dart' as api;
import '../src/rust/store.dart';
import '../src/rust/sync.dart';

/// Bridge between UI pages and the FRB Rust API.
///
/// Manages [SyncService] (CRDT) and [NoteStore] (SQLite read cache).
/// Tags are embedded inline in the content via `<!--tags:...-->`.
class BridgeHelper {
  static final BridgeHelper _instance = BridgeHelper._();
  factory BridgeHelper() => _instance;
  BridgeHelper._();

  SyncService? _sync;
  NoteStore? _store;

  SyncService get sync {
    if (_sync == null) throw StateError('BridgeHelper not initialized');
    return _sync!;
  }

  NoteStore get store {
    if (_store == null) throw StateError('BridgeHelper not initialized');
    return _store!;
  }

  /// Initialize FRB-backed services.
  ///
  /// Call once after [RustLib.init] in main.dart.
  Future<void> init() async {
    _sync = await api.createSyncService();

    // Store the SQLite database next to the app data directory
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'cardmind.db');
    _store = await api.createNoteStore(path: dbPath);
  }

  // ━━ Tag encoding helpers ━━

  /// Extract tags from content embedded as `<!--tags:tag1,tag2-->`.
  static List<String> parseTagsFromContent(String content) {
    final marker = '<!--tags:';
    final start = content.indexOf(marker);
    if (start < 0) return [];
    final after = content.substring(start + marker.length);
    final end = after.indexOf('-->');
    if (end < 0) return [];
    final tagsStr = after.substring(0, end).trim();
    if (tagsStr.isEmpty) return [];
    return tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Remove the `<!--tags:...-->` marker from content.
  static String removeTagsFromContent(String content) {
    final marker = '<!--tags:';
    final start = content.indexOf(marker);
    if (start < 0) return content;
    final after = content.substring(start + marker.length);
    final end = after.indexOf('-->');
    if (end < 0) return content;
    return content.replaceRange(start, start + marker.length + end + 3, '');
  }

  /// Prepend tags marker to content.
  static String encodeContentWithTags(String content, List<String> tags) {
    final clean = removeTagsFromContent(content);
    if (tags.isEmpty) return clean;
    return '<!--tags:${tags.join(',')}-->$clean';
  }

  // ━━ CRUD ━━

  /// Create or overwrite a note.
  ///
  /// [id] is a String. [content] may contain a `<!--tags:...-->` marker
  /// which the Rust [NoteStore] will parse out into the tags column.
  Future<void> createNote(String id, String content) async {
    await api.noteCreate(svc: sync, id: id, content: content);
    // Flush CRDT → SQLite so storeList / storeSearch see the change
    await api.syncNotesToStore(svc: sync, store: store);
  }

  /// Read a note's full content by id. Returns `null` if not found.
  Future<String?> getNote(String id) async {
    return api.noteGet(svc: sync, id: id);
  }

  // ━━ Listing & searching (via SQLite cache) ━━

  /// List all notes ordered by `updated_at DESC`.
  Future<List<NoteRow>> listNotes() async {
    await api.syncNotesToStore(svc: sync, store: store);
    return api.storeList(store: store);
  }

  /// Full-text search across title, content, and tags.
  Future<List<NoteRow>> search(String query) async {
    await api.syncNotesToStore(svc: sync, store: store);
    return api.storeSearch(store: store, query: query);
  }
}
