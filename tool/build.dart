#!/usr/bin/env dart

import 'dart:io';
import 'dart:math';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String magenta = '\x1B[35m';
const String cyan = '\x1B[36m';
const String bold = '\x1B[1m';
const String buildMode = 'release';

String? _cargoBinPath;

enum BuildPlatform { android, linux, windows, macos, ios }

class BuildConfig {
  final Set<BuildPlatform> platforms;

  BuildConfig({required this.platforms});
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.contains('-h') ||
      arguments.contains('--help')) {
    printUsage();
    exit(0);
  }

  final command = arguments.first;
  if (command != 'bridge' && command != 'app') {
    printUsage(error: '未知子命令: $command');
    exit(2);
  }

  final platformArgs = arguments.sublist(1);
  final platforms = parsePlatforms(platformArgs);
  if (platforms == null) {
    printUsage(error: '平台参数无效: ${platformArgs.join(' ')}');
    exit(2);
  }

  final config = BuildConfig(platforms: platforms);

  if (command == 'bridge') {
    await runBridge(config);
    return;
  }

  await runApp(config);
}

Set<BuildPlatform>? parsePlatforms(List<String> args) {
  final platforms = <BuildPlatform>{};

  for (final arg in args) {
    switch (arg) {
      case '--android':
        platforms.add(BuildPlatform.android);
        break;
      case '--linux':
        platforms.add(BuildPlatform.linux);
        break;
      case '--windows':
        platforms.add(BuildPlatform.windows);
        break;
      case '--macos':
        platforms.add(BuildPlatform.macos);
        break;
      case '--ios':
        platforms.add(BuildPlatform.ios);
        break;
      default:
        return null;
    }
  }

  if (platforms.isEmpty) {
    if (Platform.isLinux) {
      platforms.addAll([BuildPlatform.android, BuildPlatform.linux]);
    } else if (Platform.isWindows) {
      platforms.addAll([BuildPlatform.android, BuildPlatform.windows]);
    } else if (Platform.isMacOS) {
      platforms.addAll([
        BuildPlatform.android,
        BuildPlatform.ios,
        BuildPlatform.macos,
      ]);
    }
  }

  return platforms;
}

Future<bool> prepareBridge(BuildConfig config) async {
  printSection('📋 检查构建环境');
  if (!await checkEnvironment(config)) {
    printError('环境检查失败，无法继续');
    return false;
  }

  printSection('🔧 生成桥接代码');
  if (!await generateBridge()) {
    printError('桥接代码生成失败');
    return false;
  }

  printSection('🎨 格式化生成代码');
  await formatGeneratedCode();

  printSection('🦀 构建 Rust 动态库');
  if (!await buildRustLibraries(config)) {
    printError('Rust 库构建失败');
    return false;
  }

  if (!await createXcframeworkIfNeeded(config)) {
    printError('xcframework 生成或配置失败');
    return false;
  }

  return true;
}

Future<void> runBridge(BuildConfig config) async {
  printHeader('🔨 CardMind 构建工具');
  if (!await prepareBridge(config)) {
    exit(1);
  }
  printSuccess('✅ 桥接构建完成');
}

Future<void> runApp(BuildConfig config) async {
  printHeader('🔨 CardMind 构建工具');
  if (!await prepareBridge(config)) {
    exit(1);
  }

  printSection('📱 构建 Flutter 应用');
  var hasErrors = false;
  for (final platform in config.platforms) {
    if (!await buildPlatform(platform)) {
      hasErrors = true;
    }
  }

  if (hasErrors) {
    printError('部分平台构建失败，请查看上方错误信息');
    exit(1);
  }

  printSuccess('✅ 所有平台构建成功');
}

void printUsage({String? error}) {
  if (error != null) {
    stderr.writeln('$red✗$reset $error');
    stderr.writeln('');
  }

  stdout.writeln('CardMind 构建脚本');
  stdout.writeln('');
  stdout.writeln('用法:');
  stdout.writeln(
    '  dart tool/build.dart bridge [--android|--linux|--windows|--macos|--ios]',
  );
  stdout.writeln(
    '  dart tool/build.dart app    [--android|--linux|--windows|--macos|--ios]',
  );
  stdout.writeln('');
  stdout.writeln('未指定平台参数时，默认构建当前系统可构建的全部平台。');
}

void printHeader(String message) {
  stdout.writeln("\n$bold$blue${'=' * 70}");
  stdout.writeln('  $message');
  stdout.writeln("${'=' * 70}$reset\n");
}

void printSection(String message) {
  stdout.writeln('\n$bold$magenta━━━ $message ━━━$reset\n');
}

void printInfo(String message) {
  stdout.writeln('$blue$message$reset');
}

void printSuccess(String message) {
  stdout.writeln('$green$message$reset');
}

void printWarning(String message) {
  stdout.writeln('$yellow⚠ $message$reset');
}

void printError(String message) {
  stderr.writeln('$red✗ $message$reset');
}

Future<String?> getCargoBinPath({bool forceRefresh = false}) async {
  if (_cargoBinPath != null && !forceRefresh) {
    return _cargoBinPath;
  }

  final home = Platform.environment['HOME'];
  if (home != null) {
    final candidate = '$home/.cargo/bin';
    if (Directory(candidate).existsSync()) {
      _cargoBinPath = candidate;
      return _cargoBinPath;
    }
  }

  final result = await Process.run('cargo', ['env', '--prefix', 'HOME']);
  if (result.exitCode == 0) {
    final cargoHome = result.stdout.toString().trim();
    _cargoBinPath = '$cargoHome/.cargo/bin';
    return _cargoBinPath;
  }

  return null;
}

Future<String?> getCodegenPath({bool forceRefresh = false}) async {
  final cargoBin = await getCargoBinPath(forceRefresh: forceRefresh);
  if (cargoBin == null) {
    return null;
  }
  final executable = Platform.isWindows
      ? 'flutter_rust_bridge_codegen.exe'
      : 'flutter_rust_bridge_codegen';
  final path = '$cargoBin/$executable';
  if (!File(path).existsSync()) {
    return null;
  }
  return path;
}

Future<bool> checkEnvironment(BuildConfig config) async {
  var success = true;

  printStep('检查 Flutter...');
  if (await runCommand(
    'flutter',
    ['--version'],
    quiet: true,
    description: 'Flutter version',
  )) {
    printSuccess('Flutter 已安装');
  } else {
    printError('Flutter 未安装');
    success = false;
  }

  printStep('检查 Rust...');
  if (await runCommand(
    'cargo',
    ['--version'],
    quiet: true,
    description: 'Cargo version',
  )) {
    printSuccess('Rust 已安装');
  } else {
    printError('Rust 未安装');
    success = false;
  }

  printStep('检查 flutter_rust_bridge_codegen...');
  final codegenPath = await getCodegenPath();
  if (codegenPath != null &&
      await runCommand(
        codegenPath,
        ['--version'],
        quiet: true,
        description: 'FRB version',
      )) {
    printSuccess('flutter_rust_bridge_codegen 已安装');
  } else {
    printWarning('flutter_rust_bridge_codegen 未安装，尝试安装中...');
    if (await runCommand('cargo', [
      'install',
      'flutter_rust_bridge_codegen',
    ], description: 'Install FRB')) {
      final installedPath = await getCodegenPath(forceRefresh: true);
      if (installedPath != null &&
          await runCommand(
            installedPath,
            ['--version'],
            quiet: true,
            description: 'FRB version',
          )) {
        printSuccess('flutter_rust_bridge_codegen 安装成功');
      } else {
        printError('flutter_rust_bridge_codegen 安装失败');
        success = false;
      }
    } else {
      printError('flutter_rust_bridge_codegen 安装失败');
      success = false;
    }
  }

  if (!Directory('rust').existsSync()) {
    printError('未找到 rust/ 目录');
    success = false;
  }

  if (!File('pubspec.yaml').existsSync()) {
    printError('未找到 pubspec.yaml，请在项目根目录运行');
    success = false;
  }

  for (final platform in config.platforms) {
    success = await checkPlatformEnvironment(platform) && success;
  }

  return success;
}

Future<bool> generateBridge() async {
  final codegenPath = await getCodegenPath();
  if (codegenPath == null) {
    printError('无法找到 flutter_rust_bridge_codegen，请确认已安装');
    return false;
  }

  final args = [
    'generate',
    '--rust-input',
    'cardmind_rust::api',
    '--dart-output',
    'lib/bridge/',
    '--c-output',
    'rust/src/bridge_generated.h',
  ];

  printInfo('运行: $codegenPath ${args.join(' ')}');
  final generated = await runCommand(
    codegenPath,
    args,
    description: 'Generate FRB bindings',
  );
  if (!generated) {
    return false;
  }
  return suppressGeneratedRustWarnings();
}

Future<bool> suppressGeneratedRustWarnings() async {
  final generatedFile = File('rust/src/frb_generated.rs');
  if (!generatedFile.existsSync()) {
    printError('未找到 rust/src/frb_generated.rs，无法注入告警抑制');
    return false;
  }

  const allowLine = '#![allow(warnings)]';
  try {
    final content = await generatedFile.readAsString();
    if (content.contains(allowLine)) {
      return true;
    }

    final lines = content.split('\n');
    var insertAt = 0;
    while (insertAt < lines.length && lines[insertAt].startsWith('//')) {
      insertAt++;
    }
    lines.insert(insertAt, allowLine);
    lines.insert(insertAt + 1, '');

    final updated = lines.join('\n');
    await generatedFile.writeAsString(
      updated.endsWith('\n') ? updated : '$updated\n',
    );
    return true;
  } catch (error) {
    printError('注入告警抑制失败: $error');
    return false;
  }
}

Future<void> formatGeneratedCode() async {
  final dartFormat = await runCommand('dart', [
    'format',
    'lib/bridge/',
  ], description: 'Dart format');
  if (!dartFormat) {
    printWarning('Dart 格式化失败（非致命）');
  }

  final rustFormat = await runCommand(
    'cargo',
    ['fmt'],
    workingDirectory: 'rust',
    description: 'Cargo fmt',
  );
  if (!rustFormat) {
    printWarning('Rust 格式化失败（非致命）');
  }
}

Future<bool> checkPlatformEnvironment(BuildPlatform platform) async {
  switch (platform) {
    case BuildPlatform.android:
      printStep('检查 Android 环境...');
      final ndkHome = Platform.environment['ANDROID_NDK_HOME'];
      if (ndkHome != null && Directory(ndkHome).existsSync()) {
        printSuccess('Android NDK: $ndkHome');
      } else {
        printWarning('ANDROID_NDK_HOME 未设置或目录不存在');
      }

      final targets = [
        'aarch64-linux-android',
        'armv7-linux-androideabi',
        'x86_64-linux-android',
        'i686-linux-android',
      ];
      final rustupOk = await runCommand(
        'rustup',
        ['target', 'list', '--installed'],
        quiet: true,
        description: 'Check Rust target',
      );
      if (!rustupOk) {
        printWarning('Rust Android 目标未完全安装，尝试安装...');
        await runCommand('rustup', [
          'target',
          'add',
          ...targets,
        ], description: 'Add Android targets');
      }

      if (!await runCommand(
        'cargo-ndk',
        ['--version'],
        quiet: true,
        description: 'cargo-ndk version',
      )) {
        printWarning('cargo-ndk 未安装，尝试安装...');
        await runCommand('cargo', [
          'install',
          'cargo-ndk',
        ], description: 'Install cargo-ndk');
      }
      return true;

    case BuildPlatform.linux:
      printStep('检查 Linux 环境...');
      if (!Platform.isLinux) {
        printWarning('当前系统不是 Linux，跳过 Linux 平台构建');
        return false;
      }

      var pkgConfigResult = await runCommand(
        '/usr/bin/pkg-config',
        ['--exists', 'gtk+-3.0'],
        quiet: true,
        description: 'Check GTK3',
      );
      if (!pkgConfigResult) {
        pkgConfigResult = await runCommand(
          'pkg-config',
          ['--exists', 'gtk+-3.0'],
          quiet: true,
          description: 'Check GTK3',
        );
      }
      if (!pkgConfigResult) {
        printWarning('GTK 3 开发库未安装，请安装 libgtk-3-dev 和 pkg-config');
        return false;
      }
      printSuccess('GTK 3 开发库已安装');
      return true;

    case BuildPlatform.windows:
      printStep('检查 Windows 环境...');
      if (!Platform.isWindows) {
        printWarning('当前系统不是 Windows，跳过 Windows 平台构建');
        return false;
      }
      printSuccess('Windows 环境正常');
      return true;

    case BuildPlatform.macos:
      printStep('检查 macOS 环境...');
      if (!Platform.isMacOS) {
        printWarning('当前系统不是 macOS，跳过 macOS 平台构建');
        return false;
      }
      printSuccess('macOS 环境正常');
      return true;

    case BuildPlatform.ios:
      printStep('检查 iOS 环境...');
      if (!Platform.isMacOS) {
        printWarning('当前系统不是 macOS，跳过 iOS 平台构建');
        return false;
      }
      if (await runCommand(
        'xcodebuild',
        ['-version'],
        quiet: true,
        description: 'Xcode version',
      )) {
        printSuccess('Xcode 已安装');
        return true;
      }
      printError('Xcode 未安装');
      return false;
  }
}

Map<String, String> getAndroidEnvironment() {
  final env = Map<String, String>.from(Platform.environment);

  final ndkHome = env['ANDROID_NDK_HOME'];
  if (ndkHome == null || ndkHome.isEmpty) {
    printWarning('ANDROID_NDK_HOME 未设置，尝试自动检测...');
    final possiblePaths = [
      '${env['HOME']}/android-sdk/ndk/28.2.13676358',
      '${env['HOME']}/android-sdk/ndk/26.1.10909125',
      '${env['HOME']}/Android/Sdk/ndk/28.2.13676358',
      '${env['HOME']}/Android/Sdk/ndk/26.1.10909125',
    ];

    for (final path in possiblePaths) {
      if (Directory(path).existsSync()) {
        env['ANDROID_NDK_HOME'] = path;
        printInfo('自动检测到 NDK: $path');
        break;
      }
    }
  }

  final resolvedNdk = env['ANDROID_NDK_HOME'];
  if (resolvedNdk == null) {
    printError('无法找到 Android NDK，请设置 ANDROID_NDK_HOME 环境变量');
    return env;
  }

  final toolchainPath =
      '$resolvedNdk/toolchains/llvm/prebuilt/linux-x86_64/bin';
  env['PATH'] = '${env['PATH']}:$toolchainPath';

  env['CC_aarch64_linux_android'] = 'aarch64-linux-android21-clang';
  env['CXX_aarch64_linux_android'] = 'aarch64-linux-android21-clang++';
  env['AR_aarch64_linux_android'] = 'llvm-ar';
  env['CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER'] =
      'aarch64-linux-android21-clang';

  env['CC_armv7_linux_androideabi'] = 'armv7a-linux-androideabi21-clang';
  env['CXX_armv7_linux_androideabi'] = 'armv7a-linux-androideabi21-clang++';
  env['AR_armv7_linux_androideabi'] = 'llvm-ar';
  env['CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER'] =
      'armv7a-linux-androideabi21-clang';

  env['CC_i686_linux_android'] = 'i686-linux-android21-clang';
  env['CXX_i686_linux_android'] = 'i686-linux-android21-clang++';
  env['AR_i686_linux_android'] = 'llvm-ar';
  env['CARGO_TARGET_I686_LINUX_ANDROID_LINKER'] = 'i686-linux-android21-clang';

  env['CC_x86_64_linux_android'] = 'x86_64-linux-android21-clang';
  env['CXX_x86_64_linux_android'] = 'x86_64-linux-android21-clang++';
  env['AR_x86_64_linux_android'] = 'llvm-ar';
  env['CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER'] =
      'x86_64-linux-android21-clang';

  return env;
}

Future<bool> buildRustLibraries(BuildConfig config) async {
  for (final platform in config.platforms) {
    printStep('构建 ${platform.name} Rust 库...');

    switch (platform) {
      case BuildPlatform.android:
        final targets = [
          'aarch64-linux-android',
          'armv7-linux-androideabi',
          'x86_64-linux-android',
          'i686-linux-android',
        ];
        final androidEnv = getAndroidEnvironment();

        for (final target in targets) {
          printInfo('  构建 $target...');
          if (!await runCommand(
            'cargo',
            ['build', '--release', '--target', target],
            workingDirectory: 'rust',
            environment: androidEnv,
            description: 'Build Rust for $target',
          )) {
            printError('$target 构建失败');
            return false;
          }
        }

        if (!await copyAndroidLibraries()) {
          return false;
        }
        printSuccess('Android Rust 库构建成功');
        break;

      case BuildPlatform.linux:
        if (!await runCommand(
          'cargo',
          ['build', '--release'],
          workingDirectory: 'rust',
          description: 'Build Rust for Linux',
        )) {
          printError('Linux Rust 库构建失败');
          return false;
        }
        printSuccess('Linux Rust 库构建成功');
        break;

      case BuildPlatform.windows:
        if (!await runCommand(
          'cargo',
          ['build', '--release'],
          workingDirectory: 'rust',
          description: 'Build Rust for Windows',
        )) {
          printError('Windows Rust 库构建失败');
          return false;
        }
        printSuccess('Windows Rust 库构建成功');
        break;

      case BuildPlatform.macos:
        if (!await runCommand(
          'cargo',
          ['build', '--release'],
          workingDirectory: 'rust',
          description: 'Build Rust for macOS',
        )) {
          printError('macOS Rust 库构建失败');
          return false;
        }
        printSuccess('macOS Rust 库构建成功');
        break;

      case BuildPlatform.ios:
        final targets = ['aarch64-apple-ios', 'x86_64-apple-ios'];
        for (final target in targets) {
          printInfo('  构建 $target...');
          if (!await runCommand(
            'cargo',
            ['build', '--release', '--target', target],
            workingDirectory: 'rust',
            description: 'Build Rust for $target',
          )) {
            printError('$target 构建失败');
            return false;
          }
        }
        printSuccess('iOS Rust 库构建成功');
        break;
    }
  }

  return true;
}

Future<bool> buildPlatform(BuildPlatform platform) async {
  printStep('构建 ${platform.name} 应用...');

  switch (platform) {
    case BuildPlatform.android:
      if (!await runCommand('flutter', [
        'build',
        'apk',
        '--release',
      ], description: 'Build Android APK')) {
        printError('Android APK 构建失败');
        return false;
      }
      printSuccess('✅ Android APK 构建成功');
      printInfo('   输出: build/app/outputs/flutter-apk/app-release.apk');
      return true;

    case BuildPlatform.linux:
      final env = Map<String, String>.from(Platform.environment);
      if (!env.containsKey('PKG_CONFIG_PATH')) {
        env['PATH'] = '/usr/bin:${env['PATH']}';
      }
      if (!await runCommand(
        'flutter',
        ['build', 'linux', '--release'],
        environment: env,
        description: 'Build Linux app',
      )) {
        printError('Linux 应用构建失败');
        return false;
      }

      final rustLib = 'rust/target/$buildMode/libcardmind_rust.so';
      final bundleLib =
          'build/linux/x64/$buildMode/bundle/lib/libcardmind_rust.so';
      try {
        File(bundleLib).parent.createSync(recursive: true);
        File(rustLib).copySync(bundleLib);
        printInfo('  复制 Rust 库: $rustLib -> $bundleLib');
      } catch (e) {
        printError('复制 Rust 库失败: $e');
        return false;
      }

      printSuccess('✅ Linux 应用构建成功');
      printInfo('   输出: build/linux/x64/$buildMode/bundle/');
      return true;

    case BuildPlatform.windows:
      if (!await runCommand('flutter', [
        'build',
        'windows',
        '--release',
      ], description: 'Build Windows app')) {
        printError('Windows 应用构建失败');
        return false;
      }

      final rustLib = 'rust/target/$buildMode/cardmind_rust.dll';
      final bundleLib = 'build/windows/x64/runner/Release/cardmind_rust.dll';
      try {
        File(bundleLib).parent.createSync(recursive: true);
        File(rustLib).copySync(bundleLib);
        printInfo('  复制 Rust 库: $rustLib -> $bundleLib');
      } catch (e) {
        printError('复制 Rust 库失败: $e');
        return false;
      }

      printSuccess('✅ Windows 应用构建成功');
      printInfo('   输出: build/windows/x64/runner/Release/');
      return true;

    case BuildPlatform.macos:
      if (!await runCommand('flutter', [
        'build',
        'macos',
        '--release',
      ], description: 'Build macOS app')) {
        printError('macOS 应用构建失败');
        return false;
      }
      printSuccess('✅ macOS 应用构建成功');
      printInfo('   输出: build/macos/Build/Products/Release/');
      return true;

    case BuildPlatform.ios:
      if (!await runCommand('flutter', [
        'build',
        'ios',
        '--release',
        '--no-codesign',
      ], description: 'Build iOS app')) {
        printError('iOS 应用构建失败');
        return false;
      }
      printSuccess('✅ iOS 应用构建成功');
      printInfo('   输出: build/ios/iphoneos/');
      return true;
  }
}

Future<bool> copyAndroidLibraries() async {
  const jniLibsDir = 'android/app/src/main/jniLibs';

  final archMap = {
    'aarch64-linux-android': 'arm64-v8a',
    'armv7-linux-androideabi': 'armeabi-v7a',
    'x86_64-linux-android': 'x86_64',
    'i686-linux-android': 'x86',
  };

  for (final entry in archMap.entries) {
    final rustTarget = entry.key;
    final androidAbi = entry.value;

    final sourceLib = 'rust/target/$rustTarget/$buildMode/libcardmind_rust.so';
    final targetDir = '$jniLibsDir/$androidAbi';
    final targetLib = '$targetDir/libcardmind_rust.so';

    Directory(targetDir).createSync(recursive: true);

    try {
      File(sourceLib).copySync(targetLib);
      printInfo('  复制 $androidAbi: $sourceLib -> $targetLib');
    } catch (e) {
      printError('复制失败 $androidAbi: $e');
      return false;
    }
  }

  return true;
}

Future<bool> createXcframeworkIfNeeded(BuildConfig config) async {
  final includeMacos = config.platforms.contains(BuildPlatform.macos);
  final includeIos = config.platforms.contains(BuildPlatform.ios);
  if (!includeMacos && !includeIos) {
    return true;
  }

  if (!Platform.isMacOS) {
    printError('生成 xcframework 需要在 macOS 上运行');
    return false;
  }

  final args = <String>['-create-xcframework'];
  if (includeMacos) {
    final macosLib = 'rust/target/$buildMode/libcardmind_rust.a';
    if (!File(macosLib).existsSync()) {
      printError('未找到 macOS 静态库: $macosLib');
      return false;
    }
    args.addAll(['-library', macosLib, '-headers', 'rust/src']);
  }

  if (includeIos) {
    final iosDeviceLib =
        'rust/target/aarch64-apple-ios/$buildMode/libcardmind_rust.a';
    final iosSimLib =
        'rust/target/x86_64-apple-ios/$buildMode/libcardmind_rust.a';
    if (!File(iosDeviceLib).existsSync()) {
      printError('未找到 iOS 设备静态库: $iosDeviceLib');
      return false;
    }
    if (!File(iosSimLib).existsSync()) {
      printError('未找到 iOS 模拟器静态库: $iosSimLib');
      return false;
    }
    args.addAll(['-library', iosDeviceLib, '-headers', 'rust/src']);
    args.addAll(['-library', iosSimLib, '-headers', 'rust/src']);
  }

  final tempDir = await Directory.systemTemp.createTemp(
    'cardmind_xcframework_',
  );
  final outputPath = '${tempDir.path}/cardmind_rust.xcframework';
  args.addAll(['-output', outputPath]);

  if (!await runCommand(
    'xcodebuild',
    args,
    description: 'Create xcframework',
  )) {
    return false;
  }

  if (includeMacos) {
    final dest = 'macos/Runner/Frameworks/cardmind_rust.xcframework';
    await replaceDirectory(outputPath, dest);
    if (!await patchXcodeProject(
      'macos/Runner.xcodeproj/project.pbxproj',
      'Runner/Frameworks/cardmind_rust.xcframework',
      embedPhaseName: 'Bundle Framework',
    )) {
      return false;
    }
  }

  if (includeIos) {
    final dest = 'ios/Runner/Frameworks/cardmind_rust.xcframework';
    await replaceDirectory(outputPath, dest);
    if (!await patchXcodeProject(
      'ios/Runner.xcodeproj/project.pbxproj',
      'Runner/Frameworks/cardmind_rust.xcframework',
      embedPhaseName: 'Embed Frameworks',
    )) {
      return false;
    }
  }

  return true;
}

Future<void> replaceDirectory(String sourcePath, String destPath) async {
  final sourceDir = Directory(sourcePath);
  final destDir = Directory(destPath);

  if (destDir.existsSync()) {
    destDir.deleteSync(recursive: true);
  }
  destDir.createSync(recursive: true);
  await copyDirectory(sourceDir, destDir);
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }

  await for (final entity in source.list(recursive: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    final newPath = '${destination.path}/$name';
    if (entity is Directory) {
      await copyDirectory(entity, Directory(newPath));
    } else if (entity is File) {
      await entity.copy(newPath);
    }
  }
}

Future<bool> patchXcodeProject(
  String projectPath,
  String frameworkPath, {
  required String embedPhaseName,
}) async {
  final file = File(projectPath);
  if (!file.existsSync()) {
    printError('Xcode 工程不存在: $projectPath');
    return false;
  }

  var contents = await file.readAsString();
  if (contents.contains('cardmind_rust.xcframework')) {
    printInfo('Xcode 工程已包含 cardmind_rust.xcframework: $projectPath');
    return true;
  }

  final fileRefId = generatePbxId();
  final frameworkBuildId = generatePbxId();
  final embedBuildId = generatePbxId();

  final fileRefLine =
      '\t\t$fileRefId /* cardmind_rust.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = cardmind_rust.xcframework; path = ${_quote(frameworkPath)}; sourceTree = \"<group>\"; };';
  final frameworkBuildLine =
      '\t\t$frameworkBuildId /* cardmind_rust.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = $fileRefId /* cardmind_rust.xcframework */; };';
  final embedBuildLine =
      '\t\t$embedBuildId /* cardmind_rust.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = $fileRefId /* cardmind_rust.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };';

  final lines = contents.split('\n');
  if (!insertBeforeSectionEnd(lines, 'PBXFileReference', fileRefLine)) {
    printError('无法写入 PBXFileReference section');
    return false;
  }
  if (!insertBeforeSectionEnd(lines, 'PBXBuildFile', frameworkBuildLine)) {
    printError('无法写入 PBXBuildFile section');
    return false;
  }
  insertBeforeSectionEnd(lines, 'PBXBuildFile', embedBuildLine);

  final frameworksGroupId =
      findFrameworksGroupId(lines) ?? findMainGroupId(lines);
  if (frameworksGroupId == null ||
      !addLineToObjectList(
        lines,
        frameworksGroupId,
        'children',
        '\t\t\t\t$fileRefId /* cardmind_rust.xcframework */,',
      )) {
    printError('无法将 xcframework 添加到 Frameworks 组');
    return false;
  }

  final frameworksPhaseId = findRunnerBuildPhaseId(lines, 'Frameworks') ?? '';
  if (frameworksPhaseId.isEmpty ||
      !addLineToObjectList(
        lines,
        frameworksPhaseId,
        'files',
        '\t\t\t\t$frameworkBuildId /* cardmind_rust.xcframework in Frameworks */,',
      )) {
    printError('无法将 xcframework 添加到 Frameworks build phase');
    return false;
  }

  final embedPhaseId = findRunnerBuildPhaseId(lines, embedPhaseName);
  if (embedPhaseId != null) {
    addLineToObjectList(
      lines,
      embedPhaseId,
      'files',
      '\t\t\t\t$embedBuildId /* cardmind_rust.xcframework in Embed Frameworks */,',
    );
  } else {
    printWarning('未找到 $embedPhaseName build phase，跳过嵌入设置');
  }

  ensureFrameworkSearchPaths(lines);

  await file.writeAsString(lines.join('\n'));
  printSuccess('Xcode 配置已更新: $projectPath');
  return true;
}

String generatePbxId() {
  final random = Random.secure();
  const chars = '0123456789ABCDEF';
  return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
}

bool insertBeforeSectionEnd(
  List<String> lines,
  String sectionName,
  String insertion,
) {
  final marker = '/* End $sectionName section */';
  final index = lines.indexWhere((line) => line.contains(marker));
  if (index == -1) {
    return false;
  }
  lines.insertAll(index, insertion.split('\n'));
  return true;
}

bool addLineToObjectList(
  List<String> lines,
  String objectId,
  String listKey,
  String lineToAdd,
) {
  final startIndex = findObjectStart(lines, objectId);
  if (startIndex == -1) {
    return false;
  }
  final endIndex = findObjectEnd(lines, startIndex);
  if (endIndex == -1) {
    return false;
  }

  var listStart = -1;
  for (var i = startIndex; i <= endIndex; i++) {
    if (lines[i].contains('$listKey = (')) {
      listStart = i;
      break;
    }
  }
  if (listStart == -1) {
    return false;
  }

  for (var i = listStart + 1; i <= endIndex; i++) {
    if (lines[i].trim() == lineToAdd.trim()) {
      return true;
    }
    if (lines[i].trim() == ');') {
      lines.insert(i, lineToAdd);
      return true;
    }
  }
  return false;
}

int findObjectStart(List<String> lines, String objectId) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('$objectId /*') && lines[i].contains('= {')) {
      return i;
    }
  }
  return -1;
}

int findObjectEnd(List<String> lines, int startIndex) {
  for (var i = startIndex + 1; i < lines.length; i++) {
    if (lines[i].startsWith('\t\t};')) {
      return i;
    }
  }
  return -1;
}

String? findFrameworksGroupId(List<String> lines) {
  final regex = RegExp(r'^\\s*([A-F0-9]{24})');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('/* Frameworks */ = {')) {
      final match = regex.firstMatch(lines[i]);
      if (match == null) {
        continue;
      }
      for (var j = i + 1; j < i + 6 && j < lines.length; j++) {
        if (lines[j].contains('isa = PBXGroup;')) {
          return match.group(1);
        }
      }
    }
  }
  return null;
}

String? findMainGroupId(List<String> lines) {
  final regex = RegExp(r'mainGroup = ([A-F0-9]{24})');
  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

String? findRunnerBuildPhaseId(List<String> lines, String phaseComment) {
  final targetRange = findRunnerTargetRange(lines);
  if (targetRange == null) {
    return null;
  }
  final regex = RegExp(r'^\\s*([A-F0-9]{24})');
  for (var i = targetRange.$1; i <= targetRange.$2; i++) {
    if (lines[i].contains('/* $phaseComment */')) {
      final match = regex.firstMatch(lines[i]);
      return match?.group(1);
    }
  }
  return null;
}

(int, int)? findRunnerTargetRange(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('/* Runner */ = {')) {
      for (var j = i + 1; j < i + 6 && j < lines.length; j++) {
        if (lines[j].contains('isa = PBXNativeTarget;')) {
          final end = findObjectEnd(lines, i);
          if (end != -1) {
            return (i, end);
          }
          return null;
        }
      }
    }
  }
  return null;
}

bool ensureFrameworkSearchPaths(List<String> lines) {
  final configListId = findRunnerConfigListId(lines);
  if (configListId == null) {
    return false;
  }
  final configIds = findBuildConfigIds(lines, configListId);
  var changed = false;
  for (final configId in configIds) {
    changed = ensureFrameworkSearchPathsForConfig(lines, configId) || changed;
  }
  return changed;
}

String? findRunnerConfigListId(List<String> lines) {
  final targetRange = findRunnerTargetRange(lines);
  if (targetRange == null) {
    return null;
  }
  final regex = RegExp(r'buildConfigurationList = ([A-F0-9]{24})');
  for (var i = targetRange.$1; i <= targetRange.$2; i++) {
    final match = regex.firstMatch(lines[i]);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

List<String> findBuildConfigIds(List<String> lines, String configListId) {
  final startIndex = findObjectStart(lines, configListId);
  if (startIndex == -1) {
    return [];
  }
  final endIndex = findObjectEnd(lines, startIndex);
  if (endIndex == -1) {
    return [];
  }

  var listStart = -1;
  for (var i = startIndex; i <= endIndex; i++) {
    if (lines[i].contains('buildConfigurations = (')) {
      listStart = i;
      break;
    }
  }
  if (listStart == -1) {
    return [];
  }

  final regex = RegExp(r'^\\s*([A-F0-9]{24})');
  final ids = <String>[];
  for (var i = listStart + 1; i <= endIndex; i++) {
    if (lines[i].trim() == ');') {
      break;
    }
    final match = regex.firstMatch(lines[i]);
    if (match != null) {
      ids.add(match.group(1)!);
    }
  }
  return ids;
}

bool ensureFrameworkSearchPathsForConfig(List<String> lines, String configId) {
  final startIndex = findObjectStart(lines, configId);
  if (startIndex == -1) {
    return false;
  }
  final endIndex = findObjectEnd(lines, startIndex);
  if (endIndex == -1) {
    return false;
  }

  var buildSettingsLine = -1;
  for (var i = startIndex; i <= endIndex; i++) {
    if (lines[i].contains('buildSettings = {')) {
      buildSettingsLine = i;
      break;
    }
  }
  if (buildSettingsLine == -1) {
    return false;
  }

  var hasFrameworkSearch = false;
  var hasRunnerFramework = false;
  var searchStart = -1;
  var searchEnd = -1;

  for (var i = buildSettingsLine + 1; i <= endIndex; i++) {
    if (lines[i].contains('FRAMEWORK_SEARCH_PATHS')) {
      hasFrameworkSearch = true;
      searchStart = i;
    }
    if (searchStart != -1 && lines[i].trim() == ');') {
      searchEnd = i;
      break;
    }
    if (lines[i].contains('Runner/Frameworks')) {
      hasRunnerFramework = true;
    }
    if (lines[i].trim() == '};') {
      break;
    }
  }

  if (hasFrameworkSearch && hasRunnerFramework) {
    return false;
  }

  final indent = lines[buildSettingsLine].split('buildSettings').first;
  if (!hasFrameworkSearch) {
    final insertion = [
      '${indent}FRAMEWORK_SEARCH_PATHS = (',
      '${indent}\t"\$(inherited)",',
      '${indent}\t"\$(PROJECT_DIR)/Runner/Frameworks",',
      '${indent});',
    ];
    lines.insertAll(buildSettingsLine + 1, insertion);
    return true;
  }

  if (searchStart != -1 && searchEnd != -1) {
    lines.insert(searchEnd, '${indent}\t"\$(PROJECT_DIR)/Runner/Frameworks",');
    return true;
  }

  return false;
}

String _quote(String value) => '\"$value\"';

Future<bool> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool quiet = false,
  String? description,
}) async {
  final workDir = workingDirectory ?? '.';

  if (!quiet && description != null) {
    printInfo('  → $description');
  }

  try {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workDir,
      environment: environment,
      runInShell: Platform.isWindows,
    );

    if (!quiet) {
      process.stdout.listen((data) => stdout.add(data));
      process.stderr.listen((data) => stderr.add(data));
    } else {
      process.stdout.drain();
      process.stderr.drain();
    }

    final exitCode = await process.exitCode;
    return exitCode == 0;
  } catch (e) {
    if (!quiet) {
      printError('命令执行失败: $executable ${arguments.join(' ')}');
      printError('错误: $e');
    }
    return false;
  }
}

void printStep(String message) {
  stdout.writeln('$bold$cyan$message$reset');
}
