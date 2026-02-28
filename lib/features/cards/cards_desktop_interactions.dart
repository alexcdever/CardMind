// input: showContextMenu 接收 BuildContext 与全局点击坐标 position。
// output: 调用 showMenu 弹出桌面右键菜单并返回其 Future。
// pos: 卡片桌面交互封装，负责右键上下文菜单展示。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:flutter/material.dart';

class CardsDesktopInteractions {
  const CardsDesktopInteractions();

  Future<void> showContextMenu(BuildContext context, Offset position) {
    return showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: const [PopupMenuItem<void>(value: null, child: Text('删除'))],
    );
  }
}
