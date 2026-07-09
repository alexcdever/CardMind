import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bridge/bridge_helper.dart';
import '../src/rust/store.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  List<NoteRow> _notes = [];
  bool _loading = true;
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<NoteRow> _searchResults = [];
  bool _isSearching = false;

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
    setState(() => _loading = true);
    try {
      final notes = await BridgeHelper().listNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _preview(NoteRow note) {
    final preview = note.contentPreview.trim();
    if (preview.isEmpty) return '';
    if (preview.length <= 80) return preview;
    return '${preview.substring(0, 80)}…';
  }

  String _formatDate(String updatedAt) {
    try {
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(updatedAt);
      return DateFormat('M月d日').format(date);
    } catch (_) {
      try {
        final date = DateTime.parse(updatedAt);
        return DateFormat('M月d日').format(date);
      } catch (_) {
        return updatedAt;
      }
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

  List<NoteRow> get _filteredNotes {
    if (_selectedTag == null) return _notes;
    return _notes.where((note) {
      final tags = _parseTags(note.tags);
      return tags.any((t) => t.toLowerCase() == _selectedTag!.toLowerCase());
    }).toList();
  }

  List<NoteRow> get _displayedNotes {
    if (_isSearching) return _searchResults;
    return _filteredNotes;
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final results = await BridgeHelper().search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索笔记...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: _onSearchChanged,
      ),
    );
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

  Widget _buildNoteItem(NoteRow note) {
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
          : _notes.isEmpty && !_isSearching
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    if (!_isSearching) _buildTagFilterBar(),
                    Expanded(
                      child: _displayedNotes.isEmpty
                          ? Center(
                              child: Text(
                                _isSearching
                                    ? '没有找到匹配的笔记'
                                    : '没有包含"$_selectedTag"标签的笔记',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _displayedNotes.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) =>
                                  _buildNoteItem(_displayedNotes[index]),
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
