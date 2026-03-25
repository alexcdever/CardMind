/// # 编辑器页面
///
/// 卡片编辑页面的主要界面组件，负责内容编辑、保存与离开拦截流程。
/// 提供标题和内容输入框、保存按钮、键盘快捷键支持以及未保存确认弹窗。
///
/// ## 关联路由
/// - 跳转至此页面需使用 `Navigator.pushNamed(context, '/editor')` 或通过其他导航方式。
///
/// ## 外部依赖
/// - 依赖 [EditorController] 管理编辑状态。
/// - 依赖 [SemanticIds] 提供语义标识符支持无障碍测试。
library editor_page;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import 'package:cardmind/features/editor/editor_controller.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';

/// 编辑器页面的 StatefulWidget。
///
/// 负责创建编辑器页面的状态管理实例 [_EditorPageState]。
/// 可通过 [onSaved] 回调在保存成功时通知父组件。
class EditorPage extends StatefulWidget {
  /// 创建编辑器页面实例。
  ///
  /// [onSaved] 可选回调，当用户成功保存编辑内容时触发，
  /// 回调参数为包含当前标题和内容的 [EditorDraft]。
  const EditorPage({super.key, this.onSaved});

  /// 保存成功时的回调函数。
  final ValueChanged<EditorDraft>? onSaved;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

/// 编辑器页面的状态实现类。
///
/// 管理编辑器的业务逻辑、用户交互和状态更新。
/// 包括：快捷键处理、返回拦截、保存逻辑和确认弹窗。
class _EditorPageState extends State<EditorPage> {
  /// 编辑器状态控制器实例。
  final EditorController _controller = EditorController();

  /// UUID 生成器实例，用于生成唯一标识符。
  static const Uuid _uuid = Uuid();

  /// 保存错误提示信息，为空时表示无错误。
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// 控制器状态变更回调。
  ///
  /// 当编辑器控制器的状态（如保存状态、脏标记）发生变化时触发，
  /// 调用 setState 刷新界面。
  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              unawaited(_controller.saveLocal());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) {
                return;
              }
              await _onBack();
            },
            child: Scaffold(
              appBar: AppBar(
                leading: BackButton(onPressed: _onBack),
                title: const Text('编辑卡片'),
                actions: [
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    identifier: SemanticIds.editorSaveButton,
                    label: '保存卡片',
                    button: true,
                    child: IconButton(
                      key: const ValueKey('editor.save_button'),
                      onPressed: () async {
                        final shouldClose = await _saveAndRunCallback();
                        if (!context.mounted || !shouldClose) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save_outlined),
                    ),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      identifier: SemanticIds.editorTitleInput,
                      label: '标题输入框',
                      textField: true,
                      child: TextField(
                        key: const ValueKey('editor.title_input'),
                        decoration: const InputDecoration(labelText: '标题'),
                        onChanged: _controller.setTitle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Semantics(
                        container: true,
                        explicitChildNodes: true,
                        identifier: SemanticIds.editorBodyInput,
                        label: '内容输入框',
                        textField: true,
                        child: TextField(
                          key: const ValueKey('editor.body_input'),
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            labelText: '内容',
                            hintText: '输入卡片内容',
                          ),
                          onChanged: _controller.setBody,
                        ),
                      ),
                    ),
                    if (_controller.saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('保存中...'),
                      ),
                    if (_controller.saved)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('本地已保存'),
                      ),
                    if (_saveErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_saveErrorMessage!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理返回按钮点击或系统返回手势。
  ///
  /// 如果有未保存的更改，显示确认弹窗让用户选择保存、放弃或取消。
  /// 如果没有未保存的更改，直接返回上一页。
  Future<void> _onBack() async {
    if (!_controller.dirty) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    final decision = await showDialog<_ExitDecision>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('离开编辑？'),
          content: const Text('你有未保存的更改。'),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.editorLeaveDialogSave,
              label: '保存并离开',
              button: true,
              child: TextButton(
                key: const ValueKey('editor.leave_dialog.save'),
                onPressed: () => Navigator.of(context).pop(_ExitDecision.save),
                child: const Text('保存并离开'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.editorLeaveDialogDiscard,
              label: '放弃更改',
              button: true,
              child: TextButton(
                key: const ValueKey('editor.leave_dialog.discard'),
                onPressed: () =>
                    Navigator.of(context).pop(_ExitDecision.discard),
                child: const Text('放弃更改'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.editorLeaveDialogCancel,
              label: '取消',
              button: true,
              child: TextButton(
                key: const ValueKey('editor.leave_dialog.cancel'),
                onPressed: () =>
                    Navigator.of(context).pop(_ExitDecision.cancel),
                child: const Text('取消'),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || decision == null) {
      return;
    }

    if (decision == _ExitDecision.cancel) {
      return;
    }

    if (decision == _ExitDecision.save) {
      final shouldClose = await _saveAndRunCallback();
      if (!mounted || !shouldClose) {
        return;
      }
    }

    Navigator.of(context).pop();
  }

  /// 执行保存操作并触发回调。
  ///
  /// 保存内容到本地，并在成功时调用 [onSaved] 回调通知父组件。
  ///
  /// 返回值为 `true` 表示保存成功，页面可以关闭；
  /// 返回 `false` 表示保存失败，页面应保持打开。
  Future<bool> _saveAndRunCallback() async {
    await _controller.saveLocal();
    if (!mounted) {
      return false;
    }
    try {
      widget.onSaved?.call(_controller.draft());
      setState(() {
        _saveErrorMessage = null;
      });
      return true;
    } catch (_) {
      setState(() {
        _saveErrorMessage = '保存失败，请重试';
      });
      return false;
    }
  }
}

/// 保存意图类。
///
/// 用于处理键盘快捷键（Ctrl/Cmd + S）触发的保存操作。
class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// 生成唯一的笔记 ID。
///
/// 使用 UUID v4 生成全局唯一标识符，用于新卡片的 ID。
String generateNoteId() => _EditorPageState._uuid.v4();

/// 退出编辑决策枚举。
///
/// 用户在离开编辑确认弹窗中的选择。
enum _ExitDecision { save, discard, cancel }
