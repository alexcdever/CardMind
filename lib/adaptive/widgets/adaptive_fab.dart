import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';

/// 自适应浮动操作按钮
///
/// 仅在移动端显示
class AdaptiveFab extends StatelessWidget {
  const AdaptiveFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  /// 点击回调
  final VoidCallback onPressed;

  /// 按钮内容（通常是图标）
  final Widget child;

  /// 提示文字
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 仅在移动端显示
    if (!PlatformDetector.isMobile) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: child,
    );
  }
}
