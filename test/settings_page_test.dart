import 'dart:async';
import 'dart:convert';

import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/services/app_settings_service.dart';
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

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _manifest({int build = 10001}) {
  const pointer =
      'https://github.com/alexcdever/CardMind/releases/download/'
      'channel-stable/stable.json'; // manifest fixture uses stable
  final platforms = <String, dynamic>{
    'windows-x64': {
      'artifact': 'CardMind-Setup.exe',
      'url': 'https://example.com/windows',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl': pointer,
    },
    'android': {
      'artifact': 'CardMind-Android.apk',
      'url': 'https://example.com/android',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl': pointer,
    },
    'linux-x64': {
      'artifact': 'CardMind-Linux-x64.tar.gz',
      'url': 'https://example.com/linux',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl': pointer,
    },
  };
  return {
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
    'platforms': platforms,
  };
}

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
        ),
      ),
    );
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
      expect(
        tester
            .widget<RadioGroup<UpdateChannel>>(
              find.byType(RadioGroup<UpdateChannel>),
            )
            .groupValue,
        UpdateChannel.stable,
      );
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
    expect(
      tester
          .widget<RadioGroup<UpdateChannel>>(
            find.byType(RadioGroup<UpdateChannel>),
          )
          .groupValue,
      UpdateChannel.beta,
    );
  });

  testWidgets(
    'update check renders checking, latest, available, and failure states',
    (tester) async {
      final completer = Completer<String>();
      final service = UpdateService(
        currentBuild: 1,
        currentVersion: '0.1.0',
        fetch: (_) => completer.future,
      );
      addTearDown(() {
        if (!completer.isCompleted) completer.complete('');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentVersion: '0.1.0', updates: service),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('check-for-updates')));
      await tester.pump();
      expect(find.text('检查中…'), findsWidgets);
      completer.complete(jsonEncode(_manifest(build: 10002)));
      await tester.pumpAndSettle();
      expect(find.text('发现更新'), findsOneWidget);
      expect(find.text('修复问题'), findsWidgets);

      Future<void> check(Map<String, dynamic> data) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SettingsPage(
              currentVersion: '0.1.0',
              currentBuild: 1,
              updates: UpdateService(
                currentBuild: 1,
                currentVersion: '0.1.0',
                fetch: (_) async => jsonEncode(data),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('check-for-updates')));
        await tester.pumpAndSettle();
      }

      await check(_manifest(build: 1));
      expect(find.text('已是最新版本'), findsOneWidget);
      await check(_manifest(build: 10002));
      expect(find.text('发现更新'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            currentVersion: '0.1.0',
            currentBuild: 1,
            updates: UpdateService(
              currentBuild: 1,
              currentVersion: '0.1.0',
              fetch: (_) async => throw StateError('offline'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('check-for-updates')));
      await tester.pumpAndSettle();
      expect(find.textContaining('检查失败'), findsOneWidget);
    },
  );
}
