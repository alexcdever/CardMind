/// # 卡片页面
///
/// 卡片列表的主界面，负责卡片读写交互、搜索过滤和编辑入口编排。
///
/// ## 关联路由
/// - 跳转至此页面需使用 `Navigator.pushNamed(context, '/cards')`。
///
/// ## 外部依赖
/// - 依赖 [CardsController] 提供卡片数据管理。
/// - 依赖 [FrbCardApiClient] 与后端通信。
library cards_page;

import 'dart:async';

import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

/// 卡片页面的主 Widget。
///
/// 负责卡片列表的展示、搜索、新建和编辑功能。
/// 支持桌面端和移动端两种不同的布局模式。
class CardsPage extends StatefulWidget {
  /// 创建卡片页面。
  ///
  /// [syncStatus] 同步状态，默认为健康状态。
  /// [controller] 可选的控制器，用于测试注入。
  const CardsPage({
    super.key,
    this.syncStatus = const SyncStatus.healthy(),
    this.controller,
  });

  /// 同步状态。
  final SyncStatus syncStatus;

  /// 卡片控制器，用于测试注入。
  final CardsController? controller;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final CardsController _controller = CardsController(
    apiClient: FrbCardApiClient(),
  )..addListener(_onChanged);
  late final CardsController _effectiveController =
      widget.controller ?? _controller;
  _DesktopEditorSession? _desktopSession;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_onChanged);
    unawaited(_loadInitialCards());
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// 加载初始卡片列表。
  ///
  /// 如果 FRB 未初始化（widget test 场景），则跳过默认加载。
  Future<void> _loadInitialCards() async {
    try {
      await _effectiveController.load();
    } on StateError {
      // widget test 若未初始化 FRB，则跳过默认加载，改由测试显式注入控制器或数据。
    }
  }

  /// 删除或恢复卡片。
  ///
  /// [id] 卡片 ID。
  /// [deleted] 当前删除状态，true 表示已删除，false 表示未删除。
  Future<void> _onDeleteOrRestore({required String id, required bool deleted}) {
    return deleted
        ? _effectiveController.restore(id)
        : _effectiveController.delete(id);
  }

  /// 打开编辑器。
  ///
  /// 在桌面端显示右侧面板，在移动端导航到新页面。
  /// [context] BuildContext。
  void _openEditor(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop) {
      setState(() {
        _desktopSession = _DesktopEditorSession();
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(
          onSaved: (draft) {
            if (draft.title.isEmpty) {
              return;
            }
            unawaited(
              _effectiveController.createDraft(
                generateNoteId(),
                draft.title,
                draft.body,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactions = const CardsDesktopInteractions();
    final notes = _effectiveController.items;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          interactions.showContextMenu(context, details.globalPosition);
        },
        child: desktop ? _buildDesktopLayout(notes) : _buildMobileLayout(notes),
      ),
      floatingActionButton: Semantics(
        container: true,
        explicitChildNodes: true,
        identifier: SemanticIds.cardsCreateFab,
        label: '新建卡片',
        button: true,
        child: FloatingActionButton(
          key: const ValueKey('cards.create_fab'),
          onPressed: () {
            _openEditor(context);
          },
          tooltip: '新建卡片',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// 构建移动端布局。
  ///
  /// [notes] 要显示的卡片列表。
  Widget _buildMobileLayout(List<CardSummary> notes) {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(child: _buildNotesList(notes)),
      ],
    );
  }

  /// 构建桌面端布局。
  ///
  /// [notes] 要显示的卡片列表。
  Widget _buildDesktopLayout(List<CardSummary> notes) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildSearchField(),
              Expanded(child: _buildNotesList(notes, desktop: true)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _buildDesktopEditorPanel(),
          ),
        ),
      ],
    );
  }

  /// 构建搜索输入框。
  Widget _buildSearchField() {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: SemanticIds.cardsSearchInput,
      label: '搜索卡片',
      textField: true,
      child: TextField(
        key: const ValueKey('cards.search_input'),
        decoration: const InputDecoration(hintText: '搜索卡片'),
        focusNode: _searchFocusNode,
        onChanged: (value) {
          unawaited(_effectiveController.load(query: value));
        },
      ),
    );
  }

  /// 构建卡片列表。
  ///
  /// [notes] 要显示的卡片列表。
  /// [desktop] 是否为桌面端布局，默认为 false。
  Widget _buildNotesList(List<CardSummary> notes, {bool desktop = false}) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: SemanticIds.cardsList,
      label: '卡片列表',
      child: ListView(
        children: [
          for (final note in notes)
            ListTile(
              key: ValueKey('cards.item.${note.id}'),
              selected: _desktopSession?.selectedId == note.id,
              title: Text(note.title),
              subtitle: note.deleted ? const Text('已删除') : null,
              onTap: desktop ? () => _handleDesktopSelection(note) : null,
              trailing: TextButton(
                key: ValueKey('cards.item.${note.id}.toggle_delete'),
                onPressed: () {
                  unawaited(
                    _onDeleteOrRestore(id: note.id, deleted: note.deleted),
                  );
                },
                child: Text(note.deleted ? '恢复' : '删除'),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建桌面端编辑器面板。
  Widget _buildDesktopEditorPanel() {
    final session = _desktopSession;
    if (session == null) {
      return const Center(child: Text('选择卡片或新建卡片'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('编辑卡片'),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          explicitChildNodes: true,
          identifier: SemanticIds.cardsDesktopEditorTitleInput,
          label: '桌面编辑标题输入框',
          textField: true,
          child: TextField(
            key: const ValueKey('cards.desktop_editor.title_input'),
            controller: session.titleController,
            decoration: const InputDecoration(labelText: '标题'),
            onChanged: (_) {
              setState(() {
                session.dirty = true;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            identifier: SemanticIds.cardsDesktopEditorBodyInput,
            label: '桌面编辑内容输入框',
            textField: true,
            child: TextField(
              key: const ValueKey('cards.desktop_editor.body_input'),
              controller: session.bodyController,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '内容',
              ),
              onChanged: (_) {
                setState(() {
                  session.dirty = true;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          explicitChildNodes: true,
          identifier: SemanticIds.cardsDesktopEditorSaveButton,
          label: '保存桌面编辑卡片',
          button: true,
          child: FilledButton(
            key: const ValueKey('cards.desktop_editor.save_button'),
            onPressed: _saveDesktopSession,
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  /// 处理桌面端卡片选择。
  ///
  /// [note] 被选中的卡片摘要。
  Future<void> _handleDesktopSelection(CardSummary note) async {
    final session = _desktopSession;
    if (session != null && session.dirty && session.selectedId != note.id) {
      final decision = await _showDesktopLeaveGuard();
      if (!mounted || decision == null || decision == _ExitDecision.cancel) {
        return;
      }
      if (decision == _ExitDecision.save) {
        await _saveDesktopSession();
      }
    }
    final detail = await _effectiveController.getCardDetail(note.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(
        detail.id,
        detail.title,
        body: detail.body,
      );
    });
  }

  /// 显示离开编辑器确认对话框。
  ///
  /// 当用户有未保存的更改时，提示保存、放弃或取消。
  Future<_ExitDecision?> _showDesktopLeaveGuard() {
    return showDialog<_ExitDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('离开编辑？'),
          content: const Text('你有未保存的更改。'),
          actions: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.cardsLeaveDialogSave,
              label: '保存并离开',
              button: true,
              child: TextButton(
                key: const ValueKey('cards.leave_dialog.save'),
                onPressed: () => Navigator.of(context).pop(_ExitDecision.save),
                child: const Text('保存并离开'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.cardsLeaveDialogDiscard,
              label: '放弃更改',
              button: true,
              child: TextButton(
                key: const ValueKey('cards.leave_dialog.discard'),
                onPressed: () =>
                    Navigator.of(context).pop(_ExitDecision.discard),
                child: const Text('放弃更改'),
              ),
            ),
            Semantics(
              container: true,
              explicitChildNodes: true,
              identifier: SemanticIds.cardsLeaveDialogCancel,
              label: '取消',
              button: true,
              child: TextButton(
                key: const ValueKey('cards.leave_dialog.cancel'),
                onPressed: () =>
                    Navigator.of(context).pop(_ExitDecision.cancel),
                child: const Text('取消'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 保存桌面端编辑会话。
  Future<void> _saveDesktopSession() async {
    final session = _desktopSession;
    if (session == null) {
      return;
    }
    final title = session.titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    String? savedId = session.selectedId;
    if (session.selectedId == null) {
      savedId = await _effectiveController.createDraft(
        generateNoteId(),
        title,
        session.bodyController.text,
      );
    } else {
      await _effectiveController.save(
        session.selectedId,
        title,
        session.bodyController.text,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(
        savedId,
        title,
        body: session.bodyController.text,
      );
    });
  }
}

/// 桌面端编辑器会话状态。
///
/// 管理桌面端编辑器的标题、内容和编辑状态。
class _DesktopEditorSession {
  /// 创建新的编辑器会话。
  ///
  /// [selectedId] 当前选中卡片的 ID，为 null 表示新建卡片。
  /// [title] 初始标题，默认为空字符串。
  /// [body] 初始内容，默认为空字符串。
  _DesktopEditorSession({this.selectedId, String title = '', String body = ''})
    : titleController = TextEditingController(text: title),
      bodyController = TextEditingController(text: body);

  /// 为已有卡片创建编辑器会话。
  ///
  /// [selectedId] 卡片 ID。
  /// [title] 卡片标题。
  /// [body] 卡片内容，默认为空字符串。
  factory _DesktopEditorSession.forSelection(
    String? selectedId,
    String title, {
    String body = '',
  }) {
    return _DesktopEditorSession(
      selectedId: selectedId,
      title: title,
      body: body,
    );
  }

  /// 当前选中卡片的 ID，为 null 表示新建卡片。
  final String? selectedId;

  /// 标题输入控制器。
  final TextEditingController titleController;

  /// 内容输入控制器。
  final TextEditingController bodyController;

  /// 是否有未保存的更改。
  bool dirty = false;
}

/// 离开编辑器的决策选项。
enum _ExitDecision {
  /// 保存并离开。
  save,

  /// 放弃更改并离开。
  discard,

  /// 取消离开操作。
  cancel,
}
