import 'package:path_provider/path_provider.dart';

import '../src/rust/store.dart';
import 'frb_note_repository.dart';
import 'note_repository.dart';

/// Bridge between UI pages and the FRB Rust API.
///
/// Manages [SyncService] (CRDT) and [NoteStore] (SQLite read cache).
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
    final dir = await getApplicationSupportDirectory();
    _repository?.close();
    _repository = await FrbNoteRepository.open(dataDirectory: dir.path);
  }

  // ━━ Tag encoding helpers（v1 兼容；新数据走 meta tags API）━━

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

  /// Prepend tags marker to content. 仅供旧数据兼容测试使用；
  /// 新数据应调用 [updateMetadata] 写入 meta tags。
  static String encodeContentWithTags(String content, List<String> tags) {
    final clean = removeTagsFromContent(content);
    if (tags.isEmpty) return clean;
    return '<!--tags:${tags.join(',')}-->$clean';
  }

  // ━━ CRUD ━━

  /// Create or overwrite a note.
  ///
  /// [content] 应是不含 tags marker 的干净正文；标签走 [updateMetadata]。
  @override
  Future<void> createNote(String id, String content) async {
    await _delegate.createNote(id, content);
  }

  /// 生成新笔记 ID（UUID v7）。
  @override
  Future<String> generateNoteId() async {
    return _delegate.generateNoteId();
  }

  /// 更新笔记元数据（meta tags）。
  @override
  Future<void> updateMetadata(String id, List<String> tags) async {
    await _delegate.updateMetadata(id, tags);
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

  /// LIKE 搜索（保留，部分场景回退用）。
  @override
  Future<List<NoteRow>> search(String query) async {
    return _delegate.search(query);
  }

  /// 全文搜索（FTS5；短查询自动回退 LIKE）。
  @override
  Future<List<NoteRow>> searchNotes(String query) async {
    return _delegate.searchNotes(query);
  }

  // ━━ 链接（outgoing / backlinks）━━

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) async {
    return _delegate.getOutgoingLinks(id);
  }

  @override
  Future<List<LinkRow>> getBacklinks(String id) async {
    return _delegate.getBacklinks(id);
  }

  // ━━ 链接自动补全 / 标签 ━━

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) async {
    return _delegate.autoCompleteLinks(prefix);
  }

  @override
  Future<List<String>> getAllTags() async {
    return _delegate.getAllTags();
  }

  @override
  Future<List<NoteRow>> searchByTag(String tag) async {
    return _delegate.searchByTag(tag);
  }
}
