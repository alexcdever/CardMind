import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'platform_detector.dart';

/// Intent for creating a new card
class CreateCardIntent extends Intent {
  const CreateCardIntent();
}

/// Intent for saving a card
class SaveCardIntent extends Intent {
  const SaveCardIntent();
}

/// Intent for closing the editor
class CloseEditorIntent extends Intent {
  const CloseEditorIntent();
}

/// Intent for opening search
class SearchIntent extends Intent {
  const SearchIntent();
}

/// Intent for opening settings
class SettingsIntent extends Intent {
  const SettingsIntent();
}

/// Intent for deleting a card
class DeleteCardIntent extends Intent {
  const DeleteCardIntent();
}

/// Intent for selecting all text
class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

/// Intent for undo action
class UndoIntent extends Intent {
  const UndoIntent();
}

/// Intent for redo action
class RedoIntent extends Intent {
  const RedoIntent();
}

/// Keyboard shortcuts wrapper for desktop platforms
///
/// Provides keyboard shortcut support exclusively on desktop platforms.
/// Mobile platforms will not have shortcuts enabled.
///
/// Supported shortcuts:
/// - Ctrl/Cmd+N: Create new card
/// - Ctrl/Cmd+S: Save card
/// - Esc: Close editor
/// - Ctrl/Cmd+F: Search
/// - Ctrl/Cmd+,: Settings
/// - Delete: Delete card
/// - Ctrl/Cmd+A: Select all
/// - Ctrl/Cmd+Z: Undo
/// - Ctrl/Cmd+Shift+Z: Redo
class KeyboardShortcuts extends StatelessWidget {

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onCreateCard,
    this.onSaveCard,
    this.onCloseEditor,
    this.onSearch,
    this.onSettings,
    this.onDeleteCard,
    this.onSelectAll,
    this.onUndo,
    this.onRedo,
  });
  final Widget child;
  final VoidCallback? onCreateCard;
  final VoidCallback? onSaveCard;
  final VoidCallback? onCloseEditor;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;
  final VoidCallback? onDeleteCard;
  final VoidCallback? onSelectAll;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    // Mobile: No keyboard shortcuts
    if (PlatformDetector.isMobile) {
      return child;
    }

    // Desktop: Enable keyboard shortcuts
    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(actions: _buildActions(context), child: child),
    );
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      // Create new card: Ctrl/Cmd+N
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
          const CreateCardIntent(),

      // Save card: Ctrl/Cmd+S
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
          const SaveCardIntent(),

      // Close editor: Esc
      LogicalKeySet(LogicalKeyboardKey.escape): const CloseEditorIntent(),

      // Search: Ctrl/Cmd+F
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
          const SearchIntent(),

      // Settings: Ctrl/Cmd+,
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
          const SettingsIntent(),

      // Delete card: Delete
      LogicalKeySet(LogicalKeyboardKey.delete): const DeleteCardIntent(),

      // Select all: Ctrl/Cmd+A
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
          const SelectAllIntent(),

      // Undo: Ctrl/Cmd+Z
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
          const UndoIntent(),

      // Redo: Ctrl/Cmd+Shift+Z
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyZ,
      ): const RedoIntent(),
    };
  }

  Map<Type, Action<Intent>> _buildActions(BuildContext context) {
    return {
      if (onCreateCard != null)
        CreateCardIntent: CallbackAction<CreateCardIntent>(
          onInvoke: (_) {
            onCreateCard?.call();
            return null;
          },
        ),
      if (onSaveCard != null)
        SaveCardIntent: CallbackAction<SaveCardIntent>(
          onInvoke: (_) {
            onSaveCard?.call();
            return null;
          },
        ),
      if (onCloseEditor != null)
        CloseEditorIntent: CallbackAction<CloseEditorIntent>(
          onInvoke: (_) {
            onCloseEditor?.call();
            return null;
          },
        ),
      if (onSearch != null)
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) {
            onSearch?.call();
            return null;
          },
        ),
      if (onSettings != null)
        SettingsIntent: CallbackAction<SettingsIntent>(
          onInvoke: (_) {
            onSettings?.call();
            return null;
          },
        ),
      if (onDeleteCard != null)
        DeleteCardIntent: CallbackAction<DeleteCardIntent>(
          onInvoke: (_) {
            onDeleteCard?.call();
            return null;
          },
        ),
      if (onSelectAll != null)
        SelectAllIntent: CallbackAction<SelectAllIntent>(
          onInvoke: (_) {
            onSelectAll?.call();
            return null;
          },
        ),
      if (onUndo != null)
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (_) {
            onUndo?.call();
            return null;
          },
        ),
      if (onRedo != null)
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (_) {
            onRedo?.call();
            return null;
          },
        ),
    };
  }
}
