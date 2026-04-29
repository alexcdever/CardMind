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
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

    final syncFeedback = buildPoolSyncFeedback(
      context: context,
      status: syncStatus,
      onRetrySync: controller.retrySync,
      onReconnectSync: controller.reconnectSync,
    );

    if (desktop) {
      return _buildDesktop(context, syncFeedback);
    }

    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncFeedback ?? const SizedBox.shrink(),
              const _PoolBrandHeader(),
              const SizedBox(height: 18),
              const _SoftLabel(text: '连接中心'),
              const SizedBox(height: 10),
              Text(
                '连接你的数据池',
                style: const TextStyle(
                  color: CardMindColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '在这里创建或加入数据池',
                style: TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _PoolSetupCard(
                icon: Icons.add,
                title: '创建数据池',
                body: '创建一个新的数据池，用于组织本设备与其他设备之间的笔记同步。',
                actionLabel: '创建池',
                onPressed: controller.joining ? null : controller.createPool,
                semanticIdentifier: SemanticIds.poolCreateButton,
                semanticLabel: '创建池',
                filled: true,
              ),
              const SizedBox(height: 16),
              _PoolSetupCard(
                icon: Icons.link,
                title: '加入数据池',
                body: '使用邀请字符串加入已有数据池。',
                actionLabel: '扫码加入',
                onPressed: controller.joining ? null : onScanJoin,
                semanticIdentifier: SemanticIds.poolJoinScanButton,
                semanticLabel: '扫码加入',
                filled: false,
              ),
              if (controller.joining)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '请求处理中...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CardMindColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    noticeMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CardMindColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, Widget? syncFeedback) {
    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncFeedback ?? const SizedBox.shrink(),
              StyledSearchField(
                hintText: '搜索数据池...',
                focusNode: FocusNode(),
                semanticId: 'pool.desktop_search',
                semanticLabel: '搜索数据池',
              ),
              const SizedBox(height: 24),
              const _SoftLabel(text: '初始配置'),
              const SizedBox(height: 18),
              const Text(
                '设置数据池',
                style: TextStyle(
                  color: CardMindColors.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '在这里创建或加入数据池',
                style: TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _PoolSetupCard(
                        icon: Icons.add,
                        title: '创建数据池',
                        body: '创建一个新的数据池，用于组织本设备与其他设备之间的笔记同步。',
                        actionLabel: '创建池',
                        onPressed: controller.joining
                            ? null
                            : controller.createPool,
                        semanticIdentifier: SemanticIds.poolCreateButton,
                        semanticLabel: '创建池',
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _PoolSetupCard(
                        icon: Icons.link,
                        title: '加入数据池',
                        body: '使用邀请字符串加入已有数据池。',
                        actionLabel: '扫码加入',
                        onPressed: controller.joining ? null : onScanJoin,
                        semanticIdentifier: SemanticIds.poolJoinScanButton,
                        semanticLabel: '扫码加入',
                        filled: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '数据池就绪',
                    style: TextStyle(
                      color: CardMindColors.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '本地优先',
                    style: TextStyle(
                      color: CardMindColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (controller.joining)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '请求处理中...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CardMindColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    noticeMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CardMindColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
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
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

    final syncFeedback = buildPoolSyncFeedback(
      context: context,
      status: syncStatus,
      onRetrySync: controller.retrySync,
      onReconnectSync: controller.reconnectSync,
    );

    final runtimeView = controller.runtimeView;
    final memberCount =
        runtimeView?.members.length ?? state.memberLabels.length;

    if (desktop) {
      return _buildDesktop(context, syncFeedback, runtimeView, memberCount);
    }

    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
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
              const _PoolMembersHeader(),
              const SizedBox(height: 18),
              const Text(
                '数据池成员',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: CardMindColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '查看已加入此数据池的设备与成员。',
                style: TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(noticeMessage!),
                ),
              _PoolCollectiveCard(
                poolName: state.poolName,
                memberCount: memberCount,
                isDissolved: state.isDissolved,
                isOwner: state.isOwner,
                onLeave: onConfirmLeave,
              ),
              if (state.pending.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  '待审批请求',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final request in state.pending)
                  _PendingRequestTile(
                    request: request,
                    isOwner: state.isOwner,
                    controller: controller,
                  ),
              ],
              const SizedBox(height: 18),
              _PoolMetricCard(
                icon: Icons.devices_other,
                value: '$memberCount 台',
                label: '成员设备',
              ),
              const SizedBox(height: 18),
              const _MembersSectionHead(),
              Text(
                '我的身份: ${state.currentIdentityLabel}',
                style: const TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (runtimeView != null) ...[
                const SizedBox(height: 8),
                Text(
                  runtimeView.summary.memberCountText,
                  style: const TextStyle(
                    color: CardMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  runtimeView.summary.runtimeStatusText,
                  style: const TextStyle(
                    color: CardMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (runtimeView != null)
                for (final member in runtimeView.members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RuntimeMemberTile(member: member),
                  ),
              if (state.memberLabels.isNotEmpty)
                for (final entry in state.memberLabels.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${entry.$1 + 1}. ${entry.$2}',
                      style: const TextStyle(
                        color: CardMindColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              if (runtimeView != null && runtimeView.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '暂无成员设备',
                    style: TextStyle(
                      color: CardMindColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (state.isOwner && !state.isDissolved)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
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
                ),
              if (state.isDissolved)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    identifier: SemanticIds.poolLeaveButton,
                    label: '退出池',
                    button: true,
                    child: OutlinedButton(
                      key: const ValueKey('pool.leave_button'),
                      onPressed: onConfirmLeave,
                      child: const Text('退出池'),
                    ),
                  ),
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

  Widget _buildDesktop(
    BuildContext context,
    Widget? syncFeedback,
    PoolRuntimeViewData? runtimeView,
    int memberCount,
  ) {
    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 22, 34, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncFeedback ?? const SizedBox.shrink(),
              StyledSearchField(
                hintText: '搜索成员设备...',
                focusNode: FocusNode(),
                semanticId: 'pool.desktop_member_search',
                semanticLabel: '搜索成员设备',
              ),
              const SizedBox(height: 18),
              Text(
                '数据池 / ${state.poolName}',
                style: const TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.poolName,
                          style: const TextStyle(
                            color: CardMindColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$memberCount 台设备已加入',
                          style: const TextStyle(
                            color: CardMindColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (state.isOwner && !state.isDissolved)
                    Row(
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
                        const SizedBox(width: 10),
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
                ],
              ),
              if (state.isDissolved)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '该数据池已解散，当前为只读状态',
                    style: TextStyle(
                      color: CardMindColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (state.isDissolved)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    identifier: SemanticIds.poolLeaveButton,
                    label: '退出池',
                    button: true,
                    child: OutlinedButton(
                      key: const ValueKey('pool.leave_button'),
                      onPressed: onConfirmLeave,
                      child: const Text('退出池'),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(noticeMessage!),
                ),
              const SizedBox(height: 6),
              const Text(
                '成员设备',
                style: TextStyle(
                  color: CardMindColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '我的身份: ${state.currentIdentityLabel}',
                style: const TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (runtimeView != null) ...[
                const SizedBox(height: 8),
                Text(
                  runtimeView.summary.memberCountText,
                  style: const TextStyle(
                    color: CardMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  runtimeView.summary.runtimeStatusText,
                  style: const TextStyle(
                    color: CardMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (runtimeView != null)
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final member in runtimeView.members)
                      SizedBox(
                        width: 280,
                        child: _RuntimeMemberTile(member: member),
                      ),
                  ],
                ),
              if (state.memberLabels.isNotEmpty)
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final entry in state.memberLabels.indexed)
                      SizedBox(
                        width: 280,
                        child: Text(
                          '${entry.$1 + 1}. ${entry.$2}',
                          style: const TextStyle(
                            color: CardMindColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              if (runtimeView != null && runtimeView.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '暂无成员设备',
                    style: TextStyle(
                      color: CardMindColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (state.pending.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  '待审批请求',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                for (final request in state.pending)
                  _PendingRequestTile(
                    request: request,
                    isOwner: state.isOwner,
                    controller: controller,
                  ),
              ],
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

class _PoolMembersHeader extends StatelessWidget {
  const _PoolMembersHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.grid_view_rounded, size: 14, color: CardMindColors.brand),
        SizedBox(width: 8),
        Text(
          'Card Mind',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: CardMindColors.brand,
          ),
        ),
        Spacer(),
        Text(
          '数据池',
          style: TextStyle(
            color: CardMindColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PoolCollectiveCard extends StatelessWidget {
  const _PoolCollectiveCard({
    required this.poolName,
    required this.memberCount,
    required this.isDissolved,
    required this.isOwner,
    required this.onLeave,
  });

  final String poolName;
  final int memberCount;
  final bool isDissolved;
  final bool isOwner;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFCFF6EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据池已创建',
            style: TextStyle(
              color: CardMindColors.brand,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            poolName,
            style: const TextStyle(
              color: CardMindColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$memberCount 台设备已加入',
            style: const TextStyle(
              color: CardMindColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: CardMindColors.brand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '离线',
                    style: TextStyle(
                      color: CardMindColors.textOnBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  identifier: SemanticIds.poolLeaveButton,
                  label: '退出池',
                  button: true,
                  child: GestureDetector(
                    key: const ValueKey('pool.leave_button'),
                    onTap: isDissolved ? null : onLeave,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: CardMindColors.bgCanvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '退出池',
                        style: TextStyle(
                          color: CardMindColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoolMetricCard extends StatelessWidget {
  const _PoolMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: CardMindColors.brandMutedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: CardMindColors.brand),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: CardMindColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: CardMindColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSectionHead extends StatelessWidget {
  const _MembersSectionHead();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 24,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '成员列表',
            style: TextStyle(
              color: CardMindColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PoolSetupCard extends StatelessWidget {
  const _PoolSetupCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.semanticIdentifier,
    this.semanticLabel,
    this.filled = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onPressed;
  final String? semanticIdentifier;
  final String? semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: filled ? CardMindColors.bgSurface : CardMindColors.brandMutedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: CardMindColors.brand),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CardMindColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: CardMindColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: semanticIdentifier,
            label: semanticLabel,
            button: true,
            child: GestureDetector(
              key: semanticIdentifier == null
                  ? null
                  : ValueKey<String>(semanticIdentifier!),
              onTap: onPressed,
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: onPressed != null
                      ? CardMindColors.brand
                      : CardMindColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolBrandHeader extends StatelessWidget {
  const _PoolBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.grid_view_rounded, size: 14, color: CardMindColors.brand),
        SizedBox(width: 8),
        Text(
          'Card Mind',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: CardMindColors.brand,
          ),
        ),
        Spacer(),
        _SoftLabel(text: '数据池'),
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
        color: CardMindColors.brandLightBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: CardMindColors.brand,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
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

class _RuntimeMemberTile extends StatelessWidget {
  const _RuntimeMemberTile({required this.member});

  final PoolMemberRuntimeData member;

  Color _avatarColor() {
    return switch (member.status) {
      'connected' || 'syncing' => const Color(0xFFE1F3F0),
      'disconnected' => const Color(0xFFE5EAEA),
      _ => const Color(0xFFF0F4F4),
    };
  }

  Color _nameColor() {
    return member.status == 'disconnected'
        ? const Color(0xFF6E8183)
        : CardMindColors.textPrimary;
  }

  Color _metaColor() {
    return member.status == 'disconnected'
        ? CardMindColors.textMuted
        : CardMindColors.textSecondary;
  }

  Color _statusColor() {
    return member.status == 'disconnected'
        ? CardMindColors.textMuted
        : CardMindColors.brand;
  }

  Color _bgColor() {
    return member.status == 'disconnected'
        ? CardMindColors.brandMutedBg
        : CardMindColors.bgSurface;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 44,
            decoration: BoxDecoration(
              color: _avatarColor(),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _nameColor(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.isCurrentDevice
                      ? '${member.os} · 本地设备 · 你'
                      : '${member.os} · ${member.role}',
                  style: TextStyle(fontSize: 11, color: _metaColor()),
                ),
              ],
            ),
          ),
          Text(
            member.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _statusColor(),
            ),
          ),
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
