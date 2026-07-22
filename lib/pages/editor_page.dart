import 'dart:async';
import 'dart:math' show Random;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../bridge/bridge_helper.dart';
import '../bridge/note_repository.dart';
import '../ui/design_system/cardmind_theme.dart';
import '../ui/design_system/cardmind_widgets.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    this.noteId,
    this.embedded = false,
    this.onSaved,
    this.repository,
  });

  final String? noteId;
  final bool embedded;
  final ValueChanged<String>? onSaved;
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
  bool _loaded = false;
  String? _loadError;
  bool _dirty = false;
  bool _editorDirty = false;
  bool _saving = false;
  String? _sourceMarkdown;
  List<String> _tags = [];
  StreamSubscription<dynamic>? _transactionSubscription;
  Timer? _autosaveTimer;

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
      if (!mounted) return;
      setState(() {
        _originalNoteId = widget.noteId;
        _tags = BridgeHelper.parseTagsFromContent(content);
        final clean = BridgeHelper.removeTagsFromContent(content);
        _sourceMarkdown = clean;
        _editorState = EditorState(document: markdownToDocument(clean));
        _loaded = true;
        _loadError = null;
      });
      _listenToEditor();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadError = '无法加载这篇笔记：$error';
      });
    }
  }

  void _listenToEditor() {
    _transactionSubscription?.cancel();
    _transactionSubscription = _editorState?.transactionStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _dirty = true;
        _editorDirty = true;
      });
      _scheduleAutosave();
    });
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

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(99999);
    return '$timestamp$random';
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

    final noteId = _originalNoteId ?? _generateId();
    final savedTags = List<String>.of(_tags);
    final content = BridgeHelper.encodeContentWithTags(markdown, savedTags);
    if (mounted) setState(() => _saving = true);
    try {
      await _repository.createNote(noteId, content);
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
    final isBlank =
        _editorState == null ||
        _documentMarkdown().trim().isEmpty;
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(body: SafeArea(child: _buildContent())),
    );
  }
}
