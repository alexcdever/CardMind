import 'dart:async';

import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/bridge/models/pool.dart' as pool;
import 'package:cardmind/models/device.dart';
import 'package:cardmind/utils/text_truncator.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced Note Card component following design specifications
///
/// Features:
/// - Platform-specific layouts (desktop: 4 lines, mobile: 3 lines)
/// - Proper time formatting with relative/absolute time
/// - Text truncation with platform-specific limits
/// - Context menu support (right-click desktop, long-press mobile)
/// - Hover effects for desktop
/// - Accessibility features
/// - Internationalization support
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.card,
    required this.currentPeerId,
    this.poolMembers,
    required this.onUpdate,
    required this.onDelete,
    this.onTap,
    this.onEdit,
    this.onViewDetails,
    this.onCopyContent,
    this.onShare,
  });

  final bridge.Card card;
  final String currentPeerId;
  final List<pool.Device>? poolMembers;
  final void Function(bridge.Card) onUpdate;
  final void Function(String) onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onViewDetails;
  final VoidCallback? onCopyContent;
  final VoidCallback? onShare;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isHovered = false;
  final TimeCache _timeCache = TimeFormatter.createTimeCache();

  // Context menu state
  bool _isContextMenuOpen = false;

  // Long press detection for mobile
  Timer? _longPressTimer;
  static const Duration _longPressDuration = Duration(milliseconds: 500);

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// Check if card was edited by another device
  bool get _isEditedByOther {
    if (widget.card.ownerType != bridge.OwnerType.pool) {
      return false;
    }
    if (widget.card.lastEditPeer.trim().isEmpty) {
      return false;
    }
    return widget.card.lastEditPeer != widget.currentPeerId;
  }

  /// Get formatted update time
  String get _formattedUpdateTime {
    return _timeCache.format(widget.card.updatedAt);
  }

  String _resolvePeerName(String peerId) {
    if (peerId.trim().isEmpty) {
      return '未知';
    }
    final members = widget.poolMembers ?? const <pool.Device>[];
    for (final member in members) {
      if (member.peerId == peerId) {
        return member.nickname;
      }
    }
    return PeerIdValidator.format(peerId);
  }

  /// Handle card tap (different behavior for desktop vs mobile)
  void _handleTap() {
    if (PlatformDetector.isMobile) {
      // Mobile: Open full-screen editor
      widget.onTap?.call();
    } else {
      // Desktop: Open edit dialog (or trigger edit mode)
      widget.onEdit?.call();
    }
  }

  /// Handle secondary tap (right-click on desktop)
  void _handleSecondaryTap() {
    if (PlatformDetector.isDesktop) {
      _showContextMenu();
    }
  }

  /// Handle pointer down (start long press detection on mobile)
  void _handlePointerDown() {
    if (PlatformDetector.isMobile) {
      _longPressTimer = Timer(_longPressDuration, () {
        _showContextMenu();
        HapticFeedback.mediumImpact(); // Provide tactile feedback
      });
    }
  }

  /// Handle pointer up (cancel long press if not triggered)
  void _handlePointerUp() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  /// Show context menu
  void _showContextMenu() {
    if (_isContextMenuOpen) return;

    setState(() {
      _isContextMenuOpen = true;
    });

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    if (PlatformDetector.isDesktop) {
      _showDesktopContextMenu(overlay, position, size);
    } else {
      _showMobileContextMenu();
    }
  }

  /// Show desktop context menu (popup menu)
  void _showDesktopContextMenu(
    OverlayState overlay,
    Offset position,
    Size size,
  ) {
    final overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background overlay
          GestureDetector(
            onTap: _hideContextMenu,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Context menu
          Positioned(
            left: position.dx + size.width / 2,
            top: position.dy + size.height / 2,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minWidth: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildContextMenuItems(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);

    // Store reference to remove later
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _currentOverlayEntry = overlayEntry;
      }
    });
  }

  /// Show mobile context menu (bottom sheet)
  void _showMobileContextMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildContextMenuItems(),
        ),
      ),
    ).then((_) {
      _hideContextMenu();
    });
  }

  /// Hide context menu
  void _hideContextMenu() {
    if (!_isContextMenuOpen) return;

    setState(() {
      _isContextMenuOpen = false;
    });

    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  }

  /// Build context menu items based on platform
  List<Widget> _buildContextMenuItems() {
    final isDesktop = PlatformDetector.isDesktop;

    return [
      // Edit - Common to both platforms
      ListTile(
        leading: const Icon(Icons.edit),
        title: const Text('编辑'),
        onTap: () {
          _hideContextMenu();
          widget.onEdit?.call();
        },
      ),

      // View Details - Desktop only
      if (isDesktop)
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('查看详情'),
          onTap: () {
            _hideContextMenu();
            widget.onViewDetails?.call();
          },
        ),

      // Share - Mobile only
      if (!isDesktop)
        ListTile(
          leading: const Icon(Icons.share),
          title: const Text('分享'),
          onTap: () {
            _hideContextMenu();
            widget.onShare?.call();
          },
        ),

      // Copy Content - Common to both platforms
      ListTile(
        leading: const Icon(Icons.content_copy),
        title: const Text('复制内容'),
        onTap: () {
          _hideContextMenu();
          widget.onCopyContent?.call();
        },
      ),

      const Divider(),

      // Delete - Common to both platforms (with danger styling)
      ListTile(
        leading: const Icon(Icons.delete, color: Colors.red),
        title: const Text('删除', style: TextStyle(color: Colors.red)),
        onTap: () {
          _hideContextMenu();
          _showDeleteConfirmation();
        },
      ),
    ];
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除卡片 "${widget.card.title.isEmpty ? '无标题' : widget.card.title}" 吗？',
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  OverlayEntry? _currentOverlayEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxContentLines = TextTruncator.getContentMaxLines();

    return MouseRegion(
      onEnter: (_) {
        if (PlatformDetector.isDesktop) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (PlatformDetector.isDesktop) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: Listener(
        onPointerDown: (_) => _handlePointerDown(),
        onPointerUp: (_) => _handlePointerUp(),
        child: GestureDetector(
          onTap: _handleTap,
          onSecondaryTap: _handleSecondaryTap,
          onLongPress: PlatformDetector.isMobile ? _showContextMenu : null,
          child: Card(
            elevation: _isHovered ? 4 : 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isHovered
                  ? BorderSide(color: theme.colorScheme.primary, width: 2)
                  : BorderSide(color: theme.dividerColor, width: 1),
            ),
            child: Semantics(
              label: _buildSemanticLabel(),
              button: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            TextTruncator.truncateTitle(widget.card.title),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: TextTruncator.maxTitleLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isEditedByOther)
                          Tooltip(
                            message:
                                '最后编辑节点: ${_resolvePeerName(widget.card.lastEditPeer)}',
                            child: Icon(
                              Icons.people,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Content preview with platform-specific line limits
                    Text(
                      TextTruncator.truncateContent(widget.card.content),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: maxContentLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Footer with time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Time display
                        Text(
                          _formattedUpdateTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
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

  /// Build semantic label for accessibility
  String _buildSemanticLabel() {
    final title = widget.card.title.isEmpty ? '无标题' : widget.card.title;
    final timeText = _formattedUpdateTime;
    final peerText = _isEditedByOther
        ? '，最后编辑节点: ${_resolvePeerName(widget.card.lastEditPeer)}'
        : '';

    return '笔记卡片: $title，更新时间: $timeText$peerText';
  }
}
