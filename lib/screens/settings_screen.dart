import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../adaptive/layouts/adaptive_padding.dart';
import '../adaptive/layouts/adaptive_scaffold.dart';
import '../bridge/third_party/cardmind_rust/api/device_config.dart';
import '../providers/app_info_provider.dart';
import '../providers/card_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/loro_file_service.dart';
import '../widgets/dialogs/export_confirm_dialog.dart';
import '../widgets/settings/button_setting_item.dart';
import '../widgets/settings/toggle_setting_item.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _mdnsActive = false;
  int _remainingMs = 0;
  Timer? _countdownTimer;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadMdnsState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMdnsState() async {
    try {
      final isActive = await isMdnsActive();
      final remaining = await getMdnsRemainingMs();

      if (!mounted) return;

      setState(() {
        _mdnsActive = isActive;
        _remainingMs = remaining;
        _isLoading = false;
      });

      if (_mdnsActive && _remainingMs > 0) {
        _startCountdown();
      }
    } on Exception {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_remainingMs <= 0) {
        _countdownTimer?.cancel();
        await _refreshMdnsState();
      } else {
        setState(() {
          _remainingMs = (_remainingMs - 1000).clamp(0, _remainingMs);
        });
      }
    });
  }

  Future<void> _refreshMdnsState() async {
    try {
      final isActive = await isMdnsActive();
      final remaining = await getMdnsRemainingMs();

      if (!mounted) return;

      setState(() {
        _mdnsActive = isActive;
        _remainingMs = remaining;
      });

      if (!_mdnsActive) {
        _countdownTimer?.cancel();
      }
    } on Exception {
      // Ignore errors during refresh
    }
  }

  Future<void> _enableMdnsTemporary() async {
    try {
      await enableMdnsTemporary();
      await _refreshMdnsState();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to enable mDNS: $e')));
    }
  }

  Future<void> _cancelMdnsTimer() async {
    try {
      await cancelMdnsTimer();
      await _refreshMdnsState();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to disable mDNS: $e')));
    }
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s remaining';
  }

  Future<void> _handleExport(BuildContext context) async {
    // 在任何异步操作前保存 messenger
    final messenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _isExporting = true);

      // 获取卡片数量
      final cardProvider = context.read<CardProvider>();
      final cards = cardProvider.cards;

      // 显示确认对话框
      final confirmed = await ExportConfirmDialog.show(context, cards.length);
      if (!confirmed) {
        setState(() => _isExporting = false);
        return;
      }

      // 导出数据
      final filePath = await LoroFileService.exportData();

      if (!mounted) return;

      if (filePath != null) {
        messenger.showSnackBar(SnackBar(content: Text('数据已导出到: $filePath')));
      }
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    // 在任何异步操作前保存 provider 和 messenger
    final cardProvider = context.read<CardProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _isImporting = true);

      // 导入数据
      final count = await LoroFileService.importData();

      if (!mounted) return;

      if (count != null) {
        // 刷新卡片列表
        await cardProvider.loadCards();

        if (!mounted) return;

        messenger.showSnackBar(SnackBar(content: Text('成功导入 $count 张卡片')));
      }
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _handleToggleSyncNotification(
    BuildContext context,
    bool value,
  ) async {
    // 在任何异步操作前保存 provider 和 messenger
    final settingsProvider = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await settingsProvider.setSyncNotificationEnabled(value);
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('设置失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return CallbackShortcuts(
      bindings: {
        // Escape key to close settings (desktop)
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        // Ctrl/Cmd + E to export data
        const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
          meta: true,
        ): () =>
            _handleExport(context),
        // Ctrl/Cmd + I to import data
        const SingleActivator(
          LogicalKeyboardKey.keyI,
          control: true,
          meta: true,
        ): () =>
            _handleImport(context),
      },
      child: Focus(
        autofocus: true,
        child: Semantics(
          label: 'Settings Screen',
          child: AdaptiveScaffold(
            appBar: AppBar(
              title: const Text('Settings'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: ListView(
              padding: AdaptivePadding.small,
              children: [
                // Notifications Section
                _buildSection(
                  context,
                  title: 'Notifications',
                  children: [
                    ToggleSettingItem(
                      icon: Icons.notifications,
                      label: 'Sync Notifications',
                      description: 'Notify when sync completes',
                      value: settingsProvider.syncNotificationEnabled,
                      onChanged: (value) =>
                          _handleToggleSyncNotification(context, value),
                    ),
                  ],
                ),

                const Divider(),

                // Theme Section
                _buildSection(
                  context,
                  title: 'Appearance',
                  children: [_ThemeSwitchTile()],
                ),

                const Divider(),

                // Sync Section (mDNS)
                _buildSection(
                  context,
                  title: 'Sync',
                  children: [
                    _MdnsTile(
                      isLoading: _isLoading,
                      isActive: _mdnsActive,
                      remainingText: _mdnsActive
                          ? _formatDuration(_remainingMs)
                          : null,
                      onEnable: _enableMdnsTemporary,
                      onDisable: _cancelMdnsTimer,
                    ),
                  ],
                ),

                const Divider(),

                // Data Management Section
                _buildSection(
                  context,
                  title: 'Data Management',
                  children: [
                    ButtonSettingItem(
                      icon: Icons.upload_file,
                      label: 'Export Data',
                      description: 'Export all notes to backup file',
                      onPressed: _isExporting
                          ? null
                          : () => _handleExport(context),
                      isLoading: _isExporting,
                    ),
                    ButtonSettingItem(
                      icon: Icons.download,
                      label: 'Import Data',
                      description: 'Import notes from backup file',
                      onPressed: _isImporting
                          ? null
                          : () => _handleImport(context),
                      isLoading: _isImporting,
                    ),
                  ],
                ),

                const Divider(),

                // About Section
                _buildSection(
                  context,
                  title: 'About',
                  children: [_AboutTile()],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// mDNS discovery tile widget
class _MdnsTile extends StatelessWidget {
  const _MdnsTile({
    required this.isLoading,
    required this.isActive,
    this.remainingText,
    required this.onEnable,
    required this.onDisable,
  });

  final bool isLoading;
  final bool isActive;
  final String? remainingText;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isActive ? Icons.wifi_find : Icons.wifi_find_outlined,
        color: isActive ? Colors.green : null,
      ),
      title: const Text('mDNS Discovery'),
      subtitle: isLoading
          ? const Text('Loading...')
          : isActive
          ? Text(
              'Active - $remainingText',
              style: const TextStyle(color: Colors.green),
            )
          : const Text('Disabled'),
      trailing: ElevatedButton(
        onPressed: isLoading ? null : (isActive ? onDisable : onEnable),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.red[100] : null,
          foregroundColor: isActive ? Colors.red : null,
        ),
        child: Text(isActive ? 'Turn Off' : 'Enable 5 min'),
      ),
    );
  }
}

/// Theme switch tile widget
class _ThemeSwitchTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return SwitchListTile(
      secondary: Icon(
        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
      ),
      title: const Text('Dark Mode'),
      subtitle: Text(themeProvider.isDarkMode ? 'Enabled' : 'Disabled'),
      value: themeProvider.isDarkMode,
      onChanged: (value) {
        themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
      },
    );
  }
}

/// About tile widget
class _AboutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info),
      title: const Text('About CardMind'),
      onTap: () => _showAboutDialog(context),
    );
  }

  void _showAboutDialog(BuildContext context) async {
    // Get package info
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } on Exception {
      // Fallback if package_info_plus fails
      packageInfo = PackageInfo(
        appName: 'CardMind',
        packageName: 'com.cardmind.app',
        version: '0.1.0',
        buildNumber: 'dev',
      );
    }

    if (!context.mounted) return;

    final appInfoProvider = context.read<AppInfoProvider>();
    final appInfo = appInfoProvider.appInfo;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.card_membership, size: 32),
            const SizedBox(width: 12),
            Text(packageInfo.appName),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version info
              Text(
                'Version ${packageInfo.version} (${packageInfo.buildNumber})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                appInfo.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Technical Stack
              Text(
                'Technical Stack',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Flutter - Cross-platform UI framework'),
              const Text('• Rust - High-performance backend'),
              const Text('• Loro CRDT - Conflict-free data sync'),
              const Text('• SQLite - Local data storage'),
              const SizedBox(height: 16),

              // Contributors
              if (appInfo.contributors.isNotEmpty) ...[
                Text(
                  'Contributors',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...appInfo.contributors.map(
                  (contributor) => Text('• $contributor'),
                ),
                const SizedBox(height: 16),
              ],

              // Changelog (recent 3 versions)
              if (appInfo.changelog.isNotEmpty) ...[
                Text(
                  'Recent Changes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...appInfo.changelog
                    .take(3)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v${entry.version} (${entry.date})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...entry.changes.map(
                              (change) => Text('  • $change'),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
              ],

              // Links
              InkWell(
                onTap: () => _launchUrl(appInfo.homepage),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Project Homepage',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _launchUrl(appInfo.issuesUrl),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Report Issues',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Copyright
              Text(
                '© 2025 CardMind Team',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
