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
}
