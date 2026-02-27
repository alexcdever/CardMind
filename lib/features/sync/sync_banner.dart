// input: 同步状态与可选查看回调
// output: 健康提示或可操作的同步异常横幅
// pos: 全局同步反馈组件；修改本文件需同步更新文件头与所属 DIR.md
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({
    super.key,
    required this.status,
    this.onView,
    this.onRetry,
    this.onReconnect,
  });

  final SyncStatus status;
  final VoidCallback? onView;
  final VoidCallback? onRetry;
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    if (status.kind == SyncStatusKind.error) {
      return MaterialBanner(
        content: Text(_messageFor(status.code)),
        actions: [
          TextButton(onPressed: onRetry, child: const Text('重试同步')),
          TextButton(onPressed: onReconnect, child: const Text('重新连接')),
          TextButton(onPressed: onView, child: const Text('查看')),
        ],
      );
    }

    if (status.kind == SyncStatusKind.degraded) {
      return const MaterialBanner(
        content: Text('同步状态降级：可继续本地操作'),
        actions: <Widget>[],
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
