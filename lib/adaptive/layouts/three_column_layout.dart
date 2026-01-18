import 'package:flutter/material.dart';

/// 桌面端三栏布局
///
/// 左侧栏：设备管理和设置
/// 右侧栏：笔记列表和搜索
class ThreeColumnLayout extends StatelessWidget {
  const ThreeColumnLayout({
    super.key,
    required this.leftColumn,
    required this.rightColumn,
    this.leftColumnWidth = 320.0,
  });

  /// 左侧栏内容
  final Widget leftColumn;

  /// 右侧栏内容
  final Widget rightColumn;

  /// 左侧栏宽度
  final double leftColumnWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧栏
        SizedBox(
          width: leftColumnWidth,
          child: leftColumn,
        ),

        const SizedBox(width: 24),

        // 右侧栏（占据剩余空间）
        Expanded(
          child: rightColumn,
        ),
      ],
    );
  }
}
