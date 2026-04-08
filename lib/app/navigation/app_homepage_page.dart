/// # 应用主页页面
///
/// 应用主页页面组件，负责导航与跨端布局。
///
/// ## 主要功能
/// - 使用 [AppHomepageController] 当前分区状态驱动子页面与导航切换
/// - 通过 [AdaptiveHomepageScaffold] 渲染 cards/pool 两个主工作区页面
/// - 处理物理返回键和导航栏的返回意图
/// - 提供退出应用的确认对话框
///
/// ## 关联路由
/// - 跳转至此页面需使用 `Navigator.pushNamed(context, '/home')`
///
/// ## 外部依赖
/// - 依赖 [AppHomepageController] 管理分区导航状态
/// - 依赖 [AdaptiveHomepageScaffold] 提供自适应布局
/// - 依赖 [CardsPage] 和 [PoolPage] 作为内容子页面
import 'package:cardmind/app/layout/adaptive_homepage_scaffold.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_homepage_controller.dart';
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用主页页面组件。
///
/// 这是一个 StatefulWidget，负责管理主页面的状态和生命周期。
/// 支持注入外部控制器和自定义页面构建器，便于测试和扩展。
class AppHomepagePage extends StatefulWidget {
  /// 构造函数。
  ///
  /// [controller] - 可选的外部控制器，用于管理导航状态
  /// [cardsPageBuilder] - 可选的卡片页面构建器，用于自定义或注入 mock
  /// [poolPageBuilder] - 可选的数据池页面构建器，用于自定义或注入 mock
  /// [poolNetworkId] - 数据池网络 ID，用于初始化 PoolPage
  const AppHomepagePage({
    super.key,
    this.controller,
    this.cardsPageBuilder,
    this.poolPageBuilder,
    this.poolNetworkId,
  });

  /// 可选的外部控制器，用于管理导航状态。
  ///
  /// 如果为 null，将自动创建默认控制器。
  final AppHomepageController? controller;

  /// 可选的卡片页面构建器。
  ///
  /// 允许注入自定义页面或 mock，用于测试。
  final WidgetBuilder? cardsPageBuilder;

  /// 可选的数据池页面构建器。
  ///
  /// 允许注入自定义页面或 mock，用于测试。
  final WidgetBuilder? poolPageBuilder;

  /// 数据池网络 ID。
  ///
  /// 用于初始化 PoolPage 时的网络标识。
  final BigInt? poolNetworkId;

  @override
  State<AppHomepagePage> createState() => _AppHomepagePageState();
}

class _AppHomepagePageState extends State<AppHomepagePage> {
  /// 内部控制器实例。
  ///
  /// 优先使用 widget.controller，如果为 null 则创建默认实例。
  /// 添加监听器以响应状态变化。
  late final AppHomepageController _controller =
      (widget.controller ?? AppHomepageController())..addListener(_onChanged);

  /// 退出确认对话框显示状态标记。
  ///
  /// 用于防止同时显示多个退出确认对话框。
  bool _isExitDialogShowing = false;
  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  /// 控制器状态变化回调。
  ///
  /// 当控制器中的分区状态发生变化时调用，触发界面重建。
  void _onChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        _handleBackIntent(didPop);
      },
      child: AdaptiveHomepageScaffold(
        section: _controller.section,
        onSectionChanged: _controller.setSection,
        child: _buildSection(_controller.section),
      ),
    );
  }

  /// 处理返回意图。
  ///
  /// [didPop] - 是否已经执行了 pop 操作
  ///
  /// 如果当前不在卡片分区，则切换到卡片分区；
  /// 如果已经在卡片分区，则显示退出确认对话框。
  void _handleBackIntent(bool didPop) {
    if (didPop) {
      return;
    }
    if (_controller.section != AppSection.cards) {
      _controller.setSection(AppSection.cards);
      return;
    }
    _showExitConfirmDialog();
  }

  /// 显示退出确认对话框。
  ///
  /// 异步显示一个 AlertDialog，询问用户是否退出应用。
  /// 如果用户确认，则调用 SystemNavigator.pop() 退出应用。
  Future<void> _showExitConfirmDialog() async {
    if (_isExitDialogShowing) {
      return;
    }
    _isExitDialogShowing = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('是否退出应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('是'),
          ),
        ],
      ),
    );

    _isExitDialogShowing = false;
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  /// 根据当前分区构建对应的页面内容。
  ///
  /// [section] - 当前选中的分区
  ///
  /// 返回对应分区的 Widget：
  /// - [AppSection.cards]：返回卡片页面
  /// - [AppSection.pool]：返回数据池页面
  Widget _buildSection(AppSection section) {
    switch (section) {
      case AppSection.cards:
        return widget.cardsPageBuilder?.call(context) ?? const CardsPage();
      case AppSection.pool:
        return PoolShell(
          networkId: widget.poolNetworkId,
          child: widget.poolPageBuilder?.call(context),
        );
    }
  }
}
