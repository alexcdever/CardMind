import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.status, this.onView});

  final SyncStatus status;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    if (status.kind == SyncStatusKind.error) {
      return MaterialBanner(
        content: Text(_messageFor(status.code)),
        actions: [TextButton(onPressed: onView, child: const Text('查看'))],
      );
    }

    return const Text('本地已保存');
  }

  String _messageFor(String? code) {
    switch (code) {
      case 'REQUEST_TIMEOUT':
        return '同步请求超时，请查看并处理';
      case 'ADMIN_OFFLINE':
        return '管理员离线，请查看并处理';
      default:
        return '同步异常，请前往池页面处理';
    }
  }
}
