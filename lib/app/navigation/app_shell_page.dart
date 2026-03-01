// input: 使用 AppShellController 当前分区状态驱动子页面与导航切换。
// output: 通过 AdaptiveShell 渲染 cards/pool/settings 三个主工作区页面。
// pos: 应用主工作台页面，负责跨功能导航壳与分区内容编排。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
import 'package:cardmind/app/layout/adaptive_shell.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_shell_controller.dart';
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, this.controller});

  final AppShellController? controller;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late final AppShellController _controller =
      (widget.controller ?? AppShellController())..addListener(_onChanged);

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
      child: AdaptiveShell(
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
    SystemNavigator.pop();
  }

  Widget _buildSection(AppSection section) {
    switch (section) {
      case AppSection.cards:
        return const CardsPage();
      case AppSection.pool:
        return const PoolPage(state: PoolState.notJoined());
      case AppSection.settings:
        return const SettingsPage();
    }
  }
}
