// input: 接收 SyncStatus 与可选 onView/onRetry/onReconnect 回调。
// output: 按同步状态渲染错误横幅、降级提示或“本地已保存”文本。
// pos: 同步状态横幅组件，负责在页面顶部反馈同步健康度。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
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
