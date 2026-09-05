import 'dart:convert';

import 'package:cardmind/models/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _manifest({
  String appId = 'com.cardmind.v2',
  int schemaVersion = 1,
  String channel = 'stable',
  dynamic build = 10002,
  String version = '1.0.0',
  String minimumSupportedVersion = '0.1.0',
  String releasePage = 'https://github.com/alexcdever/CardMind/releases/tag/v1',
  dynamic releaseNotes = const ['Bug fixes'],
  Map<String, dynamic>? platforms,
}) {
  final defaultPlatforms = <String, dynamic>{
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
      },
  };
  final pointer =
      'https://github.com/alexcdever/CardMind/releases/download/'
      'channel-$channel/$channel.json';
  for (final platform in defaultPlatforms.values) {
    (platform as Map)['channelManifestUrl'] = pointer;
  }
  return <String, dynamic>{
    'schemaVersion': schemaVersion,
    'appId': appId,
    'channel': channel,
    'version': version,
    'build': build,
    'publishedAt': '2026-09-05T00:00:00Z',
    'minimumSupportedVersion': minimumSupportedVersion,
    'mandatory': false,
    'releaseNotes': releaseNotes,
    'releasePage': releasePage,
    'platforms': platforms ?? defaultPlatforms,
  };
}

void main() {
  test('parses valid stable and beta manifests and all platform assets', () {
    for (final channel in ['stable', 'beta']) {
      final result = UpdateManifest.tryParse(
        jsonDecode(jsonEncode(_manifest(channel: channel))),
        channel: channel,
      );
      expect(result, isNotNull);
      expect(
        result!.platforms.keys,
        containsAll(['windows-x64', 'android', 'linux-x64']),
      );
      expect(result.platforms['android']!.url, startsWith('https://'));
    }
  });

  test(
    'rejects invalid identity, schema, channel, urls, build and platform',
    () {
      final cases = [
        _manifest(appId: 'wrong'),
        _manifest(schemaVersion: 2),
        _manifest(channel: 'beta'),
        _manifest(releasePage: 'http://example.com'),
        _manifest(version: '0.1'),
        _manifest(minimumSupportedVersion: '0.1'),
        _manifest(releaseNotes: 'Bug fixes'),
        _manifest(build: 0),
        _manifest(
          platforms: {
            'windows-x64': {
              'artifact': 'CardMind-Setup.exe',
              'url': 'http://bad',
              'sha256': _sha256,
              'size': 1,
              'channelManifestUrl':
                  'https://github.com/alexcdever/CardMind/releases/download/'
                  'channel-stable/stable.json',
            },
          },
        ),
        _manifest(
          platforms: {
            'windows-x64': {
              'artifact': 'CardMind-Setup.exe',
              'url': 'https://example.com/a.exe',
              'sha256': 'bad',
              'size': 1,
              'channelManifestUrl':
                  'https://github.com/alexcdever/CardMind/releases/download/'
                  'channel-stable/stable.json',
            },
          },
        ),
      ];
      for (final value in cases) {
        expect(UpdateManifest.tryParse(value, channel: 'stable'), isNull);
      }
    },
  );

  test('rejects a manifest with a missing required asset field', () {
    final value = _manifest();
    ((value['platforms'] as Map)['windows-x64'] as Map).remove('artifact');
    expect(UpdateManifest.tryParse(value, channel: 'stable'), isNull);
  });

  test('reads the parsed artifact name', () {
    final result = UpdateManifest.tryParse(_manifest(), channel: 'stable');
    expect(result!.currentAsset!.artifact, 'CardMind-Setup.exe');
  });
}
