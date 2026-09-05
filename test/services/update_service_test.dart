import 'dart:convert';

import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _json(String channel, int build) {
  final pointer =
      'https://github.com/alexcdever/CardMind/releases/download/'
      'channel-$channel/$channel.json';
  return {
    'schemaVersion': 1,
    'appId': 'com.cardmind.v2',
    'channel': channel,
    'version': '1.0.0',
    'build': build,
    'publishedAt': '2026-09-05T00:00:00Z',
    'minimumSupportedVersion': '0.1.0',
    'mandatory': false,
    'releaseNotes': ['notes'],
    'releasePage': 'https://example.com',
    'platforms': {
      for (final platform in ['windows-x64', 'android', 'linux-x64'])
        platform: {
          'artifact': platform == 'windows-x64'
              ? 'CardMind-Setup.exe'
              : platform == 'android'
              ? 'CardMind-Android.apk'
              : 'CardMind-Linux-x64.tar.gz',
          'url': 'https://example.com/$platform',
          'sha256': _sha256,
          'size': 1,
          'channelManifestUrl': pointer,
        },
    },
  };
}

void main() {
  test(
    'uses fixed channel URL and parses real JSON, never release list',
    () async {
      final urls = <Uri>[];
      final service = UpdateService(
        currentBuild: 10,
        currentVersion: '0.1.0-beta.1',
        fetch: (uri) async {
          urls.add(uri);
          return jsonEncode(_json('beta', 11));
        },
      );
      final result = await service.check(UpdateChannel.beta);
      expect(result, isA<UpdateAvailable>());
      expect(urls.single.toString(), UpdateChannel.beta.manifestUrl);
    },
  );

  test(
    'build comparison returns up-to-date when target is not newer',
    () async {
      final service = UpdateService(
        currentBuild: 10,
        currentVersion: '1.0.0',
        fetch: (_) async => jsonEncode(_json('stable', 10)),
      );
      expect(await service.check(UpdateChannel.stable), isA<UpdateUpToDate>());
    },
  );

  test('compares semantic versions when build numbers are equal', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async => jsonEncode(_json('stable', 10)),
    );
    final result = await service.check(UpdateChannel.stable);
    expect(result, isA<UpdateAvailable>());
  });

  test('network and manifest errors become displayable errors', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async => throw StateError('offline'),
    );
    final result = await service.check(UpdateChannel.stable);
    expect(result, isA<UpdateCheckError>());
    expect((result as UpdateCheckError).message, contains('offline'));
  });

  test('timeout becomes a displayable error', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      timeout: const Duration(milliseconds: 10),
      fetch: (_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return '';
      },
    );
    final result = await service.check(UpdateChannel.stable);
    expect(result, isA<UpdateCheckError>());
    expect((result as UpdateCheckError).message, '检查更新超时');
  });

  test('rejects a manifest with an invalid JSON root', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async => '[]',
    );
    expect(await service.check(UpdateChannel.stable), isA<UpdateCheckError>());
  });

  test('rejects a manifest with an invalid release page', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async {
        final data = _json('stable', 11);
        data['releasePage'] = 'http://example.com';
        return jsonEncode(data);
      },
    );
    expect(await service.check(UpdateChannel.stable), isA<UpdateCheckError>());
  });

  test('rejects a manifest with a non-sha256 asset hash', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async {
        final data = _json('stable', 11);
        final first = (data['platforms'] as Map).values.first as Map;
        first['sha256'] = 'bad';
        return jsonEncode(data);
      },
    );
    expect(await service.check(UpdateChannel.stable), isA<UpdateCheckError>());
  });

  test('rejects a manifest without the current platform asset', () async {
    final service = UpdateService(
      currentBuild: 10,
      currentVersion: '0.1.0-beta.1',
      fetch: (_) async {
        final data = _json('stable', 11);
        (data['platforms'] as Map).remove('windows-x64');
        return jsonEncode(data);
      },
    );
    expect(await service.check(UpdateChannel.stable), isA<UpdateCheckError>());
  });
}
