/// # 数据池页面
///
/// 负责数据池的界面展示与用户交互处理。
/// 支持创建池、扫码加入、成员审批、退出池等功能。
///
/// ## 外部依赖
/// - 依赖 [PoolController] 提供状态管理和业务逻辑。
/// - 依赖 [SyncService] 提供同步状态管理。
library pool_page;

import 'dart:async';

import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 数据池页面组件。
///
/// 根据当前状态渲染不同的页面分支，处理扫码加入、成员审批、
/// 错误处理与退池流程展示。
class PoolPage extends StatefulWidget {
  /// 创建数据池页面。
  ///
  /// [state] - 初始池状态。
  /// [networkId] - 可选的网络ID。
  /// [controller] - 可选的控制器，用于依赖注入测试。
  /// [onReturnToPoolTab] - 返回数据池Tab的回调。
  const PoolPage({
    super.key,
    required this.state,
    this.networkId,
    this.controller,
    this.onReturnToPoolTab,
  });

  /// 当前池状态。
  final PoolState state;

  /// 网络ID，用于同步服务。
  final BigInt? networkId;

  /// 可选的控制器实例。
  final PoolController? controller;

  /// 返回数据池Tab的回调函数。
  final VoidCallback? onReturnToPoolTab;

  @override
  State<PoolPage> createState() => _PoolPageState();
}

class _PoolPageState extends State<PoolPage> {
  late final PoolController _controller =
      (widget.controller ??
            PoolController(
              initialState: widget.state,
              apiClient: FrbPoolApiClient(
                endpointId: '${defaultTargetPlatform.name}@local-device',
                nickname: '${defaultTargetPlatform.name}-user',
                os: defaultTargetPlatform.name,
              ),
              syncService: widget.networkId == null
                  ? null
                  : SyncService(
                      gateway: FrbSyncGateway(),
                      networkId: widget.networkId!,
                    ),
              reconnectTarget: '${defaultTargetPlatform.name}@local-device',
            ))
        ..addListener(_onStateChanged);

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _returnToPoolTab() {
    widget.onReturnToPoolTab?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final canShowReturnToPool =
        widget.onReturnToPoolTab != null || Navigator.of(context).canPop();
    final syncFeedback = _buildLocalSyncFeedback(
      context,
      _controller.syncStatus,
    );

    if (state is PoolNotJoined) {
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
                          onPressed: _controller.joining
                              ? null
                              : _controller.createPool,
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
                          onPressed: _controller.joining
                              ? null
                              : () => _scanAndJoin(context),
                          child: const Text('扫码加入'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const ValueKey('pool.submit_join_request_button'),
                        onPressed: _controller.joining
                            ? null
                            : () {
                                unawaited(_controller.submitJoinRequest());
                              },
                        child: const Text('提交加入申请'),
                      ),
                      if (_controller.joining)
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

    if (state is PoolJoined) {
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
                    onPressed: _returnToPoolTab,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('返回数据池Tab'),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(16),
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
                          onPressed: () => _showEditPoolDialog(context),
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
                          onPressed: () => _confirmDissolvePool(context),
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
                    onPressed: state.isDissolved
                        ? null
                        : () => _confirmLeavePool(context),
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
                            onPressed: () => _controller.approve(request.id),
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
                            onPressed: () => _controller.reject(request.id),
                            child: const Text('拒绝'),
                          ),
                        ),
                      ] else ...[
                        TextButton(
                          key: const ValueKey(
                            'pool.cancel_join_request_button',
                          ),
                          onPressed: () =>
                              _controller.cancelJoinRequest(request.id),
                          child: const Text('取消申请'),
                        ),
                      ],
                      if (request.error != null)
                        TextButton(
                          onPressed: () => _controller.reject(request.id),
                          child: const Text('重试拒绝'),
                        ),
                    ],
                  ),
                ),
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: _controller.simulateRejectFailurePending,
                    child: const Text('模拟失败请求'),
                  ),
                ),
              if (state.approvalMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.approvalMessage!),
                ),
            ],
          ),
        ),
      );
    }

    if (state is PoolError) {
      final errorCode = state.code;
      final mapped = mapJoinError(errorCode);
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildLocalSyncFeedback(context, SyncStatus.error(errorCode)) ??
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
                  onPressed: () {
                    _controller.setState(const PoolState.notJoined());
                  },
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

    if (state is PoolExitPartialCleanup) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('部分清理失败')),
              ElevatedButton(
                onPressed: _controller.retryCleanup,
                child: const Text('重试清理'),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(body: SizedBox.shrink());
  }

  Future<void> _scanAndJoin(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('扫码加入'),
          content: const Text('使用模拟加入码：ok / admin-offline / timeout'),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolScanDialogSuccess,
              label: '模拟成功加入',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.scan_dialog.success'),
                onPressed: () => Navigator.of(dialogContext).pop('ok'),
                child: const Text('模拟成功'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolScanDialogAdminOffline,
              label: '管理员离线加入码',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.scan_dialog.admin_offline'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop('admin-offline'),
                child: const Text('管理员离线'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolScanDialogTimeout,
              label: '请求超时加入码',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.scan_dialog.timeout'),
                onPressed: () => Navigator.of(dialogContext).pop('timeout'),
                child: const Text('请求超时'),
              ),
            ),
          ],
        );
      },
    );

    if (code == null) return;
    unawaited(_controller.joinByCode(code));
  }

  Future<void> _confirmLeavePool(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: const Text('退出后会移除池关联数据，确认退出吗？'),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolLeaveDialogCancel,
              label: '取消退出数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.leave_dialog.cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolLeaveDialogConfirm,
              label: '确认退出数据池',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.leave_dialog.confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认退出'),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    unawaited(
      Future<void>(() {
        _controller.confirmExit();
      }),
    );
  }

  Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required String content,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(content),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: confirmLabel == '确认解散'
                  ? SemanticIds.poolDissolveDialogCancel
                  : SemanticIds.poolLeaveDialogCancel,
              label: confirmLabel == '确认解散' ? '取消解散数据池' : '取消',
              button: true,
              child: TextButton(
                key: ValueKey(
                  confirmLabel == '确认解散'
                      ? 'pool.dissolve_dialog.cancel'
                      : 'pool.confirm_dialog.cancel',
                ),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: confirmLabel == '确认解散'
                  ? SemanticIds.poolDissolveDialogConfirm
                  : SemanticIds.poolLeaveDialogConfirm,
              label: confirmLabel == '确认解散' ? '确认解散数据池' : confirmLabel,
              button: true,
              child: TextButton(
                key: ValueKey(
                  confirmLabel == '确认解散'
                      ? 'pool.dissolve_dialog.confirm'
                      : 'pool.confirm_dialog.confirm',
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showEditPoolDialog(BuildContext context) async {
    final state = _controller.state;
    if (state is! PoolJoined) return;

    var draftName = state.poolName;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑池信息'),
          content: Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: SemanticIds.poolEditDialogNameInput,
            label: '池名称输入框',
            textField: true,
            child: TextFormField(
              key: const ValueKey('pool.edit_dialog.name_input'),
              initialValue: state.poolName,
              onChanged: (value) {
                draftName = value;
              },
            ),
          ),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolEditDialogCancel,
              label: '取消编辑池信息',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.edit_dialog.cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.poolEditDialogSave,
              label: '保存池信息',
              button: true,
              child: TextButton(
                key: const ValueKey('pool.edit_dialog.save'),
                onPressed: () => Navigator.of(dialogContext).pop(draftName),
                child: const Text('保存'),
              ),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    _controller.editPoolInfo(name.trim());
  }

  Future<void> _confirmDissolvePool(BuildContext context) async {
    final confirmed = await _showConfirmationDialog(
      context: context,
      content: '确认解散该数据池？',
      confirmLabel: '确认解散',
    );

    if (confirmed) {
      _controller.dissolvePool();
    }
  }

  Widget? _buildLocalSyncFeedback(BuildContext context, SyncStatus status) {
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
                onPressed: _controller.retrySync,
                child: const Text('重试同步'),
              ),
              TextButton(
                key: const ValueKey('pool.sync.reconnect'),
                onPressed: _controller.reconnectSync,
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
      case 'samePath': // Phase 2: 支持新的枚举命名
        return '同步状态降级：仍在同一条延续路径';
      case 'path_at_risk':
      case 'pathAtRisk': // Phase 2: 支持新的枚举命名
        return '同步状态降级：延续路径有风险';
      case 'path_broken':
      case 'pathBroken': // Phase 2: 支持新的枚举命名
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
}
