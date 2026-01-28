import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/utils/text_truncator.dart';
import 'package:cardmind/utils/time_formatter.dart';
import 'package:flutter/material.dart';

import 'note_card_desktop.dart';
import 'note_card_mobile.dart';

/// Main NoteCard component with platform-specific rendering
///
/// This is the primary entry point for displaying note cards in the application.
/// It automatically detects the current platform and delegates to the appropriate
/// platform-specific implementation.
///
/// ## Platform Support
/// - **Desktop**: Uses NoteCardDesktop with 4-line content preview, hover effects, and right-click context menu
/// - **Mobile**: Uses NoteCardMobile with 3-line content preview, long-press menu, and haptic feedback
///
/// ## Architecture
/// This component is completely stateless and relies on the parent component for:
/// - Data management (Card model)
/// - Event handling (edit, delete, copy, share)
/// - State updates and UI refresh
///
/// ## Usage
/// ```dart
/// NoteCard(
///   card: myCard,
///   onTap: () => openEditor(card),
///   onEdit: (card) => navigateToEdit(card),
///   onDelete: (cardId) => deleteCard(cardId),
///   onCopy: () => copyCardContent(card),
///   onShare: () => openShareSheet(card),
/// )
/// ```
///
/// ## Performance Considerations
/// - All text formatting is handled by optimized utility classes
/// - Platform detection is compile-time optimized (zero runtime overhead)
/// - Uses const constructors where possible
/// - Minimal widget rebuilds due to stateless design
class NoteCard extends StatelessWidget {
  /// Creates a NoteCard with the specified card data and callbacks
  const NoteCard({
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
  ///
  /// On desktop: Opens modal edit dialog
  /// On mobile: Opens full-screen editor
  final VoidCallback? onTap;

  /// Callback when the card should be edited
  ///
  /// Provides the card object to be edited
  final Function(bridge.Card)? onEdit;

  /// Callback when the card should be deleted
  ///
  /// Provides the card ID to be deleted
  final Function(String cardId) onDelete;

  /// Callback when the card content should be copied to clipboard
  ///
  /// Optional - not all implementations support copy
  final VoidCallback? onCopy;

  /// Callback when the card should be shared
  ///
  /// Optional - primarily used on mobile platforms
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    // Platform detection is compile-time optimized in release builds
    // This results in zero runtime overhead for platform checks
    if (PlatformDetector.isDesktop) {
      return NoteCardDesktop(
        card: card,
        onTap: onTap,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onShare: onShare,
      );
    } else {
      return NoteCardMobile(
        card: card,
        onTap: onTap,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onShare: onShare,
      );
    }
  }

  /// Create a copy of this NoteCard with some properties replaced
  NoteCard copyWith({
    Key? key,
    bridge.Card? card,
    VoidCallback? onTap,
    Function(bridge.Card card)? onEdit,
    Function(String cardId)? onDelete,
    VoidCallback? onCopy,
    VoidCallback? onShare,
  }) {
    return NoteCard(
      key: key ?? this.key,
      card: card ?? this.card,
      onTap: onTap ?? this.onTap,
      onEdit: onEdit ?? this.onEdit,
      onDelete: onDelete ?? this.onDelete,
      onCopy: onCopy ?? this.onCopy,
      onShare: onShare ?? this.onShare,
    );
  }

  /// Check if this NoteCard has the same configuration as another
  bool isSame(NoteCard other) {
    return card.id == other.card.id &&
        card.title == other.card.title &&
        card.content == other.card.content &&
        card.updatedAt == other.card.updatedAt;
  }

  /// Get a semantic description for accessibility
  String getSemanticDescription() {
    final title = card.title.isNotEmpty ? card.title : '无标题';
    final contentPreview = card.content.isNotEmpty
        ? card.content.length > 50
              ? '${card.content.substring(0, 50)}...'
              : card.content
        : '空内容';
    final timeInfo = TimeFormatter.formatTime(card.updatedAt);

    return '笔记卡片：$title。内容：$contentPreview。更新时间：$timeInfo';
  }

  /// Check if the card has meaningful content
  bool hasContent() {
    return card.title.isNotEmpty || card.content.isNotEmpty;
  }

  /// Get display title for the card
  String getDisplayTitle() {
    return TextTruncator.truncateTitle(card.title);
  }

  /// Get display content preview for the card
  String getDisplayContent() {
    return TextTruncator.truncateContent(card.content);
  }

  /// Get formatted time display for the card
  String getDisplayTime() {
    return TimeFormatter.formatTime(card.updatedAt);
  }

  /// Check if the time display is relative (within 24 hours)
  bool isRelativeTimeDisplay() {
    return TimeFormatter.isRelativeTime(card.updatedAt);
  }
}
