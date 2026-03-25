/// # 编辑器控制器
///
/// 编辑器模块的状态控制器，负责管理编辑状态、内容变更和保存逻辑。
/// 维护 dirty（未保存）、saved（已保存）、saving（保存中）等状态标记。
///
/// ## 外部依赖
/// - 依赖 [ChangeNotifier] 提供状态变更通知机制。
library editor_controller;

import 'package:flutter/foundation.dart';

/// 编辑器草稿数据类。
///
/// 封装编辑器的标题和内容数据，用于在保存时传递编辑结果。
class EditorDraft {
  /// 创建编辑器草稿实例。
  ///
  /// [title] 卡片标题，已去除首尾空白。
  /// [body] 卡片内容正文，已去除首尾空白。
  const EditorDraft({required this.title, required this.body});

  /// 卡片标题。
  final String title;

  /// 卡片内容正文。
  final String body;
}

/// 编辑器状态控制器。
///
/// 管理编辑器的状态变更，包括：
/// - 内容变更跟踪（dirty 标记）
/// - 保存状态管理（saving、saved 标记）
/// - 标题和内容字段维护
///
/// 继承自 [ChangeNotifier]，状态变更时会通知监听者。
class EditorController extends ChangeNotifier {
  /// 是否有未保存的更改。
  bool _dirty = false;

  /// 内容是否已保存。
  bool _saved = false;

  /// 是否正在保存中。
  bool _saving = false;

  /// 当前标题内容。
  String _title = '';

  /// 当前正文内容。
  String _body = '';

  /// 获取是否有未保存的更改。
  bool get dirty => _dirty;

  /// 获取内容是否已保存。
  bool get saved => _saved;

  /// 获取是否正在保存中。
  bool get saving => _saving;

  /// 设置标题内容。
  ///
  /// 更新标题并触发内容变更处理，会重置 saved 标记并设置 dirty 标记。
  ///
  /// [value] 新的标题内容。
  void setTitle(String value) {
    _title = value;
    _onContentChanged();
  }

  /// 设置正文内容。
  ///
  /// 更新正文并触发内容变更处理，会重置 saved 标记并设置 dirty 标记。
  ///
  /// [value] 新的正文内容。
  void setBody(String value) {
    _body = value;
    _onContentChanged();
  }

  /// 生成当前草稿数据。
  ///
  /// 返回包含当前标题和内容的 [EditorDraft] 实例，
  /// 标题和正文会自动去除首尾空白字符。
  EditorDraft draft() => EditorDraft(title: _title.trim(), body: _body.trim());

  /// 内容变更处理。
  ///
  /// 内部方法，当标题或正文内容发生变化时调用。
  /// 设置 dirty 标记、重置 saved 标记，并通知监听者。
  void _onContentChanged() {
    _dirty = true;
    _saved = false;
    notifyListeners();
  }

  /// 执行本地保存操作。
  ///
  /// 模拟异步保存过程，设置 saving 状态，延迟 300ms 后完成保存。
  /// 保存完成后重置 dirty 标记、设置 saved 标记。
  ///
  /// 如果正在保存中，调用此方法不会有任何效果。
  Future<void> saveLocal() async {
    if (_saving) return;
    _saving = true;
    _saved = false;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _saving = false;
    _dirty = false;
    _saved = true;
    notifyListeners();
  }
}
