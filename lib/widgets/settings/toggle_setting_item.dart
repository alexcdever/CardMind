import 'package:flutter/material.dart';

/// 开关设置项组件
class ToggleSettingItem extends StatelessWidget {
  const ToggleSettingItem({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    required this.value,
    this.onChanged,
  });

  /// 图标
  final IconData icon;

  /// 标签
  final String label;

  /// 描述文本
  final String? description;

  /// 当前值
  final bool value;

  /// 值改变回调
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: description,
      toggled: value,
      enabled: onChanged != null,
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(label),
        subtitle: description != null ? Text(description!) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
