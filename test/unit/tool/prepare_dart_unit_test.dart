import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/prepare.dart';

void main() {
  test('it_should_resolve_default_platforms_for_macos', () {
    final platforms = resolveDefaultPlatforms(HostPlatform.macos);

    expect(platforms, {
      BuildPlatform.android,
      BuildPlatform.ios,
      BuildPlatform.macos,
    });
  });

  test('it_should_reject_unsupported_platforms', () {
    final supported = resolveDefaultPlatforms(HostPlatform.windows);
    final requested = {BuildPlatform.ios};

    final result = validateRequestedPlatforms(supported, requested);

    expect(result.isValid, isFalse);
  });

  test('it_should_select_highest_ndk_version', () async {
    final temp = await Directory.systemTemp.createTemp('ndk-test');
    final sdk = Directory('${temp.path}/sdk');
    final ndkRoot = Directory('${sdk.path}/ndk');
    await ndkRoot.create(recursive: true);
    await Directory('${ndkRoot.path}/28.2.13676358').create();
    await Directory('${ndkRoot.path}/29.0.14206865').create();

    final selected = selectHighestNdk(ndkRoot);

    expect(selected?.path.endsWith('29.0.14206865'), isTrue);
  });

  test('it_should_choose_existing_prebuilt_dir', () async {
    final temp = await Directory.systemTemp.createTemp('prebuilt-test');
    final ndk = Directory('${temp.path}/ndk');
    final prebuilt = Directory(
      '${ndk.path}/toolchains/llvm/prebuilt/darwin-x86_64',
    );
    await prebuilt.create(recursive: true);

    final selected = selectPrebuiltDir(ndk, HostPlatform.macos);

    expect(selected?.path.endsWith('darwin-x86_64'), isTrue);
  });

  test('it_should_write_and_read_prepare_env', () async {
    final temp = await Directory.systemTemp.createTemp('env-test');
    final file = File('${temp.path}/prepare_env.json');
    final env = {'ANDROID_NDK_HOME': '/tmp/ndk', 'PATH': '/tmp/bin'};

    await writePrepareEnv(file, env);
    final loaded = await readPrepareEnv(file);

    expect(loaded['ANDROID_NDK_HOME'], '/tmp/ndk');
    expect(loaded['PATH'], '/tmp/bin');
  });
}
