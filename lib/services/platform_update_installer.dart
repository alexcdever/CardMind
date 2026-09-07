import 'dart:io';

import 'package:flutter/services.dart';

import '../models/update_manifest.dart';

const _androidUpdateChannel = MethodChannel('com.cardmind.v2/update-installer');

enum UpdatePlatform { windows, android, linux }

sealed class InstallResult {
  const InstallResult();
}

class InstallStarted extends InstallResult {
  const InstallStarted();
}

class InstallFailure extends InstallResult {
  const InstallFailure(this.message, {this.recoverable = true});

  final String message;
  final bool recoverable;
}

class ManualInstallRequired extends InstallResult {
  const ManualInstallRequired(this.message);

  final String message;
}

class InstallCancelledException implements Exception {
  const InstallCancelledException();
}

class PlatformUpdateInstaller {
  PlatformUpdateInstaller({
    required this.platform,
    this.startInstaller,
    this.androidInstall,
    this.androidUriProvider,
  });

  final UpdatePlatform platform;
  final Future<void> Function(File)? startInstaller;
  final Future<void> Function(Uri)? androidInstall;
  final Future<Uri> Function(File)? androidUriProvider;

  Future<InstallResult> install(
    UpdateAsset asset, {
    required File verifiedFile,
  }) async {
    try {
      switch (platform) {
        case UpdatePlatform.windows:
          await (startInstaller ?? _startWindowsInstaller)(verifiedFile);
          return const InstallStarted();
        case UpdatePlatform.android:
          final uri = await (androidUriProvider ?? _defaultAndroidUriProvider)(
            verifiedFile,
          );
          await (androidInstall ?? _startAndroidInstaller)(uri);
          return const InstallStarted();
        case UpdatePlatform.linux:
          return const ManualInstallRequired('已下载，请关闭应用后手动替换');
      }
    } on InstallCancelledException {
      return const InstallFailure('安装已取消');
    } catch (error) {
      return InstallFailure('安装失败：$error');
    }
  }

  static Future<void> _startWindowsInstaller(File file) async {
    final process = await Process.start(file.path, const []);
    if (process.pid <= 0) throw StateError('无法启动安装器');
  }

  static Future<void> _startAndroidInstaller(Uri uri) async {
    await _androidUpdateChannel.invokeMethod<void>('installApk', {
      'uri': uri.toString(),
    });
  }

  static Future<Uri> _defaultAndroidUriProvider(File file) async {
    final uri = await _androidUpdateChannel.invokeMethod<String>('prepareApk', {
      'path': file.path,
    });
    if (uri == null || !uri.startsWith('content://')) {
      throw StateError('Android 未返回有效安装 URI');
    }
    return Uri.parse(uri);
  }
}
