part of 'pool_page.dart';

Widget? buildPoolSyncFeedback({
  required BuildContext context,
  required SyncStatus status,
  required Future<void> Function()? onRetrySync,
  required Future<void> Function()? onReconnectSync,
}) {
  if (status.kind != SyncStatusKind.error &&
      status.kind != SyncStatusKind.degraded) {
    return null;
  }

  final isError = status.kind == SyncStatusKind.error;
  final tone = isError
      ? Theme.of(context).colorScheme.errorContainer
      : Theme.of(context).colorScheme.secondaryContainer;
  final message = isError
      ? _syncErrorMessage(status.code)
      : _syncContinuityMessage(status.continuityState.name);
  final contentMessage = _syncContentMessage(status.contentState);
  final actionMessage = _syncNextActionMessage(status.nextAction);

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tone,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 4),
        Text(contentMessage),
        const SizedBox(height: 4),
        Text(actionMessage),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              key: const ValueKey('pool.sync.retry'),
              onPressed: onRetrySync,
              child: const Text('重试同步'),
            ),
            TextButton(
              key: const ValueKey('pool.sync.reconnect'),
              onPressed: onReconnectSync,
              child: const Text('重新连接'),
            ),
            if (isError)
              TextButton(
                key: const ValueKey('pool.sync.view_error'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('错误详情: ${status.code}')),
                  );
                },
                child: const Text('查看'),
              ),
          ],
        ),
      ],
    ),
  );
}

String _syncErrorMessage(String? code) {
  switch (code) {
    case 'REQUEST_TIMEOUT':
      return '同步请求超时，请查看并处理';
    case 'ADMIN_OFFLINE':
      return '管理员离线，请查看并处理';
    default:
      return '同步异常，请在数据池列表页处理';
  }
}

String _syncContinuityMessage(String continuityState) {
  switch (continuityState) {
    case 'same_path':
    case 'samePath':
      return '同步状态降级：仍在同一条延续路径';
    case 'path_at_risk':
    case 'pathAtRisk':
      return '同步状态降级：延续路径有风险';
    case 'path_broken':
    case 'pathBroken':
      return '同步状态降级：延续路径已断裂';
    default:
      return '同步状态降级：延续路径状态待确认';
  }
}

String _syncContentMessage(String contentState) {
  switch (contentState) {
    case 'content_safe':
      return '当前内容安全，可继续使用。';
    case 'content_safe_local_only':
      return '当前内容安全，可继续本地操作。';
    default:
      return '当前内容状态待确认，请先检查同步状态。';
  }
}

String _syncNextActionMessage(String nextAction) {
  switch (nextAction) {
    case 'reconnect':
      return '建议下一步：重新连接';
    case 'check_status':
      return '建议下一步：检查当前状态';
    case 'retry':
      return '建议下一步：重试同步';
    default:
      return '建议下一步：无需额外操作';
  }
}
