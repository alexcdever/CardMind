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
import 'dart:io';

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
    this.appDataDir = '',
    this.networkId,
    this.controller,
    this.onReturnToPoolTab,
    this.autoJoinCode,
    this.autoCreatePool = false,
    this.debugExportInvitePath,
    this.debugStatusExportPath,
  });

  /// 当前池状态。
  final PoolState state;

  /// 应用数据目录，用于懒初始化运行态网络与端点身份。
  final String appDataDir;

  /// 网络ID，用于同步服务。
  final BigInt? networkId;

  /// 可选的控制器实例。
  final PoolController? controller;

  /// 返回数据池Tab的回调函数。
  final VoidCallback? onReturnToPoolTab;

  /// 调试用自动加入码，仅在显式注入时使用。
  final String? autoJoinCode;

  /// 调试用自动创建池开关，仅在显式注入时使用。
  final bool autoCreatePool;

  /// 调试用 invite 导出路径，仅在显式注入时使用。
  final String? debugExportInvitePath;

  /// 调试用状态导出路径，仅在显式注入时使用。
  final String? debugStatusExportPath;

  @override
  State<PoolPage> createState() => _PoolPageState();
}

class _PoolPageState extends State<PoolPage> {
  late final PoolController _controller =
      (widget.controller ??
            PoolController(
              initialState: widget.state,
              apiClient: FrbPoolApiClient(
                nickname: '${defaultTargetPlatform.name}-user',
                os: defaultTargetPlatform.name,
                appDataDir: widget.appDataDir,
                networkId: widget.networkId,
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
  bool _autoJoinTriggered = false;
  bool _autoCreateTriggered = false;
  bool _inviteExportTriggered = false;
  String? _lastDebugStateMarker;

  @override
  void initState() {
    super.initState();
    _maybeAutoJoin();
    _maybeExportInvite();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
    _maybeAutoJoin();
    _maybeExportInvite();
    _maybeExportState();
  }

  void _maybeAutoJoin() {
    _maybeAutoCreatePool();
    final code = widget.autoJoinCode?.trim();
    if (_autoJoinTriggered || code == null || code.isEmpty) {
      return;
    }
    if (_controller.state is! PoolNotJoined || _controller.joining) {
      return;
    }
    _autoJoinTriggered = true;
    unawaited(_appendDebugStatus('auto_join_triggered'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_controller.joinByCode(code));
    });
  }

  void _maybeAutoCreatePool() {
    if (_autoCreateTriggered || !widget.autoCreatePool) {
      return;
    }
    if (_controller.state is! PoolNotJoined || _controller.joining) {
      return;
    }
    _autoCreateTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_controller.createPool());
    });
  }

  void _maybeExportState() {
    final state = _controller.state;
    final marker = switch (state) {
      PoolJoined joined => 'joined:${joined.poolId}',
      PoolError error =>
        'join_error:${error.code}:${_controller.noticeMessage ?? ''}',
      PoolNotJoined() => 'not_joined',
      PoolExitPartialCleanup() => 'exit_partial_cleanup',
    };
    if (_lastDebugStateMarker == marker) {
      return;
    }
    _lastDebugStateMarker = marker;
    unawaited(_appendDebugStatus(marker));
  }

  void _maybeExportInvite() {
    if (_inviteExportTriggered) {
      return;
    }
    final exportPath = widget.debugExportInvitePath?.trim();
    final state = _controller.state;
    if (exportPath == null || exportPath.isEmpty || state is! PoolJoined) {
      return;
    }
    final inviteCode = state.inviteCode?.trim();
    if (inviteCode == null || inviteCode.isEmpty) {
      return;
    }
    _inviteExportTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_writeInvite(exportPath, inviteCode));
    });
  }

  Future<void> _writeInvite(String exportPath, String inviteCode) async {
    try {
      final file = File(exportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(inviteCode);
    } catch (_) {
      // 调试导出失败不应影响页面主流程。
    }
  }

  Future<void> _appendDebugStatus(String line) async {
    final path = widget.debugStatusExportPath?.trim();
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {
      // 调试状态导出失败不应影响页面主流程。
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
        noticeMessage: _controller.noticeMessage,
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
