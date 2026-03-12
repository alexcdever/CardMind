// input: 页面接收 syncStatus，并通过 CardsController 处理卡片 CRUD 与检索。
// output: 渲染读模型列表，支持进入编辑页保存后回写列表。
// pos: 卡片页主界面，负责卡片读写交互与编辑入口编排。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'dart:async';

import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key, this.syncStatus = const SyncStatus.healthy()});

  final SyncStatus syncStatus;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late final AppDatabase _database = AppDatabase();
  late final SqliteCardsReadRepository _readRepository =
      SqliteCardsReadRepository(database: _database);
  late final CardsController _controller = CardsController(
    readRepository: _readRepository,
    apiClient: LegacyCardApiClient.inMemory(readRepository: _readRepository),
  )..addListener(_onChanged);
  _DesktopEditorSession? _desktopSession;

  @override
  void initState() {
    super.initState();
    unawaited(_seedAndLoad());
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _seedAndLoad() async {
    await _controller.create('seed-note', '示例卡片A', 'seed');
  }

  Future<void> _onDeleteOrRestore({required String id, required bool deleted}) {
    return deleted ? _controller.restore(id) : _controller.delete(id);
  }

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
              _controller.create(generateNoteId(), draft.title, draft.body),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactions = const CardsDesktopInteractions();
    final notes = _controller.items;
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
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(List<CardSummary> notes) {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(child: _buildNotesList(notes)),
      ],
    );
  }

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
        onChanged: (value) {
          unawaited(_controller.load(query: value));
        },
      ),
    );
  }

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
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(note.id, note.title);
    });
  }

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

  Future<void> _saveDesktopSession() async {
    final session = _desktopSession;
    if (session == null) {
      return;
    }
    final title = session.titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    await _controller.create(
      session.selectedId ?? generateNoteId(),
      title,
      session.bodyController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(
        session.selectedId,
        title,
        body: session.bodyController.text,
      );
    });
  }
}

class _DesktopEditorSession {
  _DesktopEditorSession({this.selectedId, String title = '', String body = ''})
    : titleController = TextEditingController(text: title),
      bodyController = TextEditingController(text: body);

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

  final String? selectedId;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  bool dirty = false;
}

enum _ExitDecision { save, discard, cancel }
