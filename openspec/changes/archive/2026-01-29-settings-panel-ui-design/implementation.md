# Settings Panel Implementation Guide

## Overview

本文档提供设置面板的详细技术实现指南，包括依赖包、状态管理、文件操作、主题切换等具体实现细节。

## Dependencies

### Required Flutter Packages

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  # File selection for import/export
  file_picker: ^6.0.0

  # Settings persistence
  shared_preferences: ^2.2.0

  # Open external links (GitHub, etc.)
  url_launcher: ^6.2.0

  # Toast notifications
  fluttertoast: ^8.2.0

  # App version information
  package_info_plus: ^5.0.0

  # State management
  flutter_riverpod: ^2.4.0
```

### Package Usage

- **file_picker**: 用于导入导出时的文件选择对话框
- **shared_preferences**: 持久化存储设置（通知开关、深色模式等）
- **url_launcher**: 打开外部链接（GitHub 仓库、更新日志等）
- **fluttertoast**: 显示操作反馈的 Toast 提示
- **package_info_plus**: 获取应用版本号和构建信息
- **flutter_riverpod**: 状态管理和依赖注入

## State Management with Riverpod

### Provider Definitions

```dart
// lib/providers/settings_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sync Notification Provider
final syncNotificationProvider = StateNotifierProvider<SyncNotificationNotifier, bool>((ref) {
  return SyncNotificationNotifier();
});

class SyncNotificationNotifier extends StateNotifier<bool> {
  SyncNotificationNotifier() : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('sync_notification_enabled') ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_notification_enabled', value);
  }
}

// Dark Mode Provider
final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('dark_mode_enabled') ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', value);
  }
}

// App Info Provider
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();

  return AppInfo(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
    license: 'MIT',
    githubUrl: 'https://github.com/your-org/cardmind',
    contributors: ['Contributor 1', 'Contributor 2'],
    changelog: [
      ChangelogEntry(
        version: '1.0.0',
        releaseDate: DateTime(2026, 1, 29),
        changes: ['Initial release', 'Basic note-taking features'],
      ),
    ],
  );
});
```

## Settings Persistence

### Storage Keys

使用 `shared_preferences` 存储设置，键名定义：

```dart
// lib/constants/storage_keys.dart

class StorageKeys {
  static const String syncNotificationEnabled = 'sync_notification_enabled';
  static const String darkModeEnabled = 'dark_mode_enabled';
}
```

### Save Setting

```dart
Future<void> saveSetting(String key, bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  } catch (e) {
    // Log error and show toast
    print('Failed to save setting: $e');
    Fluttertoast.showToast(msg: '设置保存失败，请重试');
  }
}
```

### Load Setting

```dart
Future<bool> loadSetting(String key, bool defaultValue) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  } catch (e) {
    // Log error and return default
    print('Failed to load setting: $e');
    return defaultValue;
  }
}
```

## Loro File Operations

### File Naming

生成导出文件名的格式：

```dart
String generateExportFileName() {
  final now = DateTime.now();
  final timestamp = DateFormat('yyyy-MM-dd-HHmmss').format(now);
  return 'cardmind-export-$timestamp.loro';
}
```

### Invalid Character Replacement

处理文件名中的非法字符：

```dart
String sanitizeFileName(String fileName) {
  // Replace invalid characters: / \ : * ? " < > |
  final invalidChars = RegExp(r'[/\\:*?"<>|]');
  return fileName.replaceAll(invalidChars, '_');
}
```

### Export Data

```dart
Future<void> exportData() async {
  try {
    // 1. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ExportConfirmDialog(
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed != true) return;

    // 2. Get Loro snapshot from Rust
    final snapshotData = await loroExportSnapshot();

    // 3. Open save file dialog
    final fileName = generateExportFileName();
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '导出数据',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['loro'],
    );

    if (outputFile == null) return;

    // 4. Write data to file
    final file = File(outputFile);
    await file.writeAsBytes(snapshotData);

    // 5. Show success toast
    Fluttertoast.showToast(msg: '数据导出成功');
  } catch (e) {
    // Handle errors
    print('Export failed: $e');
    Fluttertoast.showToast(msg: '数据导出失败，请重试');
  }
}
```

### Import Data

```dart
Future<void> importData() async {
  try {
    // 1. Open file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['loro'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // 2. Validate file size (< 100MB)
    if (file.size > 100 * 1024 * 1024) {
      Fluttertoast.showToast(msg: '文件过大（限制 100MB），请选择其他文件');
      return;
    }

    // 3. Parse file to get preview
    final fileData = file.bytes!;
    final preview = await loroParseFile(fileData);

    // 4. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ImportConfirmDialog(
        fileName: file.name,
        cardCount: preview.cardCount,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed != true) return;

    // 5. Import and merge data
    await loroImportMerge(fileData);

    // 6. Show success toast
    Fluttertoast.showToast(msg: '数据导入成功，已导入 ${preview.cardCount} 张卡片');
  } catch (e) {
    // Handle errors
    print('Import failed: $e');

    if (e.toString().contains('format')) {
      Fluttertoast.showToast(msg: '文件格式错误，请选择有效的 .loro 文件');
    } else if (e.toString().contains('permission')) {
      Fluttertoast.showToast(msg: '文件访问被拒绝，请检查权限');
    } else {
      Fluttertoast.showToast(msg: '数据导入失败，请重试');
    }
  }
}
```

### Rust FFI Interfaces

```dart
// lib/bridge/loro_bridge.dart

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

// Export snapshot as binary data
Future<Uint8List> loroExportSnapshot() async {
  // Call Rust FFI
  return await api.loroExportSnapshot();
}

// Parse file and get preview info
Future<FilePreview> loroParseFile(Uint8List data) async {
  // Call Rust FFI
  return await api.loroParseFile(data: data);
}

// Import and merge data
Future<void> loroImportMerge(Uint8List data) async {
  // Call Rust FFI
  await api.loroImportMerge(data: data);
}

class FilePreview {
  final int cardCount;
  final String version;

  FilePreview({required this.cardCount, required this.version});
}
```

## Theme Management

### Theme Provider

```dart
// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
    state = darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', enabled);
  }
}
```

### MaterialApp Configuration

```dart
// lib/main.dart

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'CardMind',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      home: HomePage(),
    );
  }
}
```

### Theme Definitions

```dart
// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Color(0xFF2196F3),
  scaffoldBackgroundColor: Color(0xFFF5F5F5),
  cardColor: Colors.white,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF333333)),
    bodyMedium: TextStyle(color: Color(0xFF666666)),
    bodySmall: TextStyle(color: Color(0xFF999999)),
  ),
  // ... more theme properties
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Color(0xFF64B5F6),
  scaffoldBackgroundColor: Color(0xFF1E1E1E),
  cardColor: Color(0xFF2C2C2C),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
    bodySmall: TextStyle(color: Color(0xFF808080)),
  ),
  // ... more theme properties
);
```

## URL Launching

### Open External Link

```dart
Future<void> openUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    print('Failed to open URL: $e');
    Fluttertoast.showToast(msg: '无法打开链接，请手动访问');
  }
}
```

### Usage in About Section

```dart
InkWell(
  onTap: () => openUrl('https://github.com/your-org/cardmind'),
  child: Row(
    children: [
      Text(
        'GitHub 仓库',
        style: TextStyle(color: Theme.of(context).primaryColor),
      ),
      SizedBox(width: 4),
      Icon(Icons.open_in_new, size: 16),
    ],
  ),
)
```

## Toast Notifications

### Show Toast

```dart
void showToast(String message, {bool isError = false}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: isError ? Colors.red : Colors.black87,
    textColor: Colors.white,
    fontSize: 14.0,
  );
}
```

### Usage Examples

```dart
// Success toast
showToast('同步通知已开启');

// Error toast
showToast('设置保存失败，请重试', isError: true);

// With custom duration
Fluttertoast.showToast(
  msg: '数据导出成功',
  toastLength: Toast.LENGTH_LONG,
  timeInSecForIosWeb: 3,
);
```

## Keyboard Shortcuts (Desktop)

### Shortcut Handler

```dart
// lib/widgets/settings_panel_desktop.dart

class SettingsPanelDesktop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Ctrl/Cmd + , to open settings
        LogicalKeySet(
          Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.comma,
        ): () => _openSettings(context),

        // Escape to close dialog
        LogicalKeySet(LogicalKeyboardKey.escape): () => Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: _buildDialog(context),
      ),
    );
  }
}
```

## Error Handling

### Error Types and Messages

```dart
enum SettingsError {
  saveFailed,
  loadFailed,
  exportFailed,
  importFailed,
  fileTooBig,
  invalidFormat,
  permissionDenied,
}

String getErrorMessage(SettingsError error) {
  switch (error) {
    case SettingsError.saveFailed:
      return '设置保存失败，请重试';
    case SettingsError.loadFailed:
      return '设置加载失败，使用默认值';
    case SettingsError.exportFailed:
      return '数据导出失败，请重试';
    case SettingsError.importFailed:
      return '数据导入失败，请重试';
    case SettingsError.fileTooBig:
      return '文件过大（限制 100MB），请选择其他文件';
    case SettingsError.invalidFormat:
      return '文件格式错误，请选择有效的 .loro 文件';
    case SettingsError.permissionDenied:
      return '文件访问被拒绝，请检查权限';
  }
}
```

### Error Recovery

```dart
Future<void> handleSettingToggleError(
  bool previousValue,
  StateNotifier<bool> notifier,
) async {
  // Revert to previous value
  notifier.state = previousValue;

  // Show error toast
  showToast('设置保存失败，请重试', isError: true);

  // Log error for debugging
  print('Setting toggle failed, reverted to: $previousValue');
}
```

## Performance Optimization

### Lazy Loading

```dart
// Load app info only when About section is visible
final appInfoProvider = FutureProvider.autoDispose<AppInfo>((ref) async {
  // This will be disposed when not needed
  return await _loadAppInfo();
});
```

### Debouncing

```dart
// Debounce rapid toggle switches
Timer? _debounceTimer;

void onToggleWithDebounce(bool value) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 300), () {
    _actualToggle(value);
  });
}
```

### Caching

```dart
// Cache app info to avoid repeated package_info calls
class AppInfoCache {
  static AppInfo? _cached;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  static Future<AppInfo> get() async {
    if (_cached != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cached!;
    }

    _cached = await _loadAppInfo();
    _cacheTime = DateTime.now();
    return _cached!;
  }
}
```

## Testing Utilities

### Mock Providers

```dart
// test/mocks/mock_providers.dart

final mockSyncNotificationProvider = StateProvider<bool>((ref) => true);
final mockDarkModeProvider = StateProvider<bool>((ref) => false);
final mockAppInfoProvider = Provider<AppInfo>((ref) => AppInfo(
  version: '1.0.0',
  buildNumber: '100',
  license: 'MIT',
  githubUrl: 'https://github.com/test/test',
  contributors: ['Test User'],
  changelog: [],
));
```

### Widget Test Helpers

```dart
// test/helpers/widget_test_helpers.dart

Widget createTestWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
    ),
  );
}

Future<void> pumpSettingsPanel(WidgetTester tester) async {
  await tester.pumpWidget(
    createTestWidget(SettingsPanelMobile(
      syncNotificationEnabled: true,
      darkModeEnabled: false,
      appVersion: '1.0.0',
      onToggleSyncNotification: (_) {},
      onToggleDarkMode: (_) {},
      onExportData: () async {},
      onImportData: () async {},
    )),
  );
}
```

## Platform Detection

### Check Platform

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
bool get isWeb => kIsWeb;
```

### Conditional Rendering

```dart
Widget build(BuildContext context) {
  if (isMobile) {
    return SettingsPanelMobile(...);
  } else {
    return SettingsPanelDesktop(...);
  }
}
```

## Accessibility

### Semantic Labels

```dart
Semantics(
  label: '同步通知开关',
  hint: '开启后，当笔记被其他设备修改时会收到通知',
  child: Switch(
    value: syncNotificationEnabled,
    onChanged: onToggle,
  ),
)
```

### Screen Reader Announcements

```dart
void announceToScreenReader(BuildContext context, String message) {
  SemanticsService.announce(message, TextDirection.ltr);
}

// Usage
onToggle(bool value) {
  // ... toggle logic
  announceToScreenReader(context, value ? '同步通知已开启' : '同步通知已关闭');
}
```

## References

- Flutter file_picker: https://pub.dev/packages/file_picker
- Flutter shared_preferences: https://pub.dev/packages/shared_preferences
- Flutter url_launcher: https://pub.dev/packages/url_launcher
- Flutter fluttertoast: https://pub.dev/packages/fluttertoast
- Flutter package_info_plus: https://pub.dev/packages/package_info_plus
- Flutter Riverpod: https://riverpod.dev/
- Loro CRDT: https://loro.dev/
- Material Design: https://m3.material.io/
