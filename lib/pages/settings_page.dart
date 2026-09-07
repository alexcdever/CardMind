import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_channel.dart';
import '../services/app_settings_service.dart';
import '../services/platform_update_installer.dart';
import '../services/update_downloader.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.currentVersion,
    this.currentBuild = 0,
    this.initialChannel = UpdateChannel.stable,
    this.settings,
    this.updates,
    this.downloader,
    this.installer,
  });

  final String? currentVersion;
  final int currentBuild;
  final UpdateChannel initialChannel;
  final AppSettingsService? settings;
  final UpdateService? updates;
  final UpdateDownloader? downloader;
  final PlatformUpdateInstaller? installer;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UpdateChannel _channel = widget.initialChannel;
  String? _version;
  int? _build;
  UpdateCheckResult? _result;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;
  String? _downloadMessage;
  DownloadCancellationToken? _downloadToken;

  @override
  void dispose() {
    _downloadToken?.cancel();
    super.dispose();
  }

  late final AppSettingsService _settings =
      widget.settings ?? AppSettingsService();
  UpdateService get _updates =>
      widget.updates ??
      UpdateService(
        currentBuild: _build ?? widget.currentBuild,
        currentVersion: _version ?? widget.currentVersion ?? '',
      );
  late final UpdateDownloader _downloader =
      widget.downloader ?? UpdateDownloader();
  late final PlatformUpdateInstaller _platformInstaller =
      widget.installer ??
      PlatformUpdateInstaller(
        platform: Platform.isWindows
            ? UpdatePlatform.windows
            : Platform.isAndroid
            ? UpdatePlatform.android
            : UpdatePlatform.linux,
      );

  PlatformUpdateInstaller get _installer => _platformInstaller;

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
    if (_checking) return;
    if (widget.updates == null && _build == null) {
      await _loadVersion();
    }
    if (!mounted) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final result = await _updates.check(_channel);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _result = UpdateCheckError('检查更新失败：$error');
      });
    }
  }

  Future<void> _download() async {
    final result = _result;
    final asset = result is UpdateAvailable
        ? result.manifest.currentAsset
        : null;
    if (asset == null) return;

    final token = DownloadCancellationToken();
    _downloadToken = token;
    setState(() {
      _downloading = true;
      _progress = 0;
      _downloadMessage = null;
    });
    final downloaded = await _downloader.download(
      asset,
      cancellation: token,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;

    if (downloaded is DownloadFailure) {
      setState(() {
        _downloading = false;
        _downloadToken = null;
        _downloadMessage = downloaded.message;
      });
      return;
    }

    final installed = await _installer.install(
      asset,
      verifiedFile: (downloaded as DownloadSuccess).file,
    );
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloadToken = null;
      _downloadMessage = switch (installed) {
        InstallStarted() => '已启动安装器',
        ManualInstallRequired(:final message) => message,
        InstallFailure(:final message) => message,
      };
    });
    if (installed case InstallFailure(:final message)) {
      _showInstallRecovery(message);
    } else if (installed case ManualInstallRequired(:final message)) {
      _showInstallRecovery(message);
    }
  }

  void _showInstallRecovery(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _cancelDownload() => _downloadToken?.cancel();

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
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('download-update'),
                    onPressed: _downloading ? null : _download,
                    child: Text(_downloading ? '下载中…' : '下载更新'),
                  ),
                  if (_downloading)
                    TextButton(
                      key: const ValueKey('cancel-update-download'),
                      onPressed: _cancelDownload,
                      child: const Text('取消下载'),
                    ),
                  if (_downloading) LinearProgressIndicator(value: _progress),
                  if (_downloadMessage != null) Text(_downloadMessage!),
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
