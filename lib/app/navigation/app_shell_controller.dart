// input: 接收分区切换动作，更新当前 AppSection 导航状态。
// output: 暴露当前 section 并在切换后通知监听者刷新界面。
// pos: 应用壳导航控制器，负责主工作台分区状态管理。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/foundation.dart';

class AppShellController extends ChangeNotifier {
  AppShellController({AppSection initialSection = AppSection.cards})
    : _section = initialSection;

  AppSection _section;

  AppSection get section => _section;

  void setSection(AppSection section) {
    if (_section == section) {
      return;
    }
    _section = section;
    notifyListeners();
  }
}
