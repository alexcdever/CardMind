import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bridge/bridge_helper.dart';
import '../bridge/note_repository.dart';
import '../src/rust/store.dart';
import '../ui/design_system/cardmind_theme.dart';
import '../ui/design_system/cardmind_widgets.dart';
import 'editor_page.dart';
import 'trash_page.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key, this.repository});

  final NoteRepository? repository;

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  List<NoteRow> _notes = [];
  bool _loading = true;
  String? _selectedTag;
  String? _selectedNoteId;
  bool _creatingNote = false;
  int _mobileTabIndex = 0;
  int _draftRevision = 0;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<NoteRow> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  int _searchGeneration = 0;

  NoteRepository get _repository => widget.repository ?? BridgeHelper();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (mounted) setState(() => _loading = true);
    try {
      final notes = await _repository.listNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
        final selectedStillExists = notes.any(
          (note) => note.id == _selectedNoteId,
        );
        if (!selectedStillExists && !_creatingNote) {
          _selectedNoteId = notes.isEmpty ? null : notes.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载失败: $error')));
    }
  }

  /// 把 `[[id|alias]]` 渲染为显示文本（alias 缺省用 id）。
  static String _renderLinkSyntax(String text) {
    return text.replaceAllMapped(
      RegExp(r'\[\[([^\]|]+)(?:\|([^\]]*))?\]\]'),
      (match) {
        final target = match.group(1) ?? '';
        final alias = match.group(2);
        return (alias == null || alias.isEmpty) ? target : alias;
      },
    );
  }

  String _preview(NoteRow note) {
    var preview = _renderLinkSyntax(
      BridgeHelper.removeTagsFromContent(note.contentPreview).trim(),
    );
    final title = _displayTitle(note);
    final lines = preview.split('\n');
    if (lines.isNotEmpty) {
      final first = lines.first.trim().replaceFirst(RegExp(r'^#+\s*'), '');
      if (first == title) preview = lines.skip(1).join('\n').trim();
    }
    if (preview.isEmpty) return '';
    if (preview.length <= 80) return preview;
    return '${preview.substring(0, 80)}…';
  }

  String _displayTitle(NoteRow note) {
    var title = BridgeHelper.removeTagsFromContent(note.title).trim();
    title = title.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    return title.isEmpty ? '无标题' : title;
  }

  String _formatDate(String updatedAt) {
    try {
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(updatedAt);
      return DateFormat('M月d日').format(date);
    } catch (_) {
      try {
        return DateFormat('M月d日').format(DateTime.parse(updatedAt));
      } catch (_) {
        return updatedAt;
      }
    }
  }

  List<String> _parseTags(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  List<String> _getAllTags() {
    final tagSet = <String>{};
    for (final note in _notes) {
      tagSet.addAll(_parseTags(note.tags));
    }
    return tagSet.toList()..sort();
  }

  List<NoteRow> get _filteredNotes {
    if (_selectedTag == null) return _notes;
    return _notes.where((note) {
      final tags = _parseTags(note.tags);
      return tags.any(
        (tag) => tag.toLowerCase() == _selectedTag!.toLowerCase(),
      );
    }).toList();
  }

  List<NoteRow> get _displayedNotes =>
      _isSearching ? _searchResults : _filteredNotes;

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final normalized = query.trim();
    _searchGeneration++;
    if (normalized.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });
    final generation = _searchGeneration;
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(normalized, generation),
    );
  }

  Future<void> _performSearch(String query, int generation) async {
    try {
      // FTS5 全文搜索（短查询由后端自动回退 LIKE，前端无感）。
      final results = await _repository.searchNotes(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _searchError = null;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = [];
        _searchError = '搜索失败：$error';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _startDesktopDraft() {
    setState(() {
      _creatingNote = true;
      _selectedNoteId = null;
      _draftRevision++;
    });
  }

  Future<void> _openMobileEditor({String? noteId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            EditorPage(noteId: noteId, repository: _repository),
      ),
    );
    await _loadNotes();
  }

  /// 打开回收站页；返回后刷新列表（恢复的笔记重新可见）。
  Future<void> _openTrash() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TrashPage(repository: _repository),
      ),
    );
    await _loadNotes();
  }

  /// 软删除笔记（进回收站）。成功返回 true。
  Future<bool> _deleteNote(NoteRow note) async {
    try {
      await _repository.softDelete(note.id);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $error')));
      }
      return false;
    }
  }

  /// 桌面端右键菜单删除。
  Future<void> _deleteViaContextMenu(
    BuildContext context,
    NoteRow note,
    TapDownDetails details,
  ) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        0,
        0,
      ),
      items: const [
        PopupMenuItem(
          key: ValueKey('note-delete-menu'),
          value: 'delete',
          child: Text('删除（进回收站）'),
        ),
      ],
    );
    if (action == 'delete' && mounted) {
      final ok = await _deleteNote(note);
      if (ok && mounted) await _loadNotes();
    }
  }

  Future<void> _handleEmbeddedSave(String noteId) async {
    setState(() {
      _creatingNote = false;
      _selectedNoteId = noteId;
    });
    await _loadNotes();
  }

  /// 反链跳转：切换桌面三栏的选中笔记。
  void _handleNoteOpened(String noteId) {
    setState(() {
      _creatingNote = false;
      _selectedNoteId = noteId;
    });
  }

  Widget _buildTagFilterBar({
    EdgeInsets padding = EdgeInsets.zero,
    bool comfortable = false,
  }) {
    final allTags = _getAllTags();
    if (allTags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final tag in allTags) ...[
            CardMindTag(
              key: ValueKey('tag-filter-${tag.toLowerCase()}'),
              label: tag,
              selected: _selectedTag == tag,
              comfortable: comfortable,
              onTap: () {
                setState(() {
                  _selectedTag = _selectedTag == tag ? null : tag;
                });
              },
            ),
            const SizedBox(width: CardMindSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteItem(
    NoteRow note, {
    required bool selected,
    required VoidCallback onTap,
    GestureTapDownCallback? onSecondaryTapDown,
  }) {
    final tokens = context.cardMind;
    final preview = _preview(note);
    final tags = _parseTags(note.tags);
    final comfortable =
        MediaQuery.sizeOf(context).width < CardMindLayout.desktopBreakpoint;

    return Semantics(
      container: true,
      identifier: 'note-${note.id}',
      label: '笔记：${_displayTitle(note)}',
      child: Material(
        color: selected ? tokens.surfaceLow : tokens.surfaceRaised,
        child: InkWell(
          key: ValueKey('note-${note.id}'),
          onTap: onTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Container(
            constraints: BoxConstraints(minHeight: comfortable ? 112 : 96),
            padding: EdgeInsets.fromLTRB(
              comfortable ? 16 : 14,
              comfortable ? 16 : 14,
              comfortable ? 16 : 12,
              comfortable ? 16 : 14,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? tokens.accent : Colors.transparent,
                  width: 2,
                ),
                bottom: BorderSide(color: tokens.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _displayTitle(note),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: comfortable ? 16 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: CardMindSpacing.sm),
                    Text(
                      _formatDate(note.updatedAt),
                      style: TextStyle(
                        color: tokens.mutedInk,
                        fontSize: comfortable ? 12 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: CardMindSpacing.xs),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.mutedInk,
                      fontSize: comfortable ? 14 : 13,
                      height: comfortable ? 21 / 14 : 18 / 13,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: CardMindSpacing.sm),
                  Wrap(
                    spacing: CardMindSpacing.xs,
                    runSpacing: CardMindSpacing.xs,
                    children: [
                      for (final tag in tags.take(3))
                        CardMindTag(label: tag, comfortable: comfortable),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListBody({required bool desktop}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notes.isEmpty && !_isSearching) {
      return const CardMindEmptyState(
        icon: Icons.note_add_outlined,
        title: '还没有笔记',
        message: '创建第一篇笔记，内容会保存在这台设备上。',
      );
    }
    if (_searchError != null) {
      return CardMindEmptyState(
        key: const ValueKey('search-error'),
        icon: Icons.error_outline,
        title: '搜索失败',
        message: _searchError!,
      );
    }
    if (_displayedNotes.isEmpty) {
      return CardMindEmptyState(
        icon: Icons.search_off,
        title: '没有匹配结果',
        message: _isSearching ? '试试更短的关键词。' : '当前标签下没有笔记。',
      );
    }

    return ListView.builder(
      itemCount: _displayedNotes.length,
      itemBuilder: (context, index) {
        final note = _displayedNotes[index];
        final item = _buildNoteItem(
          note,
          selected: desktop && note.id == _selectedNoteId,
          onTap: () {
            if (desktop) {
              setState(() {
                _creatingNote = false;
                _selectedNoteId = note.id;
              });
            } else {
              _openMobileEditor(noteId: note.id);
            }
          },
          onSecondaryTapDown: desktop
              ? (details) => _deleteViaContextMenu(context, note, details)
              : null,
        );
        if (!desktop) {
          return _buildDismissible(note, item);
        }
        return item;
      },
    );
  }

  /// 移动端左滑删除（进回收站）。
  Widget _buildDismissible(NoteRow note, Widget child) {
    final tokens = context.cardMind;
    return Dismissible(
      key: ValueKey('dismiss-${note.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: tokens.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _deleteNote(note),
      onDismissed: (_) {
        // Dismissible 要求数据源同步移除；随后后台刷新真实状态。
        setState(() {
          _notes.removeWhere((n) => n.id == note.id);
          if (_selectedNoteId == note.id) _selectedNoteId = null;
        });
        unawaited(_loadNotes());
      },
      child: child,
    );
  }

  Widget _buildMobileListBody() {
    final isEmptyState =
        _loading ||
        (_notes.isEmpty && !_isSearching) ||
        _displayedNotes.isEmpty;
    if (isEmptyState) {
      return SingleChildScrollView(child: _buildListBody(desktop: false));
    }
    return _buildListBody(desktop: false);
  }

  Widget _buildSidebar() {
    final tokens = context.cardMind;
    return Container(
      width: CardMindLayout.sidebarWidth,
      color: tokens.surfaceLow,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(CardMindRadii.md),
                ),
                child: const Icon(
                  Icons.auto_stories_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: CardMindSpacing.md),
              const Expanded(
                child: Text(
                  'CardMind',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: CardMindSpacing.xl),
          CardMindPrimaryButton(
            key: const ValueKey('new-note'),
            label: '新建笔记',
            icon: Icons.add,
            expanded: true,
            onPressed: _startDesktopDraft,
          ),
          const SizedBox(height: CardMindSpacing.xl),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.08),
              border: Border(left: BorderSide(color: tokens.accent, width: 2)),
            ),
            child: Row(
              children: [
                Icon(Icons.notes, size: 19, color: tokens.accent),
                const SizedBox(width: CardMindSpacing.md),
                Text(
                  '笔记',
                  style: TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_notes.length}',
                  style: TextStyle(color: tokens.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextButton.icon(
              key: const ValueKey('trash-entry'),
              onPressed: _openTrash,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('回收站'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: CardMindSyncStatus(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopListPane() {
    final tokens = context.cardMind;
    return Container(
      width: CardMindLayout.listWidth,
      color: tokens.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isSearching ? '搜索结果' : '全部笔记',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${_displayedNotes.length}',
                      style: TextStyle(color: tokens.mutedInk, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: CardMindSpacing.lg),
                CardMindSearchField(
                  key: const ValueKey('note-search'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                if (!_isSearching && _getAllTags().isNotEmpty) ...[
                  const SizedBox(height: CardMindSpacing.md),
                  _buildTagFilterBar(),
                ],
              ],
            ),
          ),
          Divider(color: tokens.border),
          Expanded(child: _buildListBody(desktop: true)),
        ],
      ),
    );
  }

  Widget _buildDesktopEditorPane() {
    if (_creatingNote) {
      return EditorPage(
        key: ValueKey('draft-$_draftRevision'),
        embedded: true,
        repository: _repository,
        onSaved: _handleEmbeddedSave,
        onNoteOpened: _handleNoteOpened,
      );
    }
    if (_selectedNoteId != null) {
      return EditorPage(
        key: ValueKey(_selectedNoteId),
        noteId: _selectedNoteId,
        embedded: true,
        repository: _repository,
        onSaved: _handleEmbeddedSave,
        onNoteOpened: _handleNoteOpened,
      );
    }
    return const CardMindEmptyState(
      icon: Icons.edit_note_outlined,
      title: '选择一篇笔记',
      message: '在左侧列表选择笔记，或创建一篇新笔记。',
    );
  }

  Widget _buildDesktop() {
    final tokens = context.cardMind;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            VerticalDivider(width: 1, color: tokens.border),
            _buildDesktopListPane(),
            VerticalDivider(width: 1, color: tokens.border),
            Expanded(child: _buildDesktopEditorPane()),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mobileTabIndex == 0 ? 'CardMind' : '设备'),
        actions: [
          IconButton(
            key: const ValueKey('trash-entry'),
            tooltip: '回收站',
            icon: const Icon(Icons.delete_outline),
            onPressed: _openTrash,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CardMindSyncStatus(label: '已就绪'),
          ),
        ],
      ),
      body: SafeArea(
        child: _mobileTabIndex == 0
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: CardMindSearchField(
                      key: const ValueKey('note-search'),
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                      mobile: true,
                    ),
                  ),
                  if (!_isSearching)
                    _buildTagFilterBar(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                      comfortable: true,
                    ),
                  Expanded(child: _buildMobileListBody()),
                ],
              )
            : const CardMindEmptyState(
                icon: Icons.devices_outlined,
                title: '暂无已连接设备',
                message: '发现并连接设备后，同步状态会显示在这里。',
              ),
      ),
      floatingActionButton: _mobileTabIndex == 0
          ? FloatingActionButton(
              key: const ValueKey('new-note'),
              tooltip: '新建笔记',
              onPressed: () => _openMobileEditor(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('main-navigation'),
        selectedIndex: _mobileTabIndex,
        onDestinationSelected: (index) {
          setState(() => _mobileTabIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.notes), label: '笔记'),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            label: '设备',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= CardMindLayout.desktopBreakpoint) {
          return _buildDesktop();
        }
        return _buildMobile();
      },
    );
  }
}
