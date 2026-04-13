/// # 应用根组件模块
///
/// Flutter 应用主页模块，负责导航与跨端布局。
/// 提供应用的根级配置，包括主题、标题和首屏路由。
///
/// ## 关联路由
/// - 本模块是应用的根组件，不直接参与路由跳转。
/// - 首页由 [AppHomepagePage] 负责渲染。
///
/// ## 外部依赖
/// - 依赖 [AppHomepagePage] 提供首页内容。
import 'package:cardmind/app/navigation/app_homepage_page.dart';
import 'package:flutter/material.dart';

/// 应用根组件。
///
/// [CardMindApp] 是应用的入口组件，继承自 [StatelessWidget]。
/// 负责构建 [MaterialApp] 并配置应用的全局属性，如主题、标题和首页。
class CardMindApp extends StatelessWidget {
  /// 创建应用根组件实例。
  ///
  /// [key] 用于 Widget 树中的标识。
  /// [appDataDir] 应用数据目录路径，默认为空字符串。
  const CardMindApp({
    super.key,
    this.appDataDir = '',
    this.debugStartInPool = false,
    this.debugAutoPin,
    this.debugAutoJoinCode,
    this.debugAutoCreatePool = false,
    this.debugExportInvitePath,
    this.debugStatusExportPath,
  });

  /// 应用数据目录路径。
  ///
  /// 用于存储应用持久化数据，由 main() 函数初始化时通过
  /// [path_provider] 获取并传递给本组件。
  final String appDataDir;
  final bool debugStartInPool;
  final String? debugAutoPin;
  final String? debugAutoJoinCode;
  final bool debugAutoCreatePool;
  final String? debugExportInvitePath;
  final String? debugStatusExportPath;

  /// 构建应用 Widget 树。
  ///
  /// 返回配置好的 [MaterialApp]，包含：
  /// - 应用标题：'CardMind'
  /// - 主题：使用 Material 3 设计规范
  /// - 首页：[AppHomepagePage]，接收 [poolNetworkId] 参数
  ///
  /// [context] 构建上下文，提供对 Flutter 框架的访问。
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardMind',
      theme: ThemeData(useMaterial3: true),
      home: AppHomepagePage(
        appDataDir: appDataDir,
        debugStartInPool: debugStartInPool,
        debugAutoPin: debugAutoPin,
        debugAutoJoinCode: debugAutoJoinCode,
        debugAutoCreatePool: debugAutoCreatePool,
        debugExportInvitePath: debugExportInvitePath,
        debugStatusExportPath: debugStatusExportPath,
      ),
    );
  }
}
