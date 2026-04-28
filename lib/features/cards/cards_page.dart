library cards_page;

import 'dart:async';

import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_desktop_interactions.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/editor/editor_controller.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:cardmind/features/shared/widgets/bottom_nav.dart';
import 'package:cardmind/features/shared/widgets/brand_header.dart';
import 'package:cardmind/features/shared/widgets/desktop_sidebar.dart';
import 'package:cardmind/features/shared/widgets/note_card.dart';
import 'package:cardmind/features/shared/widgets/search_field.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({
    super.key,
    this.syncStatus = const SyncStatus.healthy(),
    this.controller,
  });

  final SyncStatus syncStatus;
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
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadInitialCards() async {
    try {
      await _effectiveController.load();
    } on StateError {}
  }

  Future<void> _onDeleteOrRestore({required String id, required bool deleted}) {
    return deleted
        ? _effectiveController.restore(id)
        : _effectiveController.delete(id);
  }

  bool _useDesktopLayout(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
  }

  void _openEditor(BuildContext context) {
    final desktop = _useDesktopLayout(context);
    if (desktop) {
      setState(() {
        _desktopSession = _DesktopEditorSession();
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(
          onSaved: (draft) async {
            if (draft.title.isEmpty) return;
            await _effectiveController.createDraft(
              generateNoteId(),
              draft.title,
              draft.body,
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
    final desktop = _useDesktopLayout(context);

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
          onPressed: () => _openEditor(context),
          tooltip: '新建卡片',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(List<CardSummary> notes) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BrandHeader(),
            const SizedBox(height: 18),
            const Text(
              '笔记列表',
              style: TextStyle(
                color: CardMindColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '按主题整理你的卡片笔记。',
              style: TextStyle(
                color: CardMindColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            StyledSearchField(
              hintText: '搜索笔记...',
              focusNode: _searchFocusNode,
              semanticId: SemanticIds.cardsSearchInput,
              semanticLabel: '搜索卡片',
              onChanged: (value) {
                unawaited(_effectiveController.load(query: value));
              },
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildNotesList(notes)),
            BottomNav(
              currentSection: 'cards',
              onSectionChanged: (_) {},
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(List<CardSummary> notes) {
    return Row(
      children: [
        DesktopSidebar(
          currentSection: 'cards',
          onSectionChanged: (_) {},
          onNewNote: () => _openEditor(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                StyledSearchField(
                  hintText: '搜索笔记...',
                  focusNode: _searchFocusNode,
                  semanticId: SemanticIds.cardsSearchInput,
                  semanticLabel: '搜索卡片',
                  onChanged: (value) {
                    unawaited(_effectiveController.load(query: value));
                  },
                ),
                const SizedBox(height: 16),
                const _DesktopListHeading(),
                Expanded(child: _buildNotesList(notes, desktop: true)),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: CardMindColors.bgSurface,
            padding: const EdgeInsets.fromLTRB(32, 28, 30, 24),
            child: _buildDesktopEditorPanel(),
          ),
        ),
      ],
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NoteCard(
                tag: note.deleted ? '已删除' : '已同步',
                title: note.title,
                body: note.deleted ? '' : note.title,
                selected: _desktopSession?.selectedId == note.id,
                onTap: desktop
                    ? () => _handleDesktopSelection(note)
                    : () => _handleMobileSelection(note),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleMobileSelection(CardSummary note) async {
    final detail = await _effectiveController.getCardDetail(note.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(
          initialDraft: EditorDraft(title: detail.title, body: detail.body),
          onSaved: (draft) async {
            if (draft.title.isEmpty) return;
            await _effectiveController.save(note.id, draft.title, draft.body);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopEditorPanel() {
    final session = _desktopSession;
    if (session == null) {
      return const Center(
        child: Text(
          '选择卡片或新建卡片',
          style: TextStyle(color: CardMindColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: const [
            Text(
              '本地优先',
              style: TextStyle(
                color: CardMindColors.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '已同步',
              style: TextStyle(
                color: CardMindColors.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          explicitChildNodes: true,
          identifier: SemanticIds.cardsDesktopEditorTitleInput,
          label: '桌面编辑标题输入框',
          textField: true,
          child: TextField(
            key: const ValueKey('cards.desktop_editor.title_input'),
            controller: session.titleController,
            style: const TextStyle(
              color: CardMindColors.textPrimary,
              fontSize: 37,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '标题',
            ),
            onChanged: (_) {
              setState(() => session.dirty = true);
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '更新于 2026.04.24',
          style: TextStyle(
            color: Color(0xFF6E8183),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
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
              style: const TextStyle(
                color: Color(0xFF344B4E),
                fontSize: 15,
                height: 1.55,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '输入卡片内容',
              ),
              onChanged: (_) {
                setState(() => session.dirty = true);
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('cards.desktop_editor.save_button'),
              onPressed: _saveDesktopSession,
              child: const Text('保存'),
            ),
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
    final detail = await _effectiveController.getCardDetail(note.id);
    if (!mounted) return;
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(
        detail.id,
        detail.title,
        body: detail.body,
      );
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
    if (session == null) return;
    final title = session.titleController.text.trim();
    if (title.isEmpty) return;
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
    if (!mounted) return;
    setState(() {
      _desktopSession = _DesktopEditorSession.forSelection(
        savedId,
        title,
        body: session.bodyController.text,
      );
    });
  }
}

class _DesktopListHeading extends StatelessWidget {
  const _DesktopListHeading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '笔记列表',
            style: TextStyle(
              color: CardMindColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '12 条笔记',
            style: TextStyle(
              color: CardMindColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
