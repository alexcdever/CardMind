import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../bridge/api/device_config.dart';
import '../providers/theme_provider.dart';
import '../adaptive/layouts/adaptive_scaffold.dart';
import '../adaptive/layouts/adaptive_padding.dart';

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

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AdaptivePadding.small,
        children: [
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

          // About Section
          _buildSection(context, title: 'About', children: [_AboutTile()]),

          const Divider(),

          // Data Management (reserved for future)
          _buildSection(
            context,
            title: 'Data Management',
            children: [
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Data Management'),
                subtitle: const Text('Coming soon'),
                enabled: false,
                onTap: () {
                  // Reserved for future implementation
                },
              ),
            ],
          ),
        ],
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

    showAboutDialog(
      context: context,
      applicationName: packageInfo.appName,
      applicationVersion: 'v${packageInfo.version}+${packageInfo.buildNumber}',
      applicationLegalese: '© 2025 CardMind Team',
      applicationIcon: const Icon(Icons.card_membership, size: 48),
      children: [
        const SizedBox(height: 16),
        const Text(
          'CardMind is an offline-first, card-based note-taking app '
          'with P2P sync capabilities powered by CRDT technology.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Built with Flutter and Rust.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
