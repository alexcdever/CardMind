// input: 接收内容变更或保存触发，驱动 dirty/saved 状态迁移。
// output: 更新编辑状态字段并通过 notifyListeners() 广播变化。
// pos: 编辑页状态控制器，负责未保存与已保存标记管理。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:flutter/foundation.dart';

class EditorDraft {
  const EditorDraft({required this.title, required this.body});

  final String title;
  final String body;
}

class EditorController extends ChangeNotifier {
  bool _dirty = false;
  bool _saved = false;
  String _title = '';
  String _body = '';

  bool get dirty => _dirty;
  bool get saved => _saved;

  void setTitle(String value) {
    _title = value;
    onContentChanged();
  }

  void setBody(String value) {
    _body = value;
    onContentChanged();
  }

  EditorDraft draft() => EditorDraft(title: _title.trim(), body: _body.trim());

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
