import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_channel.dart';
import '../services/app_settings_service.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.currentVersion,
    this.currentBuild = 0,
    this.initialChannel = UpdateChannel.stable,
    this.settings,
    this.updates,
  });

  final String? currentVersion;
  final int currentBuild;
  final UpdateChannel initialChannel;
  final AppSettingsService? settings;
  final UpdateService? updates;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UpdateChannel _channel = widget.initialChannel;
  String? _version;
  int? _build;
  UpdateCheckResult? _result;
  bool _checking = false;

  AppSettingsService get _settings => widget.settings ?? AppSettingsService();

  UpdateService get _updates =>
      widget.updates ??
      UpdateService(
        currentBuild: _build ?? widget.currentBuild,
        currentVersion: _version ?? widget.currentVersion ?? '',
      );

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadSettings() async {
    final channel = await _settings.readChannel();
    if (mounted) setState(() => _channel = channel);
  }

  Future<void> _loadVersion() async {
    if (widget.currentVersion != null) {
      if (mounted) {
        setState(() {
          _version = widget.currentVersion;
          _build = widget.currentBuild > 0 ? widget.currentBuild : null;
        });
      }
      return;
    }
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
        _build = int.tryParse(info.buildNumber);
      });
    }
  }

  Future<void> _choose(UpdateChannel channel) async {
    if (channel == _channel) return;
    if (channel == UpdateChannel.beta) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('切换到测试版？'),
          content: const Text('测试版可能包含未完成或不稳定功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    await _settings.writeChannel(channel);
    if (mounted) setState(() => _channel = channel);
  }

  Future<void> _check() async {
    if (widget.updates == null && _build == null) {
      await _loadVersion();
    }
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await _updates.check(_channel);
    if (mounted) {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            key: const ValueKey('settings-page'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('应用版本', style: Theme.of(context).textTheme.titleMedium),
                Text(_version ?? '加载中…'),
                const SizedBox(height: 24),
                Text('更新渠道', style: Theme.of(context).textTheme.titleMedium),
                RadioGroup<UpdateChannel>(
                  groupValue: _channel,
                  onChanged: (value) {
                    if (value != null) _choose(value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<UpdateChannel>(
                        key: const ValueKey('update-channel-stable'),
                        title: Text(UpdateChannel.stable.label),
                        subtitle: Text(UpdateChannel.stable.description),
                        value: UpdateChannel.stable,
                      ),
                      RadioListTile<UpdateChannel>(
                        key: const ValueKey('update-channel-beta'),
                        title: Text(UpdateChannel.beta.label),
                        subtitle: Text(UpdateChannel.beta.description),
                        value: UpdateChannel.beta,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  key: const ValueKey('check-for-updates'),
                  onPressed: _checking ? null : _check,
                  child: Text(_checking ? '检查中…' : '检查更新'),
                ),
                const SizedBox(height: 16),
                if (_checking) const Text('检查中…'),
                if (_result case UpdateUpToDate(:final manifest)) ...[
                  const Text('已是最新版本'),
                  Text('最新版本：${manifest.version}'),
                ],
                if (_result case UpdateAvailable(:final manifest)) ...[
                  const Text('发现更新'),
                  Text('最新版本：${manifest.version}'),
                  ...manifest.releaseNotes.map(Text.new),
                ],
                if (_result case UpdateCheckError(:final message))
                  Text('检查失败：$message'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
