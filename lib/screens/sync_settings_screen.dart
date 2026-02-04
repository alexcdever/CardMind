import 'package:cardmind/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 自动同步间隔枚举
enum SyncInterval {
  /// 手动同步
  manual,

  /// 15 分钟
  minutes15,

  /// 30 分钟
  minutes30,

  /// 1 小时
  hours1,
}

/// 冲突解决策略枚举
enum ConflictResolutionStrategy {
  /// 使用最新版本（基于时间戳）
  useLatest,

  /// 合并更改（CRDT 默认行为）
  merge,

  /// 保留本地版本
  keepLocal,

  /// 保留远程版本
  keepRemote,
}

/// 自动同步配置界面
///
/// 提供自动同步相关配置选项：
/// - 自动同步开关
/// - 同步间隔设置
/// - WiFi 限制
/// - 电池优化
/// - 冲突解决策略
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  /// 自动同步是否启用
  bool _autoSyncEnabled = false;

  /// 同步间隔
  SyncInterval _syncInterval = SyncInterval.manual;

  /// 是否仅在 WiFi 下同步
  bool _wifiOnly = true;

  /// 是否启用电池优化
  bool _batteryOptimization = false;

  /// 冲突解决策略
  ConflictResolutionStrategy _conflictStrategy =
      ConflictResolutionStrategy.merge;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  void _loadSettings() {
    // TODO: 从 SettingsProvider 加载保存的设置
    // ignore: unused_local_variable
    final settingsProvider = context.read<SettingsProvider>();
    // _autoSyncEnabled = settingsProvider.autoSyncEnabled;
    // _syncInterval = settingsProvider.syncInterval;
    // _wifiOnly = settingsProvider.wifiOnly;
    // _batteryOptimization = settingsProvider.batteryOptimization;
    // _conflictStrategy = settingsProvider.conflictResolutionStrategy;
  }

  /// 保存设置
  void _saveSettings() {
    // TODO: 保存设置到 SettingsProvider
    // ignore: unused_local_variable
    final settingsProvider = context.read<SettingsProvider>();
    // settingsProvider.setAutoSyncEnabled(_autoSyncEnabled);
    // settingsProvider.setSyncInterval(_syncInterval);
    // settingsProvider.setWifiOnly(_wifiOnly);
    // settingsProvider.setBatteryOptimization(_batteryOptimization);
    // settingsProvider.setConflictResolutionStrategy(_conflictStrategy);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // 响应式布局：大屏幕使用居中约束
    return Scaffold(
      appBar: AppBar(title: const Text('自动同步配置'), centerTitle: false),
      body: screenWidth > 1200
          ? _buildDesktopLayout(context, theme)
          : _buildMobileLayout(context),
    );
  }

  /// 构建桌面端布局
  Widget _buildDesktopLayout(BuildContext context, ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildSettingsContent(context),
          ),
        ),
      ),
    );
  }

  /// 构建移动端布局
  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_buildSettingsContent(context)],
    );
  }

  /// 构建设置内容
  Widget _buildSettingsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 自动同步开关
        _buildAutoSyncSection(context),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        // 同步间隔设置
        _buildSyncIntervalSection(context),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        // 网络设置
        _buildNetworkSection(context),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        // 电池优化
        _buildBatterySection(context),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        // 冲突解决策略
        _buildConflictResolutionSection(context),

        const SizedBox(height: 32),

        // 保存按钮
        _buildSaveButton(context),
      ],
    );
  }

  /// 构建自动同步部分
  Widget _buildAutoSyncSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sync, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              '自动同步',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '启用后，应用将自动与已连接的设备同步数据',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: const Text('启用自动同步'),
          subtitle: Text(
            _autoSyncEnabled
                ? _getSyncIntervalDescription(_syncInterval)
                : '仅在手动触发时同步',
          ),
          value: _autoSyncEnabled,
          onChanged: (value) {
            setState(() {
              _autoSyncEnabled = value;
            });
          },
        ),
      ],
    );
  }

  /// 构建同步间隔设置部分
  Widget _buildSyncIntervalSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              '同步间隔',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '选择自动同步的频率',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        RadioGroup<SyncInterval>(
          groupValue: _syncInterval,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _syncInterval = value;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...SyncInterval.values.map((interval) {
                return RadioListTile<SyncInterval>(
                  title: Text(_getSyncIntervalLabel(interval)),
                  subtitle: Text(_getSyncIntervalDescription(interval)),
                  value: interval,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建网络设置部分
  Widget _buildNetworkSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.wifi, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              '网络设置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '限制同步网络以节省流量',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: const Text('仅在 WiFi 下同步'),
          subtitle: const Text('使用移动数据时不会同步'),
          value: _wifiOnly,
          onChanged: (value) {
            setState(() {
              _wifiOnly = value;
            });
          },
        ),
      ],
    );
  }

  /// 构建电池优化部分
  Widget _buildBatterySection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.battery_charging_full,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              '电池优化',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '在低电量时限制同步以节省电量',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          secondary: const Icon(Icons.battery_saver),
          title: const Text('启用电池优化'),
          subtitle: const Text('电量低于 20% 时暂停同步'),
          value: _batteryOptimization,
          onChanged: (value) {
            setState(() {
              _batteryOptimization = value;
            });
          },
        ),
      ],
    );
  }

  /// 构建冲突解决策略部分
  Widget _buildConflictResolutionSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.merge_type, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              '冲突解决策略',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '当多个设备同时修改同一数据时，选择如何处理冲突',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        RadioGroup<ConflictResolutionStrategy>(
          groupValue: _conflictStrategy,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _conflictStrategy = value;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...ConflictResolutionStrategy.values.map((strategy) {
                return RadioListTile<ConflictResolutionStrategy>(
                  title: Text(_getConflictStrategyLabel(strategy)),
                  subtitle: Text(_getConflictStrategyDescription(strategy)),
                  value: strategy,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建保存按钮
  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          _saveSettings();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('设置已保存'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.save),
        label: const Text('保存设置'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// 获取同步间隔标签
  String _getSyncIntervalLabel(SyncInterval interval) {
    switch (interval) {
      case SyncInterval.manual:
        return '手动';
      case SyncInterval.minutes15:
        return '15 分钟';
      case SyncInterval.minutes30:
        return '30 分钟';
      case SyncInterval.hours1:
        return '1 小时';
    }
  }

  /// 获取同步间隔描述
  String _getSyncIntervalDescription(SyncInterval interval) {
    switch (interval) {
      case SyncInterval.manual:
        return '仅在手动触发时同步数据';
      case SyncInterval.minutes15:
        return '每 15 分钟自动同步一次';
      case SyncInterval.minutes30:
        return '每 30 分钟自动同步一次';
      case SyncInterval.hours1:
        return '每 1 小时自动同步一次';
    }
  }

  /// 获取冲突解决策略标签
  String _getConflictStrategyLabel(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.useLatest:
        return '使用最新版本';
      case ConflictResolutionStrategy.merge:
        return '合并更改';
      case ConflictResolutionStrategy.keepLocal:
        return '保留本地版本';
      case ConflictResolutionStrategy.keepRemote:
        return '保留远程版本';
    }
  }

  /// 获取冲突解决策略描述
  String _getConflictStrategyDescription(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.useLatest:
        return '使用最后修改的版本（基于时间戳）';
      case ConflictResolutionStrategy.merge:
        return '合并所有更改（推荐，CRDT 默认行为）';
      case ConflictResolutionStrategy.keepLocal:
        return '始终保留本地设备的版本';
      case ConflictResolutionStrategy.keepRemote:
        return '始终保留远程设备的版本';
    }
  }
}
