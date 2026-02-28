// input: lib/features/cards/cards_page.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
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
