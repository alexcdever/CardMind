import 'dart:async';

import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

/// 轻量顶级同步状态条组件。
///
/// 根据 [SyncStatus] 的类型渲染不同的同步状态提示条。
/// 支持以下状态渲染：
/// - syncing/connecting：信息色背景 + sync 图标 + 待同步数量 + 小 CircularProgressIndicator
/// - error/degraded：错误色背景 + 状态文案 + "查看"按钮
/// - connected/idle：成功色背景 + "全部已同步"，2 秒后自动消退
/// - idle（从未显示过）：不渲染
class GlobalSyncIndicator extends StatefulWidget {
  /// 创建全局同步状态指示器。
  ///
  /// [syncStatus] - 当前同步状态
  /// [pendingCount] - 待同步条目数量，默认 0
  /// [onViewDetails] - 点击"查看"按钮的回调
  const GlobalSyncIndicator({
    super.key,
    required this.syncStatus,
    this.pendingCount = 0,
    this.onViewDetails,
  });

  /// 当前同步状态。
  final SyncStatus syncStatus;

  /// 待同步条目数量。
  final int pendingCount;

  /// 点击"查看"按钮的回调。
  final VoidCallback? onViewDetails;

  @override
  State<GlobalSyncIndicator> createState() => _GlobalSyncIndicatorState();
}

class _GlobalSyncIndicatorState extends State<GlobalSyncIndicator> {
  /// 自动消退计时器。
  Timer? _dismissTimer;

  /// 是否从未显示过（用于 idle 状态首次判断）。
  bool _everShown = false;

  /// 当前是否可见（受自动消退控制）。
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _everShown = _shouldShow(widget.syncStatus);
    _visible = _everShown;
  }

  @override
  void didUpdateWidget(covariant GlobalSyncIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当同步状态从非 connected/idle 切换到 connected/idle 时，启动自动消退计时器
    final oldShouldShow = _shouldShow(oldWidget.syncStatus);
    final newShouldShow = _shouldShow(widget.syncStatus);

    if (newShouldShow) {
      _everShown = true;
      _visible = true;
    }

    if (!oldShouldShow &&
        newShouldShow &&
        (widget.syncStatus.kind == SyncStatusKind.connected ||
            widget.syncStatus.kind == SyncStatusKind.idle)) {
      _startDismissTimer();
    }

    // 如果从 connected/idle 切换到其他状态，取消消退计时器
    if ((oldWidget.syncStatus.kind == SyncStatusKind.connected ||
            oldWidget.syncStatus.kind == SyncStatusKind.idle) &&
        widget.syncStatus.kind != SyncStatusKind.connected &&
        widget.syncStatus.kind != SyncStatusKind.idle) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  /// 启动 2 秒后自动消退的计时器。
  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _visible = false;
      });
    });
  }

  /// 判断当前同步状态是否应该显示。
  bool _shouldShow(SyncStatus status) {
    return status.kind != SyncStatusKind.idle;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.syncStatus;

    // idle 且从未显示过：不渲染
    if (status.kind == SyncStatusKind.idle && !_everShown) {
      return const SizedBox.shrink();
    }

    // 消退后不渲染
    if (!_visible && _everShown &&
        (status.kind == SyncStatusKind.connected ||
            status.kind == SyncStatusKind.idle)) {
      return const SizedBox.shrink();
    }

    return _buildIndicator(status);
  }

  Widget _buildIndicator(SyncStatus status) {
    switch (status.kind) {
      case SyncStatusKind.syncing:
      case SyncStatusKind.connecting:
        return _buildInfoBar();
      case SyncStatusKind.error:
        return _buildErrorBar('同步异常');
      case SyncStatusKind.degraded:
        return _buildErrorBar('同步降级');
      case SyncStatusKind.connected:
      case SyncStatusKind.idle:
      case SyncStatusKind.queryConvergencePending:
        return _buildSuccessBar();
    }
  }

  Widget _buildInfoBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFE8F4FD),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 16, color: Color(0xFF0065A2)),
          const SizedBox(width: 8),
          Text(
            widget.pendingCount > 0
                ? '正在同步… ${widget.pendingCount} 条待同步'
                : '正在同步…',
            style: const TextStyle(
              color: Color(0xFF0065A2),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0065A2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFDEDED),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC62828),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (widget.onViewDetails != null)
            GestureDetector(
              onTap: widget.onViewDetails,
              child: const Text(
                '查看',
                style: TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFE8F5E9),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          const Text(
            '全部已同步',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
