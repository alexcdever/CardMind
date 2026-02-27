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
