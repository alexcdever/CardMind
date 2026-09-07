import 'dart:convert';
import 'dart:io';

import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/models/update_manifest.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/services/app_settings_service.dart';
import 'package:cardmind/services/platform_update_installer.dart';
import 'package:cardmind/services/update_downloader.dart';
import 'package:cardmind/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsFake extends AppSettingsService {
  _SettingsFake(this.channel);

  UpdateChannel channel;

  @override
  Future<UpdateChannel> readChannel() async => channel;

  @override
  Future<void> writeChannel(UpdateChannel value) async => channel = value;
}

class _DownloaderFake extends UpdateDownloader {
  _DownloaderFake(this.result) : super(client: HttpClient());

  final DownloadResult result;

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(1);
    return result;
  }

  @override
  void dispose() {}
}

class _InstallerFake extends PlatformUpdateInstaller {
  _InstallerFake(this.result) : super(platform: UpdatePlatform.windows);

  final InstallResult result;
  File? received;

  @override
  Future<InstallResult> install(
    UpdateAsset asset, {
    required File verifiedFile,
  }) async {
    received = verifiedFile;
    return result;
  }
}

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _manifest({int build = 10001}) => {
  'schemaVersion': 1,
  'appId': 'com.cardmind.v2',
  'channel': 'stable',
  'version': '0.1.0',
  'build': build,
  'publishedAt': '2026-01-01T00:00:00Z',
  'minimumSupportedVersion': '0.1.0',
  'mandatory': false,
  'releaseNotes': ['修复问题'],
  'releasePage': 'https://example.com/release',
  'platforms': {
    'windows-x64': {
      'artifact': 'CardMind-Setup.exe',
      'url': 'https://example.com/windows',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
    'android': {
      'artifact': 'CardMind-Android.apk',
      'url': 'https://example.com/android',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
    'linux-x64': {
      'artifact': 'CardMind-Linux-x64.tar.gz',
      'url': 'https://example.com/linux',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
  },
};

void main() {
  testWidgets('settings page has version, stable default and check control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          currentBuild: 1,
          initialChannel: UpdateChannel.stable,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('正式版'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-for-updates')), findsOneWidget);
  });

  testWidgets(
    'beta selection can be cancelled or confirmed and persists on screen',
    (tester) async {
      final settings = _SettingsFake(UpdateChannel.stable);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentVersion: '1.0.0', settings: settings),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-channel-beta')));
      await tester.pumpAndSettle();
      expect(find.text('切换到测试版？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(settings.channel, UpdateChannel.stable);
      await tester.tap(find.byKey(const ValueKey('update-channel-beta')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(settings.channel, UpdateChannel.beta);
      expect(find.text('测试版'), findsOneWidget);
    },
  );

  testWidgets('settings echoes a persisted channel', (tester) async {
    final settings = _SettingsFake(UpdateChannel.beta);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(currentVersion: '1.0.0', settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试版'), findsOneWidget);
  });

  testWidgets('download button shows progress and installer result', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/cardmind-test-update.exe');
    file.writeAsStringSync('verified');
    addTearDown(() async {
      if (file.existsSync()) await file.delete();
    });
    final downloader = _DownloaderFake(DownloadSuccess(file));
    final installer = _InstallerFake(const InstallStarted());
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 10002)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          initialChannel: UpdateChannel.stable,
          settings: _SettingsFake(UpdateChannel.stable),
          updates: service,
          downloader: downloader,
          installer: installer,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    expect(find.text('发现更新'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download-update')));
    await tester.pump();
    expect(find.text('已启动安装器'), findsOneWidget);
    expect(installer.received, file);
  });

  testWidgets('update check renders an available update', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 10002)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('发现更新'), findsOneWidget);
  });

  testWidgets('update check renders up to date', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('已是最新版本'), findsOneWidget);
  });

  testWidgets('update check renders failure state', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => throw StateError('offline'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('检查失败'), findsOneWidget);
  });
}
