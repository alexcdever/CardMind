/// # 卡片桌面交互
///
/// 封装卡片在桌面端的交互行为，包括右键菜单等功能。
///
/// ## 用途
/// - 提供桌面端特有的交互体验。
/// - 解耦交互逻辑与 UI 组件。
library cards_desktop_interactions;

import 'package:flutter/material.dart';

/// 卡片桌面交互封装类。
///
/// 提供桌面端卡片相关的交互功能，如右键上下文菜单。
class CardsDesktopInteractions {
  /// 创建桌面交互实例。
  const CardsDesktopInteractions();

  /// 显示上下文菜单。
  ///
  /// [context] BuildContext。
  /// [position] 菜单显示位置的全局坐标。
  ///
  /// 返回菜单关闭的 Future。
  Future<void> showContextMenu(BuildContext context, Offset position) {
    return showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: const [PopupMenuItem<void>(value: null, child: Text('删除'))],
    );
  }
}
