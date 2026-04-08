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

part 'pool_page_dialogs.dart';
part 'pool_page_sections.dart';
part 'pool_sync_feedback.dart';

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

    if (state is PoolNotJoined) {
      return _PoolNotJoinedView(
        controller: _controller,
        syncStatus: _controller.syncStatus,
        onScanJoin: () => _scanAndJoin(context),
      );
    }

    if (state is PoolJoined) {
      return _PoolJoinedView(
        state: state,
        controller: _controller,
        syncStatus: _controller.syncStatus,
        canShowReturnToPool: canShowReturnToPool,
        onReturnToPool: _returnToPoolTab,
        onEditPool: () => _showEditPoolDialog(context),
        onConfirmDissolve: () => _confirmDissolvePool(context),
        onConfirmLeave: () => _confirmLeavePool(context),
      );
    }

    if (state is PoolError) {
      return _PoolErrorView(
        errorCode: state.code,
        onReset: () => _controller.setState(const PoolState.notJoined()),
        onRetrySync: _controller.retrySync,
        onReconnectSync: _controller.reconnectSync,
      );
    }

    if (state is PoolExitPartialCleanup) {
      return _PoolExitPartialCleanupView(onRetry: _controller.retryCleanup);
    }

    return const Scaffold(body: SizedBox.shrink());
  }
}
