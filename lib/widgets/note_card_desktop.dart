import 'dart:async';

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/utils/text_truncator.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop-specific implementation of note card
///
/// Provides desktop-optimized interactions including:
/// - 4-line content preview (more than mobile)
/// - Hover effects with smooth transitions
/// - Right-click context menu with keyboard shortcuts
/// - Click to open modal edit dialog
/// - Keyboard navigation support
/// - Larger touch targets and spacing
class NoteCardDesktop extends StatefulWidget {
  const NoteCardDesktop({
    super.key,
    required this.card,
    this.onTap,
    this.onEdit,
    required this.onDelete,
    this.onCopy,
    this.onShare,
  });

  /// The card data to display
  final bridge.Card card;

  /// Callback when the card is tapped
  /// Opens modal edit dialog
  final VoidCallback? onTap;

  /// Callback when the card should be edited
  /// Provides the card object to be edited
  final void Function(bridge.Card card)? onEdit;

  /// Callback when the card should be deleted
  /// Provides the card ID to be deleted
  final void Function(String cardId) onDelete;

  /// Callback when the card content should be copied to clipboard
  final VoidCallback? onCopy;

  /// Callback when the card should be shared
  /// Optional - rarely used on desktop
  final VoidCallback? onShare;

  @override
  State<NoteCardDesktop> createState() => _NoteCardDesktopState();
}

class _NoteCardDesktopState extends State<NoteCardDesktop>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isHovered = false;
  final FocusNode _focusNode = FocusNode();
  Timer? _timeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 1, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _focusNode.addListener(_handleFocusChange);

    // Start time update timer if showing relative time
    if (TimeFormatter.isRelativeTime(widget.card.updatedAt)) {
      _startTimeUpdateTimer();
    }
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _hoverController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        setState(() {
          // Time will be re-formatted in build
        });
      }
    });
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() {});
    }
  }

  void _handleHover(bool isHovered) {
    if (_isHovered != isHovered) {
      setState(() {
        _isHovered = isHovered;
      });
      if (isHovered) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
    }
  }

  void _handleTap() {
    // Trigger haptic feedback on supported platforms
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleRightClick(TapUpDetails details) {
    _showContextMenu(context, details.globalPosition);
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.enter:
          widget.onTap?.call();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.contextMenu:
        case LogicalKeyboardKey.f10:
          if (HardwareKeyboard.instance.isShiftPressed) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero);
            _showContextMenu(context, position);
          }
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: GestureDetector(
          onTap: _handleTap,
          onSecondaryTapUp: _handleRightClick,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyPress,
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _hoverAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isHovered
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : theme.dividerColor.withValues(alpha: 0.2),
                        width: _isHovered ? 2 : 1,
                      ),
                      boxShadow: [
                        if (_isHovered)
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Semantics(
                      label: widget.card.title.isNotEmpty
                          ? 'Note card: ${widget.card.title}'
                          : 'Note card: Untitled',
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title section
                            _buildTitleSection(theme),
                            const SizedBox(height: 16),

                            // Divider
                            Container(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),

                            // Content preview section (4 lines for desktop)
                            _buildContentSection(theme),
                            const SizedBox(height: 16),

                            // Divider
                            Container(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),

                            // Time display section
                            _buildTimeSection(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextTruncator.buildTruncatedText(
            widget.card.title,
            isTitle: true,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ),
        if (_isHovered) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.more_horiz,
            size: 16,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ],
      ],
    );
  }

  Widget _buildContentSection(ThemeData theme) {
    return TextTruncator.buildRichTextPreview(
      widget.card.content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
        height: 1.5,
      ),
      showOverflowIndicator: true,
    );
  }

  Widget _buildTimeSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          TimeFormatter.formatTime(widget.card.updatedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    HapticFeedback.lightImpact();

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 12),
              const Text('编辑'),
              const Spacer(),
              Text(
                'Enter',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              const Text('删除', style: TextStyle(color: Colors.red)),
              const Spacer(),
              Text(
                'Del',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'view_details',
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 12),
              const Text('查看详情'),
              const Spacer(),
              Text(
                'Ctrl+I',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_content',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 18),
              const SizedBox(width: 12),
              const Text('复制内容'),
              const Spacer(),
              Text(
                'Ctrl+C',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    ).then(_handleContextMenuSelection);
  }

  void _handleContextMenuSelection(String? value) {
    switch (value) {
      case 'edit':
        widget.onEdit?.call(widget.card);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
      case 'view_details':
        _showDetailsDialog(context);
        break;
      case 'copy_content':
        widget.onCopy?.call();
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text(
          '确定要删除这张卡片吗？\n\n标题：${widget.card.title.isNotEmpty ? widget.card.title : '无标题'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete(widget.card.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final createdTime = TimeFormatter.formatTime(widget.card.createdAt);
    final updatedTime = TimeFormatter.formatTime(widget.card.updatedAt);
    final tags = widget.card.tags.isEmpty ? '无' : widget.card.tags.join(', ');
    final lastEditDevice = widget.card.lastEditDevice ?? '未知';

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('卡片详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', widget.card.id),
              _buildDetailRow(
                '标题',
                widget.card.title.isEmpty ? '无标题' : widget.card.title,
              ),
              _buildDetailRow('创建时间', createdTime),
              _buildDetailRow('更新时间', updatedTime),
              _buildDetailRow('最后编辑设备', lastEditDevice),
              _buildDetailRow('标签', tags),
              _buildDetailRow('内容长度', '${widget.card.content.length} 字符'),
              _buildDetailRow('是否已删除', widget.card.deleted ? '是' : '否'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
