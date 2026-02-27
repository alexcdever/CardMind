import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({super.key, this.syncStatus = const SyncStatus.healthy()});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final interactions = const CardsDesktopInteractions();

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          interactions.showContextMenu(context, details.globalPosition);
        },
        child: Column(
          children: [
            SyncBanner(
              status: syncStatus,
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
