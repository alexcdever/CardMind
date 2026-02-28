// input: 页面接收 syncStatus，并通过 CardsController 处理卡片 CRUD 与检索。
// output: 渲染读模型列表与同步横幅，支持进入编辑页保存后回写列表。
// pos: 卡片页主界面，负责卡片读写交互与编辑入口编排。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'dart:async';

import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key, this.syncStatus = const SyncStatus.healthy()});

  final SyncStatus syncStatus;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final AppDatabase _database = AppDatabase();
  late final CardsController _controller = CardsController(
    readRepository: SqliteCardsReadRepository(database: _database),
    writeRepository: LoroCardsWriteRepository.inMemory(),
  )..addListener(_onChanged);

  @override
  void initState() {
    super.initState();
    unawaited(_seedAndLoad());
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _seedAndLoad() async {
    await _controller.create('seed-note', '示例卡片A', 'seed');
  }

  Future<void> _onDeleteOrRestore({required String id, required bool deleted}) {
    return deleted ? _controller.restore(id) : _controller.delete(id);
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(
          onSaved: (draft) {
            if (draft.title.isEmpty) {
              return;
            }
            unawaited(
              _controller.create(generateNoteId(), draft.title, draft.body),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactions = const CardsDesktopInteractions();
    final notes = _controller.items;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          interactions.showContextMenu(context, details.globalPosition);
        },
        child: Column(
          children: [
            SyncBanner(
              status: widget.syncStatus,
              onView: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PoolPage(
                      state: PoolState.error('REQUEST_TIMEOUT'),
                    ),
                  ),
                );
              },
            ),
            TextField(
              decoration: const InputDecoration(hintText: '搜索卡片'),
              onChanged: (value) {
                unawaited(_controller.load(query: value));
              },
            ),
            for (final note in notes)
              ListTile(
                title: Text(note.title),
                subtitle: note.deleted ? const Text('已删除') : null,
                trailing: TextButton(
                  onPressed: () {
                    unawaited(
                      _onDeleteOrRestore(id: note.id, deleted: note.deleted),
                    );
                  },
                  child: Text(note.deleted ? '恢复' : '删除'),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _openEditor(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
