part of 'pool_page.dart';

class _PoolNotJoinedView extends StatelessWidget {
  const _PoolNotJoinedView({
    required this.controller,
    required this.syncStatus,
    required this.onScanJoin,
  });

  final PoolController controller;
  final SyncStatus syncStatus;
  final VoidCallback onScanJoin;

  @override
  Widget build(BuildContext context) {
    final syncFeedback = buildPoolSyncFeedback(
      context: context,
      status: syncStatus,
      onRetrySync: controller.retrySync,
      onReconnectSync: controller.reconnectSync,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            syncFeedback ?? const SizedBox.shrink(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('在这里创建或加入数据池'),
                    ),
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: SemanticIds.poolCreateButton,
                      label: '创建池',
                      button: true,
                      child: ElevatedButton(
                        key: const ValueKey('pool.create_button'),
                        onPressed: controller.joining
                            ? null
                            : controller.createPool,
                        child: const Text('创建池'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: SemanticIds.poolJoinScanButton,
                      label: '扫码加入',
                      button: true,
                      child: OutlinedButton(
                        key: const ValueKey('pool.join_scan_button'),
                        onPressed: controller.joining ? null : onScanJoin,
                        child: const Text('扫码加入'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const ValueKey('pool.submit_join_request_button'),
                      onPressed: controller.joining
                          ? null
                          : () {
                              unawaited(controller.submitJoinRequest());
                            },
                      child: const Text('提交加入申请'),
                    ),
                    if (controller.joining)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('请求处理中...'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolJoinedView extends StatelessWidget {
  const _PoolJoinedView({
    required this.state,
    required this.controller,
    required this.syncStatus,
    required this.noticeMessage,
    required this.canShowReturnToPool,
    required this.onReturnToPool,
    required this.onEditPool,
    required this.onConfirmDissolve,
    required this.onConfirmLeave,
  });

  final PoolJoined state;
  final PoolController controller;
  final SyncStatus syncStatus;
  final String? noticeMessage;
  final bool canShowReturnToPool;
  final VoidCallback onReturnToPool;
  final VoidCallback onEditPool;
  final VoidCallback onConfirmDissolve;
  final VoidCallback onConfirmLeave;

  @override
  Widget build(BuildContext context) {
    final syncFeedback = buildPoolSyncFeedback(
      context: context,
      status: syncStatus,
      onRetrySync: controller.retrySync,
      onReconnectSync: controller.reconnectSync,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            syncFeedback ?? const SizedBox.shrink(),
            if (canShowReturnToPool)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: onReturnToPool,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回数据池Tab'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('我的身份: ${state.currentIdentityLabel}'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('成员列表'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.poolName),
            ),
            if (state.isOwner && state.inviteCode != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('邀请字符串'),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.inviteCode!,
                      key: const ValueKey('pool.invite_code'),
                    ),
                  ],
                ),
              ),
            if (state.isDissolved)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('该数据池已解散，当前为只读状态'),
              ),
            for (var i = 0; i < state.memberLabels.length; i++)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${i + 1}. ${state.memberLabels[i]}'),
              ),
            if (state.isOwner && !state.isDissolved)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  children: [
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: SemanticIds.poolEditButton,
                      label: '编辑池信息',
                      button: true,
                      child: OutlinedButton(
                        key: const ValueKey('pool.edit_button'),
                        onPressed: onEditPool,
                        child: const Text('编辑池信息'),
                      ),
                    ),
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: SemanticIds.poolDissolveButton,
                      label: '解散池',
                      button: true,
                      child: OutlinedButton(
                        key: const ValueKey('pool.dissolve_button'),
                        onPressed: onConfirmDissolve,
                        child: const Text('解散池'),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                identifier: SemanticIds.poolLeaveButton,
                label: '退出池',
                button: true,
                child: OutlinedButton(
                  key: const ValueKey('pool.leave_button'),
                  onPressed: state.isDissolved ? null : onConfirmLeave,
                  child: const Text('退出池'),
                ),
              ),
            ),
            if (state.pending.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('待审批请求'),
              ),
            for (final request in state.pending)
              ListTile(
                title: Text(request.displayName),
                subtitle: request.error == null ? null : Text(request.error!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isOwner) ...[
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        identifier: SemanticIds.poolPendingApprove,
                        label: '通过审批',
                        button: true,
                        child: TextButton(
                          onPressed: () => controller.approve(request.id),
                          child: const Text('通过'),
                        ),
                      ),
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        identifier: SemanticIds.poolPendingReject,
                        label: '拒绝审批',
                        button: true,
                        child: TextButton(
                          onPressed: () => controller.reject(request.id),
                          child: const Text('拒绝'),
                        ),
                      ),
                    ] else ...[
                      TextButton(
                        key: const ValueKey('pool.cancel_join_request_button'),
                        onPressed: () =>
                            controller.cancelJoinRequest(request.id),
                        child: const Text('取消申请'),
                      ),
                    ],
                    if (request.error != null)
                      TextButton(
                        onPressed: () => controller.reject(request.id),
                        child: const Text('重试拒绝'),
                      ),
                  ],
                ),
              ),
            if (noticeMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(noticeMessage!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PoolErrorView extends StatelessWidget {
  const _PoolErrorView({
    required this.errorCode,
    required this.onReset,
    required this.onRetrySync,
    required this.onReconnectSync,
  });

  final String errorCode;
  final VoidCallback onReset;
  final Future<void> Function() onRetrySync;
  final Future<void> Function() onReconnectSync;

  @override
  Widget build(BuildContext context) {
    final mapped = mapJoinError(errorCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            buildPoolSyncFeedback(
                  context: context,
                  status: SyncStatus.error(errorCode),
                  onRetrySync: onRetrySync,
                  onReconnectSync: onReconnectSync,
                ) ??
                const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加入失败: ${mapped.message}'),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolErrorPrimaryAction,
              label: mapped.primaryActionLabel,
              button: true,
              child: ElevatedButton(
                key: const ValueKey('pool.error.primary_action'),
                onPressed: onReset,
                child: Text(mapped.primaryActionLabel),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('查看排查建议: $errorCode')));
              },
              child: const Text('查看排查建议'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolExitPartialCleanupView extends StatelessWidget {
  const _PoolExitPartialCleanupView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('部分清理失败')),
            ElevatedButton(onPressed: onRetry, child: const Text('重试清理')),
          ],
        ),
      ),
    );
  }
}
