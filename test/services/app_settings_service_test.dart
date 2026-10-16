import 'dart:io';
import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/services/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late AppSettingsService service;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('cardmind-settings-');
    service = AppSettingsService(directoryProvider: () async => directory);
  });
  tearDown(() => directory.deleteSync(recursive: true));
  test(
    'missing config defaults stable and writes exact JSON structure',
    () async {
      expect(await service.readChannel(), UpdateChannel.stable);
      await service.writeChannel(UpdateChannel.beta);
      expect(
        File('${directory.path}/settings.json').readAsStringSync(),
        '{"updateChannel":"beta"}\n',
      );
    },
  );
  test('invalid JSON and channel fall back to stable', () async {
    final file = File('${directory.path}/settings.json');
    file.writeAsStringSync('{bad');
    expect(await service.readChannel(), UpdateChannel.stable);
    file.writeAsStringSync('{"updateChannel":"nightly"}');
    expect(await service.readChannel(), UpdateChannel.stable);
  });
  test(
    'defaults proxy on and preserves channel when saving proxy setting',
    () async {
      await service.writeChannel(UpdateChannel.beta);
      expect(await service.readUseSystemProxy(), isTrue);
      await service.writeUseSystemProxy(false);
      expect(await service.readChannel(), UpdateChannel.beta);
      expect(await service.readUseSystemProxy(), isFalse);
    },
  );

  test('invalid proxy setting falls back to enabled', () async {
    final file = File('${directory.path}/settings.json');
    file.writeAsStringSync('{"updateChannel":"beta","useSystemProxy":"yes"}');
    expect(await service.readChannel(), UpdateChannel.beta);
    expect(await service.readUseSystemProxy(), isTrue);
  });
}
