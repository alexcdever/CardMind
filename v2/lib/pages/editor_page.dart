import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

class EditorPage extends StatefulWidget {
  final int? noteId;

  const EditorPage({super.key, this.noteId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  EditorState? _editorState;
  Note? _originalNote;
  bool _loaded = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.noteId != null) {
      final note = await DatabaseHelper().getById(widget.noteId!);
      if (note != null && mounted) {
        setState(() {
          _originalNote = note;
          _tags = _parseTags(note.tags);
          _editorState = EditorState(
            document: markdownToDocument(note.content),
          );
          _loaded = true;
        });
        return;
      }
    }
    // New note or note not found
    if (mounted) {
      setState(() {
        _editorState = EditorState.blank(withInitialText: true);
        _loaded = true;
      });
    }
  }

  String _getTitle() {
    if (_originalNote != null) {
      return _originalNote!.title;
    }
    return '新笔记';
  }

  /// Extract title from the first line of Markdown content.
  /// Removes leading `# ` prefix from headings.
  String _extractTitle(String markdown) {
    final trimmed = markdown.trim();
    if (trimmed.isEmpty) return '无标题';

    final firstLine = trimmed.split('\n').first.trim();
    // Remove leading "# " heading markers
    final title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
    return title.isEmpty ? '无标题' : title;
  }

  List<String> _parseTags(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == trimmed.toLowerCase())) return;
    setState(() {
      _tags.add(trimmed);
    });
  }

  void _editTag(int index, String newTag) {
    final trimmed = newTag.trim();
    if (trimmed.isEmpty) return;
    if (_tags.asMap().entries.any((e) =>
        e.key != index && e.value.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    setState(() {
      _tags[index] = trimmed;
    });
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (tag != null) {
      _addTag(tag);
    }
  }

  Future<void> _showTagMenu(int index) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('标签: ${_tags[index]}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: const ListTile(
              leading: Icon(Icons.edit),
              title: Text('编辑名称'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const ListTile(
              leading: Icon(Icons.delete),
              title: Text('删除标签'),
              dense: true,
            ),
          ),
        ],
      ),
    );
    if (result == 'edit') {
      final controller = TextEditingController(text: _tags[index]);
      final newTag = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('编辑标签'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入新名称',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (newTag != null) {
        _editTag(index, newTag);
      }
    } else if (result == 'delete') {
      _removeTag(index);
    }
  }

  Future<bool> _onWillPop() async {
    if (_editorState == null) return true;

    final markdown = documentToMarkdown(_editorState!.document);
    final isEmpty = markdown.trim().isEmpty;

    if (isEmpty) {
      // Don't save empty notes
      return true;
    }

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final title = _extractTitle(markdown);
    final tagsStr = _tags.join(',');

    if (_originalNote != null) {
      // Update existing note
      final updated = _originalNote!.copyWith(
        title: title,
        content: markdown,
        tags: tagsStr,
        updatedAt: now,
      );
      await DatabaseHelper().update(updated);
    } else {
      // Insert new note
      final note = Note(
        title: title,
        content: markdown,
        tags: tagsStr,
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseHelper().insert(note);
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _editorState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(_getTitle()),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Tag editing area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._tags.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(entry.value,
                                  style: const TextStyle(fontSize: 12)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onPressed: () => _showTagMenu(entry.key),
                            ),
                          )),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: const Icon(Icons.add, size: 16),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: _showAddTagDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Editor
              Expanded(
                child: AppFlowyEditor(
                  editorState: _editorState!,
                  autoFocus: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
