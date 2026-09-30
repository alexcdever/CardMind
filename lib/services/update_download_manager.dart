import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/update_manifest.dart';
import 'platform_update_installer.dart';
import 'update_downloader.dart';

class UpdateDownloadManager extends ChangeNotifier {
  UpdateDownloadManager({
    UpdateDownloader? downloader,
    PlatformUpdateInstaller? installer,
  }) : _downloader = downloader ?? UpdateDownloader(),
       _ownsDownloader = downloader == null,
       _installer = installer ?? _defaultInstaller();

  final UpdateDownloader _downloader;
  final bool _ownsDownloader;
  final PlatformUpdateInstaller _installer;
  bool _disposed = false;

  UpdateAsset? asset;
  UpdateManifest? manifest;
  bool downloading = false;
  double progress = 0;
  String? message;
  String? downloadedPath;
  DownloadCancellationToken? _token;

  static PlatformUpdateInstaller _defaultInstaller() => PlatformUpdateInstaller(
    platform: Platform.isWindows
        ? UpdatePlatform.windows
        : Platform.isAndroid
        ? UpdatePlatform.android
        : Platform.isMacOS
        ? UpdatePlatform.macos
        : UpdatePlatform.linux,
  );

  bool get hasDownload => asset != null;

  Future<void> start(UpdateAsset updateAsset) async {
    if (_disposed || downloading) return;
    asset = updateAsset;
    message = null;
    downloadedPath = null;
    progress = 0;
    downloading = true;
    final token = DownloadCancellationToken();
    _token = token;
    notifyListeners();

    try {
      final downloaded = await _downloader.download(
        updateAsset,
        cancellation: token,
        onProgress: (value) {
          progress = value;
          notifyListeners();
        },
      );
      if (downloaded is DownloadFailure) {
        _finish(downloaded.message);
        return;
      }
      if (token.cancelled) {
        _finish('下载已取消');
        return;
      }

      final verifiedFile = (downloaded as DownloadSuccess).file;
      final installed = await _installer.install(
        updateAsset,
        verifiedFile: verifiedFile,
      );
      downloadedPath = switch (installed) {
        InstallStarted(:final file) =>
          file != null && file.existsSync() ? file.path : null,
        ManualInstallRequired() || InstallFailure() => verifiedFile.path,
      };
      _finish(switch (installed) {
        InstallStarted() => '已启动安装器',
        ManualInstallRequired(:final message) => message,
        InstallFailure(:final message) => message,
      });
    } catch (error) {
      _finish('更新失败：$error');
    }
  }

  void cancel() {
    _token?.cancel();
  }

  void _finish(String result) {
    if (_disposed) return;
    downloading = false;
    _token = null;
    message = result;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    if (_ownsDownloader) _downloader.dispose();
    super.dispose();
  }
}
