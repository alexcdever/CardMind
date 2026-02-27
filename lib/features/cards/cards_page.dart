// input: 同步状态与卡片列表交互动作
// output: 卡片页 CRUD 行为与异常可处理反馈
// pos: 卡片主工作区页面；修改需同步对应测试与 DIR.md
import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
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
  final List<_CardNote> _notes = <_CardNote>[
    const _CardNote(title: '示例卡片A', deleted: false),
  ];

  @override
  Widget build(BuildContext context) {
    final interactions = const CardsDesktopInteractions();
    final note = _notes.first;

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
            const TextField(decoration: InputDecoration(hintText: '搜索卡片')),
            ListTile(
              title: Text(note.title),
              subtitle: note.deleted ? const Text('已删除') : null,
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _notes[0] = _CardNote(
                      title: note.title,
                      deleted: !note.deleted,
                    );
                  });
                },
                child: Text(note.deleted ? '恢复' : '删除'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const EditorPage()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CardNote {
  const _CardNote({required this.title, required this.deleted});

  final String title;
  final bool deleted;
}
