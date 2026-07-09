import 'dart:math' show Random;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../bridge/bridge_helper.dart';

class EditorPage extends StatefulWidget {
  final String? noteId;

  const EditorPage({super.key, this.noteId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  EditorState? _editorState;
  String? _originalNoteId;
  bool _loaded = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _initializeExisting();
    } else {
      _editorState = EditorState.blank(withInitialText: true);
      _loaded = true;
    }
  }

  Future<void> _initializeExisting() async {
    final content = await BridgeHelper().getNote(widget.noteId!);
    if (content != null && mounted) {
      setState(() {
        _originalNoteId = widget.noteId;
        _tags = BridgeHelper.parseTagsFromContent(content);
        final clean = BridgeHelper.removeTagsFromContent(content);
        _editorState = EditorState(
          document: markdownToDocument(clean),
        );
        _loaded = true;
      });
    }
  }

  String _getTitle() {
    if (_editorState != null) {
      final markdown = documentToMarkdown(_editorState!.document);
      return _extractTitle(markdown);
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
      if (!mounted) return;
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

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(99999);
    return '$ts$rnd';
  }

  Future<bool> _onWillPop() async {
    if (_editorState == null) return true;

    final markdown = documentToMarkdown(_editorState!.document);
    final isEmpty = markdown.trim().isEmpty;

    if (isEmpty) {
      // Don't save empty notes
      return true;
    }

    // Encode tags into the content before saving
    final contentWithTags =
        BridgeHelper.encodeContentWithTags(markdown, _tags);

    if (_originalNoteId != null) {
      // Update existing note (overwrite with same id)
      await BridgeHelper().createNote(_originalNoteId!, contentWithTags);
    } else {
      // Insert new note
      final noteId = _generateId();
      await BridgeHelper().createNote(noteId, contentWithTags);
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
