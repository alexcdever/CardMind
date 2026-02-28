// input: lib/features/editor/editor_controller.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:flutter/foundation.dart';

class EditorController extends ChangeNotifier {
  bool _dirty = false;
  bool _saved = false;

  bool get dirty => _dirty;
  bool get saved => _saved;

  void onContentChanged() {
    _dirty = true;
    _saved = false;
    notifyListeners();
  }

  void saveLocal() {
    _dirty = false;
    _saved = true;
    notifyListeners();
  }
}
