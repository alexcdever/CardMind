import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

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
          children: const [
            SyncBanner(status: SyncStatus.healthy()),
            TextField(decoration: InputDecoration(hintText: '搜索卡片')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        child: const Icon(Icons.add),
      ),
    );
  }
}
