import 'package:flutter/material.dart';

/// 信息展示设置项组件
class InfoSettingItem extends StatelessWidget {
  const InfoSettingItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  /// 图标
  final IconData icon;

  /// 标签
  final String label;

  /// 值
  final String value;

  /// 点击回调（可选，用于可点击的信息项）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      button: onTap != null,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
