import 'package:flutter/material.dart';

import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/widgets/sync_details_dialog.dart';

/// Sync Status Indicator Widget
///
/// 显示同步状态的指示器组件，包括图标、文字和动画
///
/// 规格编号: SP-FLUT-010
/// 功能：
/// - 根据状态显示不同的图标和颜色
/// - syncing 状态显示旋转动画
/// - 点击显示详情对话框
/// - 提供无障碍支持

class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({
    super.key,
    required this.status,
  });

  /// 当前同步状态
  final SyncStatus status;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // 创建旋转动画控制器（2 秒一圈）
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 如果初始状态是 syncing，开始旋转
    if (widget.status.state == SyncState.syncing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(SyncStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变化时更新动画
    if (widget.status.state == SyncState.syncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  /// 获取状态对应的图标
  IconData _getIcon() {
    switch (widget.status.state) {
      case SyncState.disconnected:
        return Icons.cloud_off;
      case SyncState.syncing:
        return Icons.sync;
      case SyncState.synced:
        return Icons.cloud_done;
      case SyncState.failed:
        return Icons.cloud_off;
    }
  }

  /// 获取状态对应的颜色
  Color _getColor() {
    switch (widget.status.state) {
      case SyncState.disconnected:
        return const Color(0xFF757575); // grey
      case SyncState.syncing:
        return const Color(0xFF00897B); // primary color
      case SyncState.synced:
        return const Color(0xFF43A047); // green
      case SyncState.failed:
        return const Color(0xFFFB8C00); // orange
    }
  }

  /// 获取状态对应的文字
  String _getText() {
    switch (widget.status.state) {
      case SyncState.disconnected:
        return '未同步';
      case SyncState.syncing:
        if (widget.status.syncingPeers > 0) {
          return '同步中 (${widget.status.syncingPeers} 台设备)';
        }
        return '同步中...';
      case SyncState.synced:
        if (widget.status.lastSyncTime != null) {
          final relativeTime = _getRelativeTime(widget.status.lastSyncTime!);
          return '已同步 ($relativeTime)';
        }
        return '已同步';
      case SyncState.failed:
        return '同步失败';
    }
  }

  /// 获取相对时间描述
  String _getRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 10) {
      return '刚刚';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds} 秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} 小时前';
    } else {
      return '${difference.inDays} 天前';
    }
  }

  /// 获取无障碍标签
  String _getSemanticLabel() {
    switch (widget.status.state) {
      case SyncState.disconnected:
        return '未同步，无可用设备';
      case SyncState.syncing:
        return '正在同步数据';
      case SyncState.synced:
        return '已同步，数据最新';
      case SyncState.failed:
        return '同步失败，点击查看详情';
    }
  }

  /// 显示详情对话框
  void _showDetailsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => SyncDetailsDialog(status: widget.status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final color = _getColor();
    final text = _getText();
    final semanticLabel = _getSemanticLabel();

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: _showDetailsDialog,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标（syncing 状态时旋转）
              if (widget.status.state == SyncState.syncing)
                RotationTransition(
                  turns: _rotationController,
                  child: Icon(icon, color: color, size: 20),
                )
              else
                Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              // 文字
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
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
