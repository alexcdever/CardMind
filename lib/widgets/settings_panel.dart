import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 设置面板
///
/// 包含：
/// - 主题切换
/// - 同步设置
/// - 关于信息
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 标题
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '设置',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 外观设置
            Text(
              '外观',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('暗色模式'),
              subtitle: const Text('切换应用主题'),
              value: widget.isDarkMode,
              onChanged: widget.onThemeChanged,
              secondary: Icon(
                widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
            const Divider(),

            // 同步设置
            const SizedBox(height: 8),
            Text(
              '同步',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('自动同步'),
              subtitle: const Text('在后台自动同步数据'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // TODO: 实现自动同步开关
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('仅 WiFi 同步'),
              subtitle: const Text('仅在 WiFi 网络下同步'),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // TODO: 实现 WiFi 同步开关
                },
              ),
            ),
            const Divider(),

            // 存储设置
            const SizedBox(height: 8),
            Text(
              '存储',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('清除缓存'),
              subtitle: const Text('清除本地缓存数据'),
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
            const Divider(),

            // 关于
            const SizedBox(height: 8),
            Text(
              '关于',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('版本信息'),
              subtitle: Text(
                _packageInfo != null
                    ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                    : '加载中...',
              ),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('开源许可'),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'CardMind',
                  applicationVersion: _packageInfo?.version ?? '1.0.0',
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？此操作不会删除您的笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实现清除缓存
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'CardMind',
      applicationVersion: _packageInfo?.version ?? '1.0.0',
      applicationIcon: const Icon(Icons.note, size: 48),
      applicationLegalese: '© 2026 CardMind',
      children: [
        const SizedBox(height: 16),
        const Text(
          'CardMind 是一款简洁高效的卡片笔记应用，'
          '支持 Markdown 和离线优先设计。',
        ),
        const SizedBox(height: 8),
        const Text(
          '特性：\n'
          '• 离线优先，数据本地存储\n'
          '• P2P 同步，无需服务器\n'
          '• Markdown 支持\n'
          '• 跨平台支持',
        ),
      ],
    );
  }
}
