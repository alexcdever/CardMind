import 'dart:async';

import 'package:cardmind/bridge/frb_generated.dart';
import 'package:cardmind/bridge/api/sync.dart'
    as sync_api;
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';
import 'package:flutter/material.dart';

/// Sync Status Indicator Widget
///
/// 显示同步状态的指示器组件，包括图标、文字和动画
///
/// 规格编号: SP-FLUT-010
/// 功能：
/// - 根据状态显示不同的图标和颜色（Badge 样式）
/// - syncing 状态显示旋转动画（360° 每2秒）
/// - 相对时间显示（10秒内"刚刚"，超过10秒"已同步"）
/// - 点击显示详情对话框
/// - 提供无障碍支持

class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key, required this.status});

  /// 当前同步状态
  final SyncStatus status;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    // 创建旋转动画控制器（2 秒一圈）
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 如果初始状态是 syncing，开始旋转
    _updateAnimation();

    // 如果是 synced 状态且在10秒内，启动相对时间定时器
    _startRelativeTimeTimer();
  }

  @override
  void didUpdateWidget(SyncStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变化时更新动画
    _updateAnimation();

    // 更新相对时间定时器
    _startRelativeTimeTimer();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _relativeTimeTimer?.cancel();
    super.dispose();
  }

  /// 更新动画状态
  void _updateAnimation() {
    if (widget.status.state == SyncState.syncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  /// 启动相对时间定时器
  void _startRelativeTimeTimer() {
    _relativeTimeTimer?.cancel();

    if (widget.status.state == SyncState.synced &&
        widget.status.lastSyncTime != null &&
        _isWithin10Seconds(widget.status.lastSyncTime!)) {
      _relativeTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isWithin10Seconds(widget.status.lastSyncTime!)) {
          _relativeTimeTimer?.cancel();
        }
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  /// 检查是否在10秒内
  bool _isWithin10Seconds(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    return difference.inSeconds <= 10;
  }

  /// 获取状态对应的图标
  IconData _getIcon() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return Icons.cloud_off;
      case SyncState.syncing:
        return Icons.refresh;
      case SyncState.synced:
        return Icons.check;
      case SyncState.failed:
        return Icons.error_outline;
    }
  }

  /// 获取状态对应的颜色
  Color _getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return theme.colorScheme.outline; // 灰色
      case SyncState.syncing:
        return theme.colorScheme.secondary; // 次要色
      case SyncState.synced:
        return const Color(0xFF43A047); // 绿色
      case SyncState.failed:
        return theme.colorScheme.error; // 红色
    }
  }

  /// 获取 Badge 背景颜色
  Color _getBadgeColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return theme.colorScheme.surfaceContainerHighest; // 灰色背景
      case SyncState.syncing:
        return theme.colorScheme.secondaryContainer; // 次要色背景
      case SyncState.synced:
        return Colors.transparent; // 白色边框，透明背景
      case SyncState.failed:
        return theme.colorScheme.errorContainer; // 红色背景
    }
  }

  /// 获取 Badge 边框
  BoxBorder? _getBadgeBorder(BuildContext context) {
    if (widget.status.state == SyncState.synced) {
      return Border.all(color: Theme.of(context).colorScheme.outline, width: 1);
    }
    return null;
  }

  /// 获取状态对应的文字
  String _getText() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return '尚未同步';
      case SyncState.syncing:
        return '同步中...';
      case SyncState.synced:
        if (widget.status.lastSyncTime != null &&
            _isWithin10Seconds(widget.status.lastSyncTime!)) {
          return '刚刚';
        }
        return '已同步';
      case SyncState.failed:
        return '同步失败';
    }
  }

  /// 获取无障碍标签
  String _getSemanticLabel() {
    switch (widget.status.state) {
      case SyncState.notYetSynced:
        return '尚未同步，点击查看详情';
      case SyncState.syncing:
        return '正在同步数据，点击查看详情';
      case SyncState.synced:
        return '已同步，数据最新，点击查看详情';
      case SyncState.failed:
        return '同步失败，点击查看详情并重试';
    }
  }

  /// 显示详情对话框
  Future<void> _showDetailsDialog() async {
    // 获取当前的 API 同步状态
    if (!RustLib.instance.initialized) {
      debugPrint('Rust Bridge 未初始化，无法获取同步状态');
      return;
    }
    try {
      final apiStatus = await sync_api.getSyncStatus();
      if (mounted) {
        await SyncDetailsDialog.show(context, apiStatus);
      }
    } on Exception catch (e) {
      debugPrint('获取同步状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final color = _getColor(context);
    final badgeColor = _getBadgeColor(context);
    final badgeBorder = _getBadgeBorder(context);
    final text = _getText();
    final semanticLabel = _getSemanticLabel();

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: _showDetailsDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            border: badgeBorder,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标（syncing 状态时旋转）
              if (widget.status.state == SyncState.syncing)
                RotationTransition(
                  turns: _rotationController,
                  child: Icon(icon, color: color, size: 16),
                )
              else
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              // 文字
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
