import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bridge/bridge_helper.dart';
import '../bridge/note_repository.dart';
import '../src/rust/store.dart';
import '../ui/design_system/cardmind_widgets.dart';

/// 回收站页：列出软删除的笔记，支持恢复 / 彻底删除。
///
/// 恢复后返回列表页（由调用方刷新列表）；彻底删除留在本页并刷新。
/// 空状态提示 30 天自动清理。
class TrashPage extends StatefulWidget {
  const TrashPage({super.key, this.repository});

  final NoteRepository? repository;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<NoteRow> _items = [];
  bool _loading = true;

  NoteRepository get _repository => widget.repository ?? BridgeHelper();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.trashList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载回收站失败: $error')));
    }
  }

  String _displayTitle(NoteRow note) {
    var title = BridgeHelper.removeTagsFromContent(note.title).trim();
    title = title.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    return title.isEmpty ? '无标题' : title;
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime);
      return DateFormat('M月d日').format(date);
    } catch (_) {
      try {
        return DateFormat('M月d日').format(DateTime.parse(dateTime));
      } catch (_) {
        return dateTime;
      }
    }
  }

  Future<void> _restore(NoteRow note) async {
    try {
      await _repository.restore(note.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复「${_displayTitle(note)}」')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('恢复失败: $error')));
    }
  }

  Future<void> _confirmPurge(NoteRow note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('彻底删除？'),
        content: Text('「${_displayTitle(note)}」将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            key: const ValueKey('trash-purge-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('trash-purge-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.purge(note.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${_displayTitle(note)}」已彻底删除')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $error')));
    }
  }

  Widget _buildItem(NoteRow note) {
    final tokens = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('trash-item-${note.id}'),
      leading: Icon(Icons.description_outlined, color: tokens.onSurfaceVariant),
      title: Text(
        _displayTitle(note),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('删除于 ${_formatDate(note.deletedAt ?? note.updatedAt)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('trash-restore-${note.id}'),
            tooltip: '恢复',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(note),
          ),
          IconButton(
            key: ValueKey('trash-purge-${note.id}'),
            tooltip: '彻底删除',
            icon: Icon(Icons.delete_forever, color: tokens.error),
            onPressed: () => _confirmPurge(note),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const CardMindEmptyState(
        icon: Icons.delete_outline,
        title: '回收站是空的',
        message: '删除的笔记会在这里保留 30 天，之后自动清理。',
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildItem(_items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        leading: BackButton(
          key: const ValueKey('trash-back'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }
}
