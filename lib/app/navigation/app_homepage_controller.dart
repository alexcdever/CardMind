/// # 应用主页控制器
///
/// 应用主页导航控制器，负责主工作台分区状态管理。
///
/// ## 主要功能
/// - 接收分区切换动作，更新当前 [AppSection] 导航状态
/// - 暴露当前 section 并在切换后通知监听者刷新界面
/// - 继承自 [ChangeNotifier]，支持状态监听模式
///
/// ## 使用示例
/// ```dart
/// final controller = AppHomepageController(initialSection: AppSection.cards);
/// controller.addListener(() {
///   // 响应状态变化
/// });
/// controller.setSection(AppSection.pool);
/// ```
///
/// ## 外部依赖
/// - 依赖 [AppSection] 枚举定义可用的导航分区
library app_homepage_controller;

import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/foundation.dart';

/// 应用主页导航控制器。
///
/// 管理应用主页的当前分区状态，并在状态变化时通知监听者。
/// 使用 ChangeNotifier 模式实现响应式状态管理。
class AppHomepageController extends ChangeNotifier {
  /// 构造函数。
  ///
  /// [initialSection] - 初始分区，默认为 [AppSection.cards]
  AppHomepageController({AppSection initialSection = AppSection.cards})
    : _section = initialSection;

  /// 当前分区状态。
  ///
  /// 存储当前选中的导航分区。
  AppSection _section;

  /// 获取当前分区。
  ///
  /// 返回当前选中的 [AppSection] 值。
  AppSection get section => _section;

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
