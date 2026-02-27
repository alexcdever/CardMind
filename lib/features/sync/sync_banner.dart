import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.kind == SyncStatusKind.error) {
      return MaterialBanner(
        content: const Text('同步异常，请前往池页面处理'),
        actions: [TextButton(onPressed: () {}, child: const Text('查看'))],
      );
    }

    return const Text('本地已保存');
  }
}
