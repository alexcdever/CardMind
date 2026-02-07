/// 同步状态图标组件（带旋转动画）
library;

import 'package:flutter/material.dart';
import '../utils/sync_dialog_constants.dart';

/// 同步状态图标
///
/// 根据同步状态显示不同的图标和颜色
/// 同步中时会显示旋转动画
class SyncStatusIcon extends StatefulWidget {
  const SyncStatusIcon({
    super.key,
    required this.status,
    this.size = SyncDialogIconSize.status,
  });

  /// 同步状态
  final String status;

  /// 图标大小
  final double size;

  @override
  State<SyncStatusIcon> createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends State<SyncStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: SyncDialogDuration.rotation,
      vsync: this,
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(SyncStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _updateAnimation() {
    if (_isSyncing) {
      _rotationController.repeat();
    } else {
      _rotationController
        ..stop()
        ..reset();
    }
  }

  bool get _isSyncing => widget.status.toLowerCase() == 'syncing';

  IconData get _icon {
    switch (widget.status.toLowerCase()) {
      case 'syncing':
        return Icons.sync;
      case 'synced':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'idle':
      default:
        return Icons.cloud_done;
    }
  }

  Color get _color {
    switch (widget.status.toLowerCase()) {
      case 'syncing':
        return SyncDialogColor.syncing;
      case 'synced':
        return SyncDialogColor.success;
      case 'failed':
        return SyncDialogColor.error;
      case 'idle':
      default:
        return SyncDialogColor.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_icon, size: widget.size, color: _color);

    if (_isSyncing) {
      return RotationTransition(turns: _rotationController, child: icon);
    }

    return icon;
  }
}
