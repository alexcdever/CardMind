import 'dart:async';
import 'dart:io';

import 'package:cardmind/models/update_manifest.dart';
import 'package:cardmind/services/platform_update_installer.dart';
import 'package:cardmind/services/update_download_manager.dart';
import 'package:cardmind/services/update_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

final _asset = UpdateAsset(
  artifact: 'update.exe',
  url: 'https://example.com/update.exe',
  sha256: '0' * 64,
  size: 1,
);

class _DeferredDownloader extends UpdateDownloader {
  _DeferredDownloader(this.result) : super(client: HttpClient());

  final DownloadResult result;
  final completer = Completer<void>();
  DownloadCancellationToken? token;
  var disposed = false;

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    token = cancellation;
    await completer.future;
    return result;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _ImmediateDownloader extends UpdateDownloader {
  _ImmediateDownloader(this.result) : super(client: HttpClient());

  final DownloadResult result;

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async => result;
}

class _InstallerFake extends PlatformUpdateInstaller {
  _InstallerFake(this.result) : super(platform: UpdatePlatform.windows);

  final InstallResult result;
  var calls = 0;

  @override
  Future<InstallResult> install(
    UpdateAsset asset, {
    required File verifiedFile,
  }) async {
    calls++;
    return result;
  }
}

void main() {
  test(
    'download survives manager listeners being removed and installs on completion',
    () async {
      final file = File('${Directory.systemTemp.path}/manager-update.exe');
      file.writeAsStringSync('update');
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });
      final downloader = _DeferredDownloader(DownloadSuccess(file));
      final installer = _InstallerFake(InstallStarted(file));
      final manager = UpdateDownloadManager(
        downloader: downloader,
        installer: installer,
      );
      final future = manager.start(_asset);
      manager.removeListener(() {});
      downloader.completer.complete();
      await future;
      expect(installer.calls, 1);
      expect(manager.downloading, isFalse);
      expect(manager.message, '已启动安装器');
      expect(manager.downloadedPath, file.path);
    },
  );

  test('Android install does not expose the deleted source path', () async {
    final file = File('${Directory.systemTemp.path}/manager-android.apk');
    file.writeAsStringSync('update');
    addTearDown(() async {
      if (file.existsSync()) await file.delete();
    });
    final manager = UpdateDownloadManager(
      downloader: _ImmediateDownloader(DownloadSuccess(file)),
      installer: _InstallerFake(const InstallStarted()),
    );

    await manager.start(_asset);

    expect(manager.message, '已启动安装器');
    expect(manager.downloadedPath, isNull);
  });

  test('explicit cancellation wins the success/install race', () async {
    final file = File('${Directory.systemTemp.path}/manager-cancel.exe');
    file.writeAsStringSync('update');
    addTearDown(() async {
      if (file.existsSync()) await file.delete();
    });
    final downloader = _DeferredDownloader(DownloadSuccess(file));
    final installer = _InstallerFake(const InstallStarted());
    final manager = UpdateDownloadManager(
      downloader: downloader,
      installer: installer,
    );
    final future = manager.start(_asset);
    await Future<void>.delayed(Duration.zero);
    manager.cancel();
    downloader.completer.complete();
    await future;
    expect(installer.calls, 0);
    expect(manager.message, '下载已取消');
    expect(manager.downloading, isFalse);
  });

  test(
    'downloader and installer exceptions become visible failure state',
    () async {
      final manager = UpdateDownloadManager(
        downloader: _ThrowingDownloader(),
        installer: _InstallerFake(const InstallStarted()),
      );
      await manager.start(_asset);
      expect(manager.downloading, isFalse);
      expect(manager.message, contains('更新失败：'));

      final file = File('${Directory.systemTemp.path}/manager-installer.exe');
      file.writeAsStringSync('update');
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });
      final installerManager = UpdateDownloadManager(
        downloader: _ImmediateDownloader(DownloadSuccess(file)),
        installer: _ThrowingInstaller(),
      );
      await installerManager.start(_asset);
      expect(installerManager.downloading, isFalse);
      expect(installerManager.message, contains('更新失败：'));
    },
  );

  test(
    'dispose cancels an active injected downloader without disposing it',
    () async {
      final downloader = _DeferredDownloader(
        const DownloadFailure('cancelled'),
      );
      final manager = UpdateDownloadManager(downloader: downloader);
      final future = manager.start(_asset);
      await Future<void>.delayed(Duration.zero);
      manager.dispose();
      expect(downloader.token?.cancelled, isTrue);
      expect(downloader.disposed, isFalse);
      downloader.completer.complete();
      await future;
    },
  );
}

class _ThrowingDownloader extends UpdateDownloader {
  _ThrowingDownloader() : super(client: HttpClient());

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async => throw StateError('downloader exploded');
}

class _ThrowingInstaller extends PlatformUpdateInstaller {
  _ThrowingInstaller() : super(platform: UpdatePlatform.windows);

  @override
  Future<InstallResult> install(
    UpdateAsset asset, {
    required File verifiedFile,
  }) async => throw StateError('installer exploded');
}
