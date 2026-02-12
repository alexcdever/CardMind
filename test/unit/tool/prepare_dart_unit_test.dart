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
    final v28 = Directory('${ndkRoot.path}/28.2.13676358');
    final v29 = Directory('${ndkRoot.path}/29.0.14206865');
    await v28.create();
    await v29.create();
    await File('${v28.path}/source.properties').writeAsString('Pkg.Revision=28.2.13676358');
    await File('${v29.path}/source.properties').writeAsString('Pkg.Revision=29.0.14206865');

    final selected = selectHighestNdk(ndkRoot);

    expect(selected?.path.endsWith('29.0.14206865'), isTrue);
  });

  test('it_should_ignore_invalid_ndk_versions', () async {
    final temp = await Directory.systemTemp.createTemp('ndk-invalid-test');
    final ndkRoot = Directory('${temp.path}/sdk/ndk');
    await ndkRoot.create(recursive: true);
    final invalid = Directory('${ndkRoot.path}/30.0.99999999');
    final valid = Directory('${ndkRoot.path}/27.0.12077973');
    await invalid.create();
    await valid.create();
    await File('${valid.path}/source.properties')
        .writeAsString('Pkg.Revision=27.0.12077973');

    final selected = selectHighestNdk(ndkRoot);

    expect(selected?.path.endsWith('27.0.12077973'), isTrue);
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

  test('it_should_resolve_apple_rust_targets_for_macos_and_ios', () {
    final targets = resolveAppleRustTargets({
      BuildPlatform.macos,
      BuildPlatform.ios,
    });

    expect(targets, contains('aarch64-apple-darwin'));
    expect(targets, contains('x86_64-apple-darwin'));
    expect(targets, contains('aarch64-apple-ios'));
    expect(targets, contains('x86_64-apple-ios'));
  });

  test('it_should_resolve_flutter_sdk_from_local_properties', () async {
    final temp = await Directory.systemTemp.createTemp('flutter-sdk-test');
    final androidDir = Directory('${temp.path}/android');
    await androidDir.create(recursive: true);
    final localProps = File('${androidDir.path}/local.properties');
    await localProps.writeAsString('flutter.sdk=/tmp/flutter');

    final sdkRoot = resolveFlutterSdkRoot(
      {},
      localPropertiesPath: localProps.path,
    );

    expect(sdkRoot, '/tmp/flutter');
  });

  test('it_should_resolve_flutter_ndk_version_from_sdk', () async {
    final temp = await Directory.systemTemp.createTemp('flutter-ndk-test');
    final file = File(
      '${temp.path}/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      'class FlutterExtension {\\n  val ndkVersion: String = \"28.2.13676358\"\\n}\\n',
    );

    final ndkVersion = resolveFlutterNdkVersion(temp.path);

    expect(ndkVersion, '28.2.13676358');
  });

  test('it_should_parse_java_home_output', () {
    final parsed = parseJavaHomeOutput('/Library/Java/JavaVirtualMachines/jdk17\n');

    expect(parsed, '/Library/Java/JavaVirtualMachines/jdk17');
  });
}
