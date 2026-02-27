// input: 编辑器内容变更与保存触发事件
// output: dirty/saved 可观察状态更新
// pos: 编辑页状态控制器；修改需同步对应测试与 DIR.md
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
