import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge_helper.dart';
import '../bridge/note_repository.dart';
import '../src/rust/store.dart';
import '../ui/design_system/cardmind_theme.dart';
import '../ui/design_system/cardmind_widgets.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    this.noteId,
    this.embedded = false,
    this.onSaved,
    this.onNoteOpened,
    this.repository,
  });

  final String? noteId;
  final bool embedded;
  final ValueChanged<String>? onSaved;

  /// 嵌入式（桌面三栏）模式下，反链跳转到另一篇笔记时通知父组件切换选中。
  final ValueChanged<String>? onNoteOpened;
  final NoteRepository? repository;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialValue.isEmpty ? '添加标签' : '编辑标签'),
      content: TextField(
        key: const ValueKey('tag-name-input'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '标签名称'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          key: const ValueKey('tag-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('tag-dialog-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _EditorPageState extends State<EditorPage> {
  EditorState? _editorState;
  String? _originalNoteId;

  /// 当前正在编辑的笔记 id（新建保存后从 null 变为生成值；反链跳转由父组件重建）。
  String? get _activeNoteId => _originalNoteId ?? widget.noteId;

  bool _loaded = false;
  String? _loadError;
  bool _dirty = false;
  bool _editorDirty = false;
  bool _saving = false;
  String? _sourceMarkdown;
  List<String> _tags = [];
  StreamSubscription<dynamic>? _transactionSubscription;
  Timer? _autosaveTimer;
  final FocusNode _keyboardFocusNode = FocusNode();

  // ━━ 链接自动补全 ━━
  List<NoteRow> _linkCandidates = [];
  String _linkPrefix = '';
  int _linkGen = 0;
  OverlayEntry? _linkOverlay;

  // ━━ 反链 ━━
  List<LinkRow> _backlinks = [];
  bool _backlinksLoaded = false;

  NoteRepository get _repository => widget.repository ?? BridgeHelper();

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _initializeExisting();
    } else {
      _editorState = EditorState.blank(withInitialText: true);
      _loaded = true;
      _listenToEditor();
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _transactionSubscription?.cancel();
    _editorState?.selectionNotifier.removeListener(_onEditorSelectionChanged);
    _linkOverlay?.remove();
    _keyboardFocusNode.dispose();
    if (widget.embedded && _dirty) {
      unawaited(_save(notifyParent: false));
    }
    super.dispose();
  }

  Future<void> _initializeExisting() async {
    try {
      final content = await _repository.getNote(widget.noteId!);
      if (content == null) {
        throw StateError('笔记不存在');
      }
      final tags = await _loadTagsForNote(widget.noteId!);
      if (!mounted) return;
      setState(() {
        _originalNoteId = widget.noteId;
        _tags = tags;
        final clean = BridgeHelper.removeTagsFromContent(content);
        _sourceMarkdown = clean;
        _editorState = EditorState(document: markdownToDocument(clean));
        _loaded = true;
        _loadError = null;
      });
      _listenToEditor();
      _loadBacklinks();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadError = '无法加载这篇笔记：$error';
      });
    }
  }

  /// 标签已元数据化：从 listNotes 的投影行（tags 列）取当前笔记标签。
  Future<List<String>> _loadTagsForNote(String id) async {
    try {
      final rows = await _repository.listNotes();
      for (final row in rows) {
        if (row.id == id) return _parseTagString(row.tags);
      }
    } catch (_) {
      // 列表加载失败不影响编辑器正文，返回空标签。
    }
    return <String>[];
  }

  List<String> _parseTagString(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  void _listenToEditor() {
    _transactionSubscription?.cancel();
    _transactionSubscription = _editorState?.transactionStream.listen((_) {
      _onEditorChanged();
    });
    _editorState?.selectionNotifier.addListener(_onEditorSelectionChanged);
  }

  void _onEditorSelectionChanged() {
    _updateLinkCompletions();
  }

  void _onEditorChanged() {
    if (!mounted) return;
    setState(() {
      _dirty = true;
      _editorDirty = true;
    });
    _updateLinkCompletions();
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (!widget.embedded) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), () {
      _save();
    });
  }

  String _documentMarkdown() {
    return documentToMarkdown(
      _editorState!.document,
      lineBreak: '\n',
    ).trimRight();
  }

  String _getTitle() {
    if (_editorState == null) return '新笔记';
    final markdown = _documentMarkdown();
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) return '无标题';
    final firstLine = trimmed.split('\n').first.trim();
    final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
    return title.isEmpty ? '无标题' : title;
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (_tags.any((item) => item.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    setState(() {
      _tags.add(trimmed);
      _dirty = true;
    });
    _scheduleAutosave();
  }

  void _editTag(int index, String newTag) {
    final trimmed = newTag.trim();
    if (trimmed.isEmpty) return;
    final duplicates = _tags.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicates) return;
    setState(() {
      _tags[index] = trimmed;
      _dirty = true;
    });
    _scheduleAutosave();
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
      _dirty = true;
    });
    _scheduleAutosave();
  }

  Future<String?> _requestTagName({String initialValue = ''}) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _TagNameDialog(initialValue: initialValue),
    );
  }

  Future<void> _showAddTagDialog() async {
    final tag = await _requestTagName();
    if (tag != null) _addTag(tag);
  }

  Future<void> _showTagMenu(int index) async {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final action = compact
        ? await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    key: const ValueKey('tag-action-edit'),
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('重命名标签'),
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                  ListTile(
                    key: const ValueKey('tag-action-delete'),
                    leading: Icon(
                      Icons.delete_outline,
                      color: context.cardMind.danger,
                    ),
                    title: Text(
                      '删除标签',
                      style: TextStyle(color: context.cardMind.danger),
                    ),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
                ],
              ),
            ),
          )
        : await showMenu<String>(
            context: context,
            position: const RelativeRect.fromLTRB(24, 72, 0, 0),
            items: const [
              PopupMenuItem(
                key: ValueKey('tag-action-edit'),
                value: 'edit',
                child: Text('重命名'),
              ),
              PopupMenuItem(
                key: ValueKey('tag-action-delete'),
                value: 'delete',
                child: Text('删除'),
              ),
            ],
          );
    if (!mounted) return;
    if (action == 'delete') {
      _removeTag(index);
      return;
    }
    if (action == 'edit') {
      final tag = await _requestTagName(initialValue: _tags[index]);
      if (tag != null) _editTag(index, tag);
    }
  }

  Future<String?> _save({
    bool notifyParent = true,
    bool showFeedback = false,
  }) async {
    if (_editorState == null || _saving) return _originalNoteId;
    final currentMarkdown = _documentMarkdown();
    final markdown = !_editorDirty && _sourceMarkdown != null
        ? _sourceMarkdown!
        : currentMarkdown;
    if (markdown.trim().isEmpty) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('空白笔记无需保存')));
      }
      return null;
    }

    final noteId = _originalNoteId ?? await _repository.generateNoteId();
    final savedTags = List<String>.of(_tags);
    if (mounted) setState(() => _saving = true);
    try {
      // 正文与标签分离：正文干净存储，标签走元数据 API。
      await _repository.createNote(noteId, markdown);
      await _repository.updateMetadata(noteId, savedTags);
      if (!mounted) return noteId;
      setState(() {
        _originalNoteId = noteId;
        _editorDirty = _documentMarkdown() != markdown;
        _dirty = _editorDirty || !_sameTags(_tags, savedTags);
        _sourceMarkdown = markdown;
        _saving = false;
      });
      if (notifyParent) widget.onSaved?.call(noteId);
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
      }
      if (_dirty) _scheduleAutosave();
      return noteId;
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $error')));
      }
      return null;
    }
  }

  bool _sameTags(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Future<void> _close() async {
    final isBlank = _editorState == null || _documentMarkdown().trim().isEmpty;
    final savedId = await _save(notifyParent: false);
    if (mounted && (isBlank || savedId != null)) Navigator.of(context).pop();
  }

  Future<void> _retryLoad() async {
    if (widget.noteId == null) return;
    setState(() {
      _loaded = false;
      _loadError = null;
    });
    await _initializeExisting();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━ 链接自动补全 ━━━━━━━━━━━━━━━━━━━━━━━━━━

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _linkOverlay != null) {
      _hideLinkCompletions();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 检测光标前最近的 `[[` + 前缀（未闭合），命中则显示补全面板。
  void _updateLinkCompletions() {
    final state = _editorState;
    final selection = state?.selection;
    if (state == null ||
        selection == null ||
        !selection.isCollapsed ||
        !selection.isSingle) {
      _hideLinkCompletions();
      return;
    }
    final node = state.document.nodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      _hideLinkCompletions();
      return;
    }
    final text = delta.toPlainText();
    final caret = selection.start.offset;
    if (caret < 2) {
      _hideLinkCompletions();
      return;
    }
    final before = text.substring(0, caret);
    final openIdx = before.lastIndexOf('[[');
    if (openIdx < 0) {
      _hideLinkCompletions();
      return;
    }
    final afterOpen = before.substring(openIdx + 2);
    // 已闭合或跨行：不再补全
    if (afterOpen.contains(']]') || afterOpen.contains('\n')) {
      _hideLinkCompletions();
      return;
    }
    if (afterOpen.length > 40) {
      _hideLinkCompletions();
      return;
    }
    _linkPrefix = afterOpen;
    _showLinkOverlay();
    unawaited(_loadLinkCandidates(_linkPrefix));
  }

  Future<void> _loadLinkCandidates(String prefix) async {
    final gen = ++_linkGen;
    try {
      final candidates = await _repository.autoCompleteLinks(prefix);
      if (!mounted || gen != _linkGen) return;
      setState(() {
        _linkCandidates = candidates;
      });
      _linkOverlay?.markNeedsBuild();
    } catch (_) {
      if (!mounted || gen != _linkGen) return;
      _hideLinkCompletions();
    }
  }

  void _showLinkOverlay() {
    if (_linkOverlay != null) return;
    _linkOverlay = OverlayEntry(builder: (context) => _buildLinkOverlay());
    Overlay.of(context).insert(_linkOverlay!);
  }

  void _hideLinkCompletions() {
    if (_linkOverlay != null) {
      _linkOverlay!.remove();
      _linkOverlay = null;
    }
    _linkCandidates = [];
  }

  /// 光标所在块的全局矩形，用于锚定补全面板。
  Rect? _linkPanelRect() {
    final state = _editorState;
    if (state == null) return null;
    try {
      final rects = state.selectionRects();
      if (rects.isEmpty) return null;
      return rects.first;
    } catch (_) {
      return null;
    }
  }

  Widget _buildLinkOverlay() {
    final rect = _linkPanelRect();
    final left = rect?.left ?? 20.0;
    final top = (rect?.bottom ?? 100.0) + 4.0;
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            key: const ValueKey('link-completion-panel'),
            elevation: 4,
            borderRadius: BorderRadius.circular(CardMindRadii.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: _linkCandidates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(CardMindSpacing.md),
                      child: Text('无匹配笔记'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _linkCandidates.length,
                      itemBuilder: (context, index) {
                        final note = _linkCandidates[index];
                        return ListTile(
                          key: ValueKey('link-completion-${note.id}'),
                          dense: true,
                          leading: const Icon(Icons.link, size: 18),
                          title: Text(
                            note.title.isEmpty ? '无标题' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _insertLinkCompletion(note),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _insertLinkCompletion(NoteRow note) {
    final state = _editorState;
    final selection = state?.selection;
    if (state == null || selection == null || !selection.isCollapsed) {
      _hideLinkCompletions();
      return;
    }
    final path = selection.start.path;
    final node = state.document.nodeAtPath(path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      _hideLinkCompletions();
      return;
    }
    final text = delta.toPlainText();
    final caret = selection.start.offset;
    final before = text.substring(0, caret);
    final openIdx = before.lastIndexOf('[[');
    if (openIdx < 0) {
      _hideLinkCompletions();
      return;
    }
    final prefixLength = caret - openIdx - 2;
    final transaction = state.transaction
      ..deleteText(node, openIdx, 2 + prefixLength)
      ..insertText(node, openIdx, '[[${note.id}|${note.title}]]');
    unawaited(state.apply(transaction));
    _hideLinkCompletions();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━ 反链面板 ━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _loadBacklinks() async {
    final id = _activeNoteId;
    if (id == null) {
      if (mounted) {
        setState(() {
          _backlinks = [];
          _backlinksLoaded = true;
        });
      }
      return;
    }
    try {
      final backlinks = await _repository.getBacklinks(id);
      if (!mounted || _activeNoteId != id) return;
      setState(() {
        _backlinks = backlinks;
        _backlinksLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backlinks = [];
        _backlinksLoaded = true;
      });
    }
  }

  void _openNote(String id) {
    if (id == _activeNoteId) return;
    if (widget.embedded) {
      widget.onNoteOpened?.call(id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              EditorPage(noteId: id, repository: widget.repository),
        ),
      );
    }
  }

  Widget _buildBacklinksPanel() {
    if (!_backlinksLoaded || _backlinks.isEmpty) {
      return const SizedBox.shrink();
    }
    final tokens = context.cardMind;
    return Container(
      key: const ValueKey('backlinks-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 15, color: tokens.accent),
              const SizedBox(width: CardMindSpacing.xs),
              Text(
                '反链',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.mutedInk,
                ),
              ),
              const SizedBox(width: CardMindSpacing.sm),
              Text(
                '${_backlinks.length}',
                style: TextStyle(color: tokens.mutedInk, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: CardMindSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final link in _backlinks) _buildBacklinkTile(link),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacklinkTile(LinkRow link) {
    final tokens = context.cardMind;
    final label = link.title.isNotEmpty
        ? link.title
        : (link.alias.isNotEmpty ? link.alias : link.id);
    final dangling = !link.exists;
    return InkWell(
      key: ValueKey('backlink-${link.id}'),
      onTap: dangling ? null : () => _openNote(link.id),
      borderRadius: BorderRadius.circular(CardMindRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.chevron_right,
              size: 15,
              color: dangling ? tokens.border : tokens.accent,
            ),
            const SizedBox(width: CardMindSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dangling ? tokens.mutedInk : tokens.ink,
                  fontSize: 14,
                  decoration: dangling ? null : TextDecoration.underline,
                  decorationColor: tokens.accent,
                ),
              ),
            ),
            if (dangling) ...[
              const SizedBox(width: CardMindSpacing.sm),
              Text(
                '已删除',
                style: TextStyle(color: tokens.mutedInk, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━ UI 构建 ━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildToolbar() {
    final tokens = context.cardMind;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? CardMindSpacing.md : CardMindSpacing.lg,
        vertical: compact ? CardMindSpacing.sm : CardMindSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            CardMindIconButton(
              key: const ValueKey('editor-close'),
              icon: Icons.close,
              tooltip: '关闭编辑器',
              onPressed: _close,
            ),
            const SizedBox(width: CardMindSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: compact ? 16 : 18,
                  ),
                ),
                Text(
                  _saving ? '正在保存' : (_dirty ? '尚未保存' : '已保存'),
                  style: TextStyle(
                    color: tokens.mutedInk,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          CardMindIconButton(
            key: const ValueKey('editor-add-tag'),
            icon: Icons.sell_outlined,
            tooltip: '添加标签',
            onPressed: _showAddTagDialog,
          ),
          const SizedBox(width: CardMindSpacing.sm),
          if (compact)
            CardMindIconButton(
              key: const ValueKey('editor-save'),
              icon: _saving ? Icons.sync : Icons.save_outlined,
              tooltip: _saving ? '保存中' : '保存',
              onPressed: _saving ? null : () => _save(showFeedback: true),
            )
          else
            CardMindPrimaryButton(
              key: const ValueKey('editor-save'),
              label: _saving ? '保存中' : '保存',
              icon: _saving ? Icons.sync : Icons.save_outlined,
              onPressed: _saving ? null : () => _save(showFeedback: true),
            ),
        ],
      ),
    );
  }

  Widget _buildTagRow() {
    if (_tags.isEmpty) return const SizedBox.shrink();
    final tokens = context.cardMind;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 12 : 10,
        compact ? 16 : 24,
        compact ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Wrap(
        spacing: CardMindSpacing.sm,
        runSpacing: CardMindSpacing.sm,
        children: [
          for (final entry in _tags.asMap().entries)
            CardMindTag(
              key: ValueKey('editor-tag-${entry.value.toLowerCase()}'),
              label: entry.value,
              comfortable: compact,
              onTap: () => _showTagMenu(entry.key),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final tokens = context.cardMind;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final textStyle = TextStyle(
          color: tokens.ink,
          fontSize: compact ? 16 : 15,
          height: 24 / (compact ? 16 : 15),
        );
        return Semantics(
          identifier: 'note-editor',
          textField: true,
          label: '笔记编辑器',
          child: AppFlowyEditor(
            key: const ValueKey('note-editor'),
            editorState: _editorState!,
            autoFocus: widget.noteId == null,
            editorStyle: compact
                ? EditorStyle.mobile(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    cursorColor: tokens.accent,
                    dragHandleColor: tokens.accent,
                    selectionColor: tokens.accent.withValues(alpha: 0.20),
                    textStyleConfiguration: TextStyleConfiguration(
                      text: textStyle,
                    ),
                  )
                : EditorStyle.desktop(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 56,
                    ),
                    maxWidth: CardMindLayout.editorMaxWidth,
                    cursorColor: tokens.accent,
                    selectionColor: tokens.accent.withValues(alpha: 0.20),
                    textStyleConfiguration: TextStyleConfiguration(
                      text: textStyle,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final tokens = context.cardMind;
    if (_loadError != null) {
      return ColoredBox(
        color: tokens.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CardMindSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 42, color: tokens.danger),
                const SizedBox(height: CardMindSpacing.lg),
                Text('无法打开笔记', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CardMindSpacing.sm),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.mutedInk),
                ),
                const SizedBox(height: CardMindSpacing.lg),
                CardMindPrimaryButton(
                  label: '重试',
                  icon: Icons.refresh,
                  onPressed: _retryLoad,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_loaded || _editorState == null) {
      return ColoredBox(
        color: tokens.paper,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return ColoredBox(
      color: tokens.paper,
      child: Column(
        children: [
          _buildToolbar(),
          _buildTagRow(),
          Expanded(child: _buildEditor()),
          _buildBacklinksPanel(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.embedded
        ? _buildContent()
        : PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _close();
            },
            child: Scaffold(body: SafeArea(child: _buildContent())),
          );
    return KeyboardListener(
      key: const ValueKey('editor-keyboard-listener'),
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: content,
    );
  }
}
