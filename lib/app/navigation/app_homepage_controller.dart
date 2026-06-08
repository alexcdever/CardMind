/// # 应用主页控制器
///
/// 应用主页导航控制器，负责主工作台分区状态管理以及启动阶段管理。
///
/// ## 主要功能
/// - 接收分区切换动作，更新当前 [AppSection] 导航状态
/// - 暴露当前 section 并在切换后通知监听者刷新界面
/// - 管理应用启动阶段状态（[AppStartupStage]），支持阶段推进
/// - 继承自 [ChangeNotifier]，支持状态监听模式
///
/// ## 使用示例
/// ```dart
/// final controller = AppHomepageController(initialSection: AppSection.cards);
/// controller.addListener(() {
///   // 响应状态变化
/// });
/// controller.setSection(AppSection.pool);
/// controller.advanceStartup(AppStartupStage.ready);
/// ```
///
/// ## 外部依赖
/// - 依赖 [AppSection] 枚举定义可用的导航分区
/// - 依赖 [AppStartupStage] 枚举定义启动阶段
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_startup_state.dart';
import 'package:flutter/foundation.dart';

/// 应用主页导航控制器。
///
/// 管理应用主页的当前分区状态和启动阶段，并在状态变化时通知监听者。
/// 使用 ChangeNotifier 模式实现响应式状态管理。
class AppHomepageController extends ChangeNotifier {
  /// 构造函数。
  ///
  /// [initialSection] - 初始分区，默认为 [AppSection.cards]
  /// [initialStartupStage] - 初始启动阶段，默认为 [AppStartupStage.booting]
  AppHomepageController({
    AppSection initialSection = AppSection.cards,
    AppStartupStage initialStartupStage = AppStartupStage.booting,
  })  : _section = initialSection,
        _startupStage = initialStartupStage;

  /// 当前分区状态。
  ///
  /// 存储当前选中的导航分区。
  AppSection _section;

  /// 当前启动阶段。
  ///
  /// 存储应用当前的启动阶段，从 [AppStartupStage.booting] 开始，
  /// 逐步推进至 [AppStartupStage.ready]。
  AppStartupStage _startupStage;

  /// 当前启动阶段的消息。
  ///
  /// 可选的自定义消息，可在推进阶段时附带说明。
  String? _startupMessage;

  /// 获取当前分区。
  ///
  /// 返回当前选中的 [AppSection] 值。
  AppSection get section => _section;

  /// 获取当前启动阶段。
  ///
  /// 返回当前的 [AppStartupStage] 值。
  AppStartupStage get startupStage => _startupStage;

  /// 获取当前启动阶段的消息。
  ///
  /// 返回可选的启动阶段消息，可能为 null。
  String? get startupMessage => _startupMessage;

  /// 推进启动阶段。
  ///
  /// [stage] - 要推进到的目标启动阶段
  /// [message] - 可选的自定义消息
  ///
  /// 如果目标阶段不高于当前阶段（即退回），则不做任何操作。
  /// 推进成功后，会调用 [notifyListeners] 通知所有监听者。
  void advanceStartup(AppStartupStage stage, {String? message}) {
    if (stage.index <= _startupStage.index) {
      return;
    }
    _startupStage = stage;
    _startupMessage = message;
    notifyListeners();
  }

  /// 设置当前分区。
  ///
  /// [section] - 要切换到的目标分区
  ///
  /// 如果目标分区与当前分区相同，则不执行任何操作。
  /// 切换成功后，会调用 [notifyListeners] 通知所有监听者。
  void setSection(AppSection section) {
    if (_section == section) {
      return;
    }
    _section = section;
    notifyListeners();
  }
}
