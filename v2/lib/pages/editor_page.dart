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

    if (_originalNote != null) {
      // Update existing note
      final updated = _originalNote!.copyWith(
        title: title,
        content: markdown,
        updatedAt: now,
      );
      await DatabaseHelper().update(updated);
    } else {
      // Insert new note
      final note = Note(
        title: title,
        content: markdown,
        tags: '',
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
          child: AppFlowyEditor(
            editorState: _editorState!,
            autoFocus: true,
          ),
        ),
      ),
    );
  }
}
