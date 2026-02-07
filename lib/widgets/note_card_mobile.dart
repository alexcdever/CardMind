import 'dart:async';

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/utils/text_truncator.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mobile-specific implementation of note card
///
/// Provides mobile-optimized interactions including:
/// - Touch-friendly spacing and sizing
/// - Long-press context menu with haptic feedback
/// - 3-line content preview
/// - Click to open full-screen editor
class NoteCardMobile extends StatefulWidget {
  const NoteCardMobile({
    super.key,
    required this.card,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onCopy,
    this.onShare,
  });

  final bridge.Card card;
  final VoidCallback? onTap;
  final void Function(bridge.Card)? onEdit;
  final void Function(String cardId) onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  State<NoteCardMobile> createState() => _NoteCardMobileState();
}

class _NoteCardMobileState extends State<NoteCardMobile> {
  Timer? _timeUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Start time update timer if showing relative time
    if (TimeFormatter.isRelativeTime(widget.card.updatedAt)) {
      _startTimeUpdateTimer();
    }
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTap:
            widget.onTap ??
            () {
              widget.onEdit?.call(widget.card);
            },
        onLongPress: () {
          HapticFeedback.lightImpact();
          _showContextMenu(context);
        },
        child: Semantics(
          label:
              'Note card: ${widget.card.title.isNotEmpty ? widget.card.title : '无标题'}',
          button: true,
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title section
                  _buildTitleSection(theme),
                  const SizedBox(height: 12),

                  // Content preview section
                  _buildContentSectionMobile(theme),
                  const SizedBox(height: 12),

                  // Time display section
                  _buildTimeSection(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme) {
    return TextTruncator.buildTruncatedText(
      widget.card.title.isEmpty ? '无标题' : widget.card.title,
      isTitle: true,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildContentSectionMobile(ThemeData theme) {
    return TextTruncator.buildTruncatedText(
      widget.card.content.isEmpty ? '点击添加内容...' : widget.card.content,
      isTitle: false,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
        height: 1.5,
      ),
    );
  }

  Widget _buildTimeSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          TimeFormatter.formatTime(widget.card.updatedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onEdit?.call(widget.card);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => _showDeleteConfirmation(context),
            ),
            if (widget.onShare != null)
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('分享'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShare?.call();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制内容'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onCopy?.call();
              },
            ),
          ],
        ),
      ),
    );
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
}
