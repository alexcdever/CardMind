import '../src/rust/store.dart';

/// 笔记仓库抽象：UI 层通过它访问 Rust 后端。
///
/// 所有实现（FRB / 测试 fake）都必须提供这些操作。
abstract interface class NoteRepository {
  Future<List<NoteRow>> listNotes();

  Future<List<NoteRow>> search(String query);

  Future<String?> getNote(String id);

  Future<void> createNote(String id, String content);

  /// 生成新笔记 ID（UUID v7）。
  Future<String> generateNoteId();

  /// 更新笔记元数据（meta tags）。
  Future<void> updateMetadata(String id, List<String> tags);

  /// 出链查询：当前笔记指向的所有链接。
  Future<List<LinkRow>> getOutgoingLinks(String id);

  /// 反链查询：指向当前笔记的所有链接。
  Future<List<LinkRow>> getBacklinks(String id);

  /// 全文搜索（FTS5；短查询由后端自动回退 LIKE）。
  Future<List<NoteRow>> searchNotes(String query);

  /// 链接自动补全：按标题前缀匹配，取最近更新的 20 条。
  Future<List<NoteRow>> autoCompleteLinks(String prefix);

  /// 全部标签（去重排序）。
  Future<List<String>> getAllTags();

  /// 按标签搜索。
  Future<List<NoteRow>> searchByTag(String tag);
}
