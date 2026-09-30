import 'dart:io';

import 'package:cardmind/models/update_manifest.dart';
import 'package:cardmind/services/platform_update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asset = UpdateAsset(
    artifact: 'CardMind-Setup.exe',
    url: 'https://example.com/a',
    sha256: '0' * 64,
    size: 1,
  );

  test(
    'Windows starts installer without replacing current executable',
    () async {
      var launched = '';
      final result = await PlatformUpdateInstaller(
        platform: UpdatePlatform.windows,
        startInstaller: (file) async => launched = file.path,
      ).install(asset, verifiedFile: File('C:/temp/CardMind-Setup.exe'));
      expect(result, isA<InstallStarted>());
      expect(launched, contains('CardMind-Setup.exe'));
    },
  );

  test('Android creates content URI and starts system intent', () async {
    Uri? uri;
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.android,
      androidUriProvider: (_) async => Uri.parse('content://test/update.apk'),
      androidInstall: (value) async => uri = value,
    ).install(asset, verifiedFile: File('C:/cache/update.apk'));
    expect(result, isA<InstallStarted>());
    expect((result as InstallStarted).file, isNull);
    expect(uri!.scheme, 'content');
  });

  test('Android cancellation is recoverable', () async {
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.android,
      androidInstall: (_) async => throw const InstallCancelledException(),
    ).install(asset, verifiedFile: File('update.apk'));
    expect(result, isA<InstallFailure>());
    expect((result as InstallFailure).recoverable, isTrue);
  });

  test('Android missing permission is recoverable', () async {
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.android,
      androidUriProvider: (_) async => Uri.parse('content://test/update.apk'),
      androidInstall: (_) async => throw StateError('unknown sources disabled'),
    ).install(asset, verifiedFile: File('update.apk'));
    expect(result, isA<InstallFailure>());
    expect((result as InstallFailure).recoverable, isTrue);
  });

  test('Android URI parsing failure is recoverable', () async {
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.android,
      androidUriProvider: (_) async => Uri.parse('file://unsafe/update.apk'),
      androidInstall: (_) async => throw StateError('invalid content URI'),
    ).install(asset, verifiedFile: File('update.apk'));
    expect(result, isA<InstallFailure>());
    expect((result as InstallFailure).recoverable, isTrue);
  });

  test('Windows installer failure is recoverable', () async {
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.windows,
      startInstaller: (_) async => throw StateError('not executable'),
    ).install(asset, verifiedFile: File('update.exe'));
    expect(result, isA<InstallFailure>());
    expect((result as InstallFailure).recoverable, isTrue);
  });

  test('Linux opens the verified archive', () async {
    File? opened;
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.linux,
      openFile: (file) async => opened = file,
    ).install(asset, verifiedFile: File('update.tar.gz'));
    expect(result, isA<InstallStarted>());
    expect((result as InstallStarted).file!.path, 'update.tar.gz');
    expect(opened!.path, 'update.tar.gz');
  });

  test('Linux reports a failed default opener command', () async {
    String? command;
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.linux,
      commandRunner: (value, arguments) async {
        command = '$value ${arguments.single}';
        return ProcessResult(1, 1, '', 'not found');
      },
    ).install(asset, verifiedFile: File('update.tar.gz'));

    expect(command, 'xdg-open update.tar.gz');
    expect(result, isA<InstallFailure>());
  });

  test('macOS opens the verified package', () async {
    File? opened;
    final result = await PlatformUpdateInstaller(
      platform: UpdatePlatform.macos,
      openFile: (file) async => opened = file,
    ).install(asset, verifiedFile: File('update.dmg'));
    expect(result, isA<InstallStarted>());
    expect((result as InstallStarted).file!.path, 'update.dmg');
    expect(opened!.path, 'update.dmg');
  });
}
