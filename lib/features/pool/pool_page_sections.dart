part of 'pool_page.dart';

class _PoolNotJoinedView extends StatelessWidget {
  const _PoolNotJoinedView({
    required this.controller,
    required this.syncStatus,
    required this.onScanJoin,
    required this.noticeMessage,
  });

  final PoolController controller;
  final SyncStatus syncStatus;
  final VoidCallback onScanJoin;
  final String? noticeMessage;

  @override
  Widget build(BuildContext context) {
    final syncFeedback = buildPoolSyncFeedback(
      context: context,
      status: syncStatus,
      onRetrySync: controller.retrySync,
      onReconnectSync: controller.reconnectSync,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncFeedback ?? const SizedBox.shrink(),
              const _PoolBrandHeader(statusText: 'SYNC READY'),
              const SizedBox(height: 18),
              const _SoftLabel(text: 'CONNECTIVITY HUB'),
              const SizedBox(height: 10),
              const Text(
                '在这里创建或加入数据池',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Digital Atrium Awaits.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF223233),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '创建一个私有协作空间，或通过邀请字符串同步到已有数据池。',
                style: TextStyle(color: Color(0xFF5F7274), height: 1.45),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryActionButton(
                      label: '创建池',
                      semanticIdentifier: SemanticIds.poolCreateButton,
                      buttonKey: const ValueKey('pool.create_button'),
                      onPressed: controller.joining
                          ? null
                          : controller.createPool,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryActionButton(
                      label: '扫码加入',
                      semanticIdentifier: SemanticIds.poolJoinScanButton,
                      buttonKey: const ValueKey('pool.join_scan_button'),
                      onPressed: controller.joining ? null : onScanJoin,
                    ),
                  ),
                ],
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
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(noticeMessage!),
                ),
              const SizedBox(height: 16),
              _ActionPanel(
                icon: Icons.add,
                title: 'Create Data Pool',
                body:
                    'Start a fresh decentralized pool. You will become the first admin.',
                actionLabel: 'Get Started',
                semanticIdentifier: SemanticIds.poolCreateButton,
                actionKey: const ValueKey('pool.create_button.secondary'),
                onPressed: controller.joining ? null : controller.createPool,
                filled: true,
              ),
              const SizedBox(height: 16),
              _ActionPanel(
                icon: Icons.link,
                title: 'Join Data Pool',
                body:
                    'Connect to an existing pool using an invite string from another device.',
                actionLabel: 'Connect Now',
                semanticIdentifier: SemanticIds.poolJoinScanButton,
                actionKey: const ValueKey('pool.join_scan_button.secondary'),
                onPressed: controller.joining ? null : onScanJoin,
              ),
            ],
          ),
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

    final runtimeView = controller.runtimeView;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncFeedback ?? const SizedBox.shrink(),
              if (canShowReturnToPool)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onReturnToPool,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('返回数据池Tab'),
                  ),
                ),
              const _PoolBrandHeader(statusText: 'DATA POOL'),
              const SizedBox(height: 18),
              const Text(
                'Network Nodes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF223233),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.poolName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Real-time status of ${state.poolName}.',
                style: const TextStyle(color: Color(0xFF5F7274)),
              ),
              const SizedBox(height: 16),
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(noticeMessage!),
                ),
              if (state.isDissolved)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('该数据池已解散，当前为只读状态'),
                ),
              if (state.isOwner && !state.isDissolved)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
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
              Semantics(
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
              if (state.pending.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
                  child: Text('待审批请求'),
                ),
              for (final request in state.pending)
                _PendingRequestTile(
                  request: request,
                  isOwner: state.isOwner,
                  controller: controller,
                ),
              _InfoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我的身份: ${state.currentIdentityLabel}'),
                    const SizedBox(height: 10),
                    const Text(
                      '成员列表',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < state.memberLabels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${i + 1}. ${state.memberLabels[i]}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SummaryStrip(
                runtimeView: runtimeView,
                loading: controller.runtimeViewLoading,
              ),
              const SizedBox(height: 16),
              if (runtimeView != null)
                for (final member in runtimeView.members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RuntimeMemberTile(member: member),
                  ),
              if (state.isOwner)
                _InvitePanel(
                  stateInviteCode: state.inviteCode,
                  runtimeView: runtimeView,
                  onCreateInvite: () => controller.createInvite(),
                  onRevokeInvite: (inviteId) =>
                      controller.revokeInvite(inviteId),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.semanticIdentifier,
    required this.buttonKey,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final String semanticIdentifier;
  final Key buttonKey;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = filled
        ? FilledButton(key: buttonKey, onPressed: onPressed, child: Text(label))
        : OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            child: Text(label),
          );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: semanticIdentifier,
      label: label,
      button: true,
      child: child,
    );
  }
}

class _PoolBrandHeader extends StatelessWidget {
  const _PoolBrandHeader({required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF087B78)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'The Atrium',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A6462),
            ),
          ),
        ),
        _SoftLabel(text: statusText),
      ],
    );
  }
}

class _SoftLabel extends StatelessWidget {
  const _SoftLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD8F5EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF087B78),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.semanticIdentifier,
    required this.actionKey,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final String semanticIdentifier;
  final Key actionKey;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton(
            key: actionKey,
            onPressed: onPressed,
            child: Text(actionLabel),
          )
        : OutlinedButton(
            key: actionKey,
            onPressed: onPressed,
            child: Text(actionLabel),
          );
    return _InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBlock(icon: icon),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Color(0xFF5F7274))),
          const SizedBox(height: 18),
          Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: semanticIdentifier,
            label: actionLabel,
            button: true,
            child: button,
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFBDF1E7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: const Color(0xFF087B78)),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.runtimeView, required this.loading});

  final PoolRuntimeViewData? runtimeView;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final summary = runtimeView?.summary;
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'ACTIVE NODES',
            value: loading ? '...' : summary?.memberCountText ?? '0 nodes',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'SYNC STATE',
            value: loading ? '...' : summary?.runtimeStatusText ?? 'unknown',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5F7274),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RuntimeMemberTile extends StatelessWidget {
  const _RuntimeMemberTile({required this.member});

  final PoolMemberRuntimeData member;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      child: Row(
        children: [
          _IconBlock(icon: Icons.devices_other),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${member.os} · ${member.role} · ${member.endpointId}',
                  style: const TextStyle(
                    color: Color(0xFF5F7274),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _SoftLabel(text: member.status.toUpperCase()),
        ],
      ),
    );
  }
}

class _InvitePanel extends StatelessWidget {
  const _InvitePanel({
    required this.stateInviteCode,
    required this.runtimeView,
    required this.onCreateInvite,
    required this.onRevokeInvite,
  });

  final String? stateInviteCode;
  final PoolRuntimeViewData? runtimeView;
  final Future<void> Function() onCreateInvite;
  final Future<void> Function(String inviteId) onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final invites = runtimeView?.invites ?? const <PoolInviteData>[];
    final hasRuntimeStateInvite = invites.any(
      (invite) => invite.inviteCode == stateInviteCode,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: _InfoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '邀请字符串',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(onCreateInvite()),
                  child: const Text('生成'),
                ),
              ],
            ),
            if (stateInviteCode != null && !hasRuntimeStateInvite) ...[
              const SizedBox(height: 8),
              SelectableText(
                stateInviteCode!,
                key: const ValueKey('pool.invite_code'),
              ),
            ],
            for (final invite in invites) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      invite.inviteCode,
                      key: invite.inviteCode == stateInviteCode
                          ? const ValueKey('pool.invite_code')
                          : null,
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(onRevokeInvite(invite.inviteId)),
                    child: const Text('撤销'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.request,
    required this.isOwner,
    required this.controller,
  });

  final PoolPendingRequest request;
  final bool isOwner;
  final PoolController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(request.displayName),
      subtitle: request.error == null ? null : Text(request.error!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
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
              onPressed: () => controller.cancelJoinRequest(request.id),
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
    );
  }
}

class _PoolJoinPendingView extends StatelessWidget {
  const _PoolJoinPendingView({
    required this.state,
    required this.controller,
    required this.syncStatus,
    required this.noticeMessage,
    required this.onCancelJoinRequest,
  });

  final PoolJoinPending state;
  final PoolController controller;
  final SyncStatus syncStatus;
  final String? noticeMessage;
  final Future<void> Function() onCancelJoinRequest;

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.poolName),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('加入申请处理中'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.applicantIdentityLabel),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                key: const ValueKey('pool.cancel_join_request_button'),
                onPressed: onCancelJoinRequest,
                child: const Text('取消申请'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(noticeMessage ?? '加入申请已提交，等待管理员审批'),
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
