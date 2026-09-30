import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../bridge/debug_log.dart';
import '../models/update_channel.dart';
import '../services/app_settings_service.dart';
import '../services/platform_update_installer.dart';
import '../services/update_downloader.dart';
import '../services/update_download_manager.dart';
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
    this.downloadManager,
    this.logDirectoryResolver,
    this.logDirectoryOpener,
    this.updatePackageOpener,
  });

  final String? currentVersion;
  final int currentBuild;
  final UpdateChannel initialChannel;
  final AppSettingsService? settings;
  final UpdateService? updates;
  final UpdateDownloader? downloader;
  final PlatformUpdateInstaller? installer;
  final UpdateDownloadManager? downloadManager;

  /// 日志目录推导（默认 [resolveLogDirectory]）；测试注入假实现，避免触碰
  /// 真实 `getApplicationSupportDirectory`。
  final Future<Directory> Function({String? baseDirectory})?
  logDirectoryResolver;

  /// 日志目录「打开」动作（默认 [openLogDirectoryInFileManager]）；测试注入
  /// 假实现，**不得真的打开访达**。
  final Future<void> Function(String directory)? logDirectoryOpener;

  /// 已校验更新包的打开动作；测试注入假实现。
  final Future<void> Function(String path)? updatePackageOpener;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UpdateChannel _channel = widget.initialChannel;
  String? _version;
  int? _build;
  UpdateCheckResult? _result;
  bool _checking = false;
  late final UpdateDownloadManager _downloadManager =
      widget.downloadManager ??
      UpdateDownloadManager(
        downloader: widget.downloader,
        installer: widget.installer,
      );
  late final bool _ownsDownloadManager = widget.downloadManager == null;
  String? _logDirectory;
  bool _logDirectoryLoadFailed = false;
  String? _shownRecoveryMessage;

  @override
  void dispose() {
    _downloadManager.removeListener(_downloadChanged);
    if (_ownsDownloadManager) _downloadManager.dispose();
    super.dispose();
  }

  void _downloadChanged() {
    if (!mounted) return;
    setState(() {
      if (_downloadManager.manifest case final manifest?) {
        _result = UpdateAvailable(manifest);
      }
    });
    _showRecoveryIfNeeded();
  }

  void _showRecoveryIfNeeded() {
    final message = _downloadManager.message;
    if (message == null ||
        _downloadManager.downloading ||
        _shownRecoveryMessage == message ||
        (!message.startsWith('安装失败：') &&
            !message.startsWith('已下载，请') &&
            !message.startsWith('更新失败：'))) {
      return;
    }
    _shownRecoveryMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  late final AppSettingsService _settings =
      widget.settings ?? AppSettingsService();
  UpdateService get _updates =>
      widget.updates ??
      UpdateService(
        currentBuild: _build ?? widget.currentBuild,
        currentVersion: _version ?? widget.currentVersion ?? '',
      );

  @override
  void initState() {
    super.initState();
    if (_downloadManager.manifest case final manifest?) {
      _result = UpdateAvailable(manifest);
    }
    _downloadManager.addListener(_downloadChanged);
    _showRecoveryIfNeeded();
    _loadSettings();
    _loadVersion();
    _loadLogDirectory();
  }

  Future<void> _loadLogDirectory() async {
    try {
      final dir = await (widget.logDirectoryResolver ?? resolveLogDirectory)();
      if (mounted) setState(() => _logDirectory = dir.path);
    } catch (_) {
      if (mounted) setState(() => _logDirectoryLoadFailed = true);
    }
  }

  Future<void> _openLogDirectory() async {
    final path = _logDirectory;
    if (path == null || path.isEmpty) return;
    try {
      await (widget.logDirectoryOpener ?? openLogDirectoryInFileManager)(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开日志目录：$path')));
    }
  }

  Future<void> _openUpdatePackage() async {
    final path = _downloadManager.downloadedPath;
    if (path == null || path.isEmpty) return;
    try {
      await (widget.updatePackageOpener ?? _defaultUpdatePackageOpener)(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开更新包：$path')));
    }
  }

  static Future<void> _defaultUpdatePackageOpener(String path) async {
    final command = Platform.isMacOS
        ? 'open'
        : Platform.isLinux
        ? 'xdg-open'
        : null;
    if (command == null) return;
    final process = await Process.start(command, <String>[path]);
    if (process.pid <= 0) throw StateError('无法打开更新包');
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
    _downloadManager.manifest = result is UpdateAvailable
        ? result.manifest
        : _downloadManager.manifest;
    await _downloadManager.start(asset);
  }

  void _cancelDownload() => _downloadManager.cancel();

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
                Text('日志目录', style: Theme.of(context).textTheme.titleMedium),
                InkWell(
                  key: const ValueKey('open-log-directory'),
                  onTap: _openLogDirectory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _logDirectory ??
                          (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…'),
                    ),
                  ),
                ),
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
                    onPressed: _downloadManager.downloading ? null : _download,
                    child: Text(_downloadManager.downloading ? '下载中…' : '下载更新'),
                  ),
                  if (_downloadManager.downloading)
                    TextButton(
                      key: const ValueKey('cancel-update-download'),
                      onPressed: _cancelDownload,
                      child: const Text('取消下载'),
                    ),
                  if (_downloadManager.downloading)
                    LinearProgressIndicator(value: _downloadManager.progress),
                  if (_downloadManager.message != null)
                    Text(_downloadManager.message!),
                  if (_downloadManager.downloadedPath case final path?) ...[
                    const SizedBox(height: 8),
                    Text('安装包路径：$path'),
                    if (Platform.isMacOS || Platform.isLinux)
                      TextButton(
                        key: const ValueKey('open-update-package'),
                        onPressed: _openUpdatePackage,
                        child: const Text('打开安装包'),
                      ),
                  ],
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
