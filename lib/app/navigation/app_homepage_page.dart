// input: 使用 AppHomepageController 当前分区状态驱动子页面与导航切换。
// output: 通过 AdaptiveHomepageScaffold 渲染 cards/pool/settings 三个主工作区页面。
// pos: 应用主页页面，负责跨功能导航与分区内容编排。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用主页模块，负责导航与跨端布局。
import 'package:cardmind/app/layout/adaptive_homepage_scaffold.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_homepage_controller.dart';
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppHomepagePage extends StatefulWidget {
  const AppHomepagePage({super.key, this.controller});

  final AppHomepageController? controller;

  @override
  State<AppHomepagePage> createState() => _AppHomepagePageState();
}

class _AppHomepagePageState extends State<AppHomepagePage> {
  late final AppHomepageController _controller =
      (widget.controller ?? AppHomepageController())..addListener(_onChanged);
  bool _isExitDialogShowing = false;

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

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

  Widget _buildSection(AppSection section) {
    switch (section) {
      case AppSection.cards:
        return const CardsPage();
      case AppSection.pool:
        return PoolPage(
          state: const PoolState.notJoined(),
          onGoToCards: () {
            _controller.setSection(AppSection.cards);
          },
        );
      case AppSection.settings:
        return const SettingsPage();
    }
  }
}
