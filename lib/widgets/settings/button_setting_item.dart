import 'package:flutter/material.dart';

/// 按钮设置项组件
class ButtonSettingItem extends StatelessWidget {
  const ButtonSettingItem({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.onPressed,
    this.isLoading = false,
  });

  /// 图标
  final IconData icon;

  /// 标签
  final String label;

  /// 描述文本
  final String? description;

  /// 按钮点击回调
  final VoidCallback? onPressed;

  /// 是否显示加载状态
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: description,
      button: true,
      enabled: !isLoading && onPressed != null,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: description != null ? Text(description!) : null,
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: isLoading ? null : onPressed,
        enabled: !isLoading,
      ),
    );
  }
}
