/// # 设置页面
///
/// 应用设置模块的主界面，当前为占位实现。
/// 未来版本将在此页面提供应用配置选项。
///
/// ## 关联路由
/// - 跳转至此页面需使用 `Navigator.pushNamed(context, '/settings')`。
///
/// ## 外部依赖
/// - 依赖 [SemanticIds] 提供语义标识符支持无障碍测试。
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:flutter/material.dart';

/// 设置页面的 StatelessWidget。
///
/// 当前为空白占位页，仅显示一个可扩展的空白区域。
/// 后续版本将在此添加各类设置选项。
class SettingsPage extends StatelessWidget {
  /// 创建设置页面实例。
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        identifier: SemanticIds.settingsPage,
        label: '设置页',
        child: const SizedBox.expand(key: ValueKey('settings.page')),
      ),
    );
  }
}
