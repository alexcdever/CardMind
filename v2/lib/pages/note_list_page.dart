import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  List<Note> _notes = [];
  bool _loading = true;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final notes = await DatabaseHelper().getAll();
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  String _preview(Note note) {
    final trimmed = note.content.trim();
    if (trimmed.isEmpty) return '';
    // Take the first line
    final firstLine = trimmed.split('\n').first.trim();
    if (firstLine.length <= 80) return firstLine;
    return '${firstLine.substring(0, 80)}…';
  }

  String _formatDate(String updatedAt) {
    try {
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(updatedAt);
      return DateFormat('M月d日').format(date);
    } catch (_) {
      return updatedAt;
    }
  }

  List<String> _parseTags(String tags) {
    if (tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  List<String> _getAllTags() {
    final tagSet = <String>{};
    for (final note in _notes) {
      tagSet.addAll(_parseTags(note.tags));
    }
    return tagSet.toList()..sort();
  }

  List<Note> get _filteredNotes {
    if (_selectedTag == null) return _notes;
    return _notes.where((note) {
      final tags = _parseTags(note.tags);
      return tags.any((t) => t.toLowerCase() == _selectedTag!.toLowerCase());
    }).toList();
  }

  Widget _buildTagFilterBar() {
    final allTags = _getAllTags();
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allTags.map((tag) {
            final isSelected = _selectedTag == tag;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(tag, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onSelected: (_) {
                  setState(() {
                    _selectedTag = isSelected ? null : tag;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无笔记',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final preview = _preview(note);
    final formattedDate = _formatDate(note.updatedAt);
    final tags = _parseTags(note.tags);

    return ListTile(
      title: Text(
        note.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                preview,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...tags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
      onTap: () async {
        await Navigator.pushNamed(context, '/editor',
            arguments: {'noteId': note.id});
        _loadNotes();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardMind'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildTagFilterBar(),
                    Expanded(
                      child: _filteredNotes.isEmpty
                          ? Center(
                              child: Text(
                                '没有包含"$_selectedTag"标签的笔记',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filteredNotes.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) =>
                                  _buildNoteItem(_filteredNotes[index]),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/editor');
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
