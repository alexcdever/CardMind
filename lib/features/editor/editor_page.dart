library editor_page;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:cardmind/features/editor/editor_controller.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:cardmind/features/shared/widgets/desktop_sidebar.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.initialDraft, this.onSaved});

  final EditorDraft? initialDraft;
  final FutureOr<void> Function(EditorDraft draft)? onSaved;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final EditorController _controller = EditorController(
    initialDraft: widget.initialDraft,
  );
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialDraft?.title ?? '',
  );
  late final TextEditingController _bodyController = TextEditingController(
    text: widget.initialDraft?.body ?? '',
  );

  static const Uuid _uuid = Uuid();
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool _useDesktopLayout(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
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
              if (didPop) return;
              await _onBack();
            },
            child: _useDesktopLayout(context)
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: CardMindColors.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitleField(),
                      const SizedBox(height: 8),
                      _buildMeta(),
                      const SizedBox(height: 18),
                      _buildToolbar(),
                      const SizedBox(height: 18),
                      _buildBodyField(),
                    ],
                  ),
                ),
              ),
              if (_controller.saving)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('保存中...'),
                ),
              if (_controller.saved)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('本地已保存'),
                ),
              if (_saveErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_saveErrorMessage!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSidebar(
            currentSection: 'cards',
            onSectionChanged: _noopSectionChanged,
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFB),
              padding: const EdgeInsets.fromLTRB(20, 26, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDesktopTopBar(),
                  const SizedBox(height: 14),
                  _buildDesktopStatusRow(),
                  const SizedBox(height: 18),
                  _buildDesktopToolbar(),
                  const SizedBox(height: 18),
                  Expanded(child: _buildDesktopPaperCard()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _noopSectionChanged(String _) {}

  Widget _buildDesktopTopBar() {
    return Row(
      children: [
        SizedBox(
          width: 330,
          height: 32,
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索条目...',
              filled: true,
              fillColor: const Color(0xFFEEF3F3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 14,
                color: Color(0xFF8BA1A3),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF8BA1A3),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatusRow() {
    return const Row(
      children: [
        Text(
          '已保存',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F766E),
          ),
        ),
        SizedBox(width: 12),
        Text(
          '最后编辑于 2 分钟前',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6E8183),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Text(
            'B',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF223233),
            ),
          ),
          SizedBox(width: 16),
          Text(
            'I',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF223233),
            ),
          ),
          SizedBox(width: 16),
          Icon(Icons.format_quote, size: 14, color: Color(0xFF223233)),
          SizedBox(width: 16),
          Icon(Icons.link, size: 14, color: Color(0xFF223233)),
        ],
      ),
    );
  }

  Widget _buildDesktopPaperCard() {
    return Center(
      child: SizedBox(
        width: 620,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(42, 44, 34, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF223233),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '标题',
              hintStyle: TextStyle(
                color: Color(0xFF8BA1A3),
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
            onChanged: _controller.setTitle,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: TextField(
              controller: _bodyController,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF344B4E),
                height: 1.55,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '内容',
                hintStyle: TextStyle(
                  color: Color(0xFF8BA1A3),
                  fontSize: 15,
                ),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: _controller.setBody,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '164 字',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8BA1A3),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => unawaited(_onBack()),
          child: const Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: CardMindColors.brand,
              ),
              SizedBox(width: 8),
              Text(
                'Card Mind',
                style: TextStyle(
                  color: CardMindColors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Semantics(
          container: true,
          explicitChildNodes: true,
          identifier: SemanticIds.editorSaveButton,
          label: '保存卡片',
          button: true,
          child: GestureDetector(
            key: const ValueKey('editor.save_button'),
            onTap: () async {
              final navigator = Navigator.of(context);
              final shouldClose = await _saveAndRunCallback();
              if (!mounted || !shouldClose) return;
              navigator.pop();
            },
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                color: CardMindColors.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeta() {
    return Row(
      children: [
        const Text(
          '本地优先 · 01',
          style: TextStyle(
            color: CardMindColors.brand,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '最后编辑 2 分钟前',
          style: TextStyle(
            color: CardMindColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CardMindColors.brandMutedBg,
        borderRadius: BorderRadius.circular(CardMindRadii.sm),
      ),
      child: const Row(
        children: [
          Text(
            'B',
            style: TextStyle(
              color: Color(0xFF223233),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 18),
          Text(
            'I',
            style: TextStyle(
              color: Color(0xFF223233),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.normal,
            ),
          ),
          SizedBox(width: 18),
          Icon(Icons.format_quote, size: 14, color: Color(0xFF223233)),
        ],
      ),
    );
  }

  Widget _buildBodyField() {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: SemanticIds.editorBodyInput,
      label: '内容输入框',
      textField: true,
      child: TextField(
        key: const ValueKey('editor.body_input'),
        controller: _bodyController,
        minLines: 10,
        maxLines: null,
        style: const TextStyle(
          color: Color(0xFF344B4E),
          fontSize: 15,
          height: 1.6,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '内容',
        ),
        onChanged: _controller.setBody,
      ),
    );
  }

  Widget _buildTitleField() {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: SemanticIds.editorTitleInput,
      label: '标题输入框',
      textField: true,
      child: TextField(
        key: const ValueKey('editor.title_input'),
        controller: _titleController,
        style: const TextStyle(
          color: CardMindColors.textPrimary,
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '标题',
        ),
        onChanged: _controller.setTitle,
      ),
    );
  }

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

    if (!mounted || decision == null) return;
    if (decision == _ExitDecision.cancel) return;

    if (decision == _ExitDecision.save) {
      final shouldClose = await _saveAndRunCallback();
      if (!mounted || !shouldClose) return;
    }

    Navigator.of(context).pop();
  }

  Future<bool> _saveAndRunCallback() async {
    await _controller.saveLocal();
    if (!mounted) return false;
    try {
      await widget.onSaved?.call(_controller.draft());
      setState(() => _saveErrorMessage = null);
      return true;
    } catch (_) {
      setState(() => _saveErrorMessage = '保存失败，请重试');
      return false;
    }
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

String generateNoteId() => _EditorPageState._uuid.v4();

enum _ExitDecision { save, discard, cancel }
