import 'package:path_provider/path_provider.dart';

import '../src/rust/store.dart';
import 'frb_note_repository.dart';
import 'note_repository.dart';

/// Bridge between UI pages and the FRB Rust API.
///
/// Manages [SyncService] (CRDT) and [NoteStore] (SQLite read cache).
/// Tags are embedded inline in the content via `<!--tags:...-->`.
class BridgeHelper implements NoteRepository {
  static final BridgeHelper _instance = BridgeHelper._();
  factory BridgeHelper() => _instance;
  BridgeHelper._();

  FrbNoteRepository? _repository;

  FrbNoteRepository get _delegate =>
      _repository ?? (throw StateError('BridgeHelper not initialized'));

  /// Initialize FRB-backed services.
  ///
  /// Call once after [RustLib.init] in main.dart.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _repository?.close();
    _repository = await FrbNoteRepository.open(dataDirectory: dir.path);
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
  @override
  Future<void> createNote(String id, String content) async {
    await _delegate.createNote(id, content);
  }

  /// Read a note's full content by id. Returns `null` if not found.
  @override
  Future<String?> getNote(String id) async {
    return _delegate.getNote(id);
  }

  // ━━ Listing & searching (via SQLite cache) ━━

  /// List all notes ordered by `updated_at DESC`.
  @override
  Future<List<NoteRow>> listNotes() async {
    return _delegate.listNotes();
  }

  /// Full-text search across title, content, and tags.
  @override
  Future<List<NoteRow>> search(String query) async {
    return _delegate.search(query);
  }
}
