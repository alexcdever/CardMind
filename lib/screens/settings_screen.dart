import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSection(
            context,
            title: 'Appearance',
            children: [
              _ThemeSwitchTile(),
            ],
          ),

          const Divider(),

          // About Section
          _buildSection(
            context,
            title: 'About',
            children: [
              _AboutTile(),
            ],
          ),

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
      subtitle: Text(
        themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
      ),
      value: themeProvider.isDarkMode,
      onChanged: (value) {
        themeProvider.setThemeMode(
          value ? ThemeMode.dark : ThemeMode.light,
        );
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
      applicationIcon: const Icon(
        Icons.card_membership,
        size: 48,
      ),
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
