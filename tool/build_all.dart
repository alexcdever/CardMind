#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// CardMind 全平台构建脚本
///
/// 用途: 构建所有支持平台的 Rust 动态库和 Flutter 应用
/// 功能: 自动编译 Rust 库并部署到各平台所需位置，然后构建 Flutter 应用
///
/// 使用方式:
/// ```bash
/// # 构建所有平台
/// dart tool/build_all.dart
///
/// # 只构建特定平台
/// dart tool/build_all.dart --android
/// dart tool/build_all.dart --linux
/// dart tool/build_all.dart --windows
/// dart tool/build_all.dart --macos
/// dart tool/build_all.dart --ios
///
/// # 清理构建产物
/// dart tool/build_all.dart --clean
///
/// # 调试模式构建
/// dart tool/build_all.dart --debug
/// ```

import 'dart:io';

// ANSI 颜色代码
const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String magenta = '\x1B[35m';
const String cyan = '\x1B[36m';
const String bold = '\x1B[1m';

// 平台定义
enum BuildPlatform { android, linux, windows, macos, ios }

// 构建配置
class BuildConfig {
  final bool isDebug;
  final Set<BuildPlatform> platforms;
  final bool cleanOnly;

  BuildConfig({
    required this.isDebug,
    required this.platforms,
    required this.cleanOnly,
  });

  String get buildMode => isDebug ? 'debug' : 'release';
  String get buildModeCapitalized => isDebug ? 'Debug' : 'Release';
}

void main(List<String> arguments) async {
  printHeader('🔨 CardMind 全平台构建工具');

  final config = parseArguments(arguments);

  if (config.cleanOnly) {
    await cleanAll();
    return;
  }

  // 检查环境
  printSection('📋 检查构建环境');
  if (!await checkEnvironment(config)) {
    printError('环境检查失败，无法继续构建');
    exit(1);
  }

  // 构建 Rust 库
  printSection('🦀 构建 Rust 动态库');
  if (!await buildRustLibraries(config)) {
    printError('Rust 库构建失败');
    exit(1);
  }

  // 构建各平台应用
  printSection('📱 构建 Flutter 应用');
  var hasErrors = false;
  for (final platform in config.platforms) {
    if (!await buildPlatform(platform, config)) {
      hasErrors = true;
    }
  }

  // 总结
  printSection('📊 构建总结');
  if (hasErrors) {
    printError('部分平台构建失败，请查看上方错误信息');
    exit(1);
  } else {
    printSuccess('✅ 所有平台构建成功！');
    await printBuildArtifacts(config);
    exit(0);
  }
}

BuildConfig parseArguments(List<String> args) {
  final isDebug = args.contains('--debug');
  final cleanOnly = args.contains('--clean');

  final platforms = <BuildPlatform>{};

  if (args.contains('--android')) platforms.add(BuildPlatform.android);
  if (args.contains('--linux')) platforms.add(BuildPlatform.linux);
  if (args.contains('--windows')) platforms.add(BuildPlatform.windows);
  if (args.contains('--macos')) platforms.add(BuildPlatform.macos);
  if (args.contains('--ios')) platforms.add(BuildPlatform.ios);

  // 如果没有指定任何平台，根据当前系统决定默认平台
  if (platforms.isEmpty && !cleanOnly) {
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

  return BuildConfig(
    isDebug: isDebug,
    platforms: platforms,
    cleanOnly: cleanOnly,
  );
}

Future<void> cleanAll() async {
  printStep('清理所有构建产物...');

  final cleanTasks = [
    runCommand('flutter', ['clean'], description: 'Flutter clean'),
    runCommand(
      'cargo',
      ['clean'],
      workingDirectory: 'rust',
      description: 'Cargo clean',
    ),
  ];

  await Future.wait(cleanTasks);

  // 删除额外的构建目录
  final dirsToDelete = [
    'build',
    '.dart_tool',
    'rust/target',
    'android/.gradle',
    'android/app/build',
    'linux/flutter/ephemeral',
    'linux/build',
    'windows/flutter/ephemeral',
    'windows/build',
    'macos/Flutter/ephemeral',
    'macos/build',
    'ios/Flutter/ephemeral',
    'ios/build',
  ];

  for (final dir in dirsToDelete) {
    final directory = Directory(dir);
    if (directory.existsSync()) {
      try {
        directory.deleteSync(recursive: true);
        printInfo('删除 $dir');
      } catch (e) {
        printWarning('无法删除 $dir: $e');
      }
    }
  }

  printSuccess('✅ 清理完成！');
}

Future<bool> checkEnvironment(BuildConfig config) async {
  var success = true;

  // 检查 Flutter
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

  // 检查 Rust
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

  // 检查 flutter_rust_bridge_codegen
  printStep('检查 flutter_rust_bridge_codegen...');
  if (await runCommand(
    'flutter_rust_bridge_codegen',
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
      printSuccess('flutter_rust_bridge_codegen 安装成功');
    } else {
      printError('flutter_rust_bridge_codegen 安装失败');
      success = false;
    }
  }

  // 检查平台特定工具
  for (final platform in config.platforms) {
    success = await checkPlatformEnvironment(platform, config) && success;
  }

  return success;
}

Future<bool> checkPlatformEnvironment(
  BuildPlatform platform,
  BuildConfig config,
) async {
  switch (platform) {
    case BuildPlatform.android:
      printStep('检查 Android 环境...');
      final ndkHome = Platform.environment['ANDROID_NDK_HOME'];
      if (ndkHome != null && Directory(ndkHome).existsSync()) {
        printSuccess('Android NDK: $ndkHome');
      } else {
        printWarning('ANDROID_NDK_HOME 未设置或目录不存在');
      }

      // 检查 Android 目标
      final targets = [
        'aarch64-linux-android',
        'armv7-linux-androideabi',
        'x86_64-linux-android',
        'i686-linux-android',
      ];
      for (final target in targets) {
        if (!await runCommand(
          'rustup',
          ['target', 'list', '--installed'],
          quiet: true,
          description: 'Check Rust target',
        )) {
          printWarning('Rust Android 目标未完全安装，尝试安装...');
          await runCommand('rustup', [
            'target',
            'add',
            ...targets,
          ], description: 'Add Android targets');
          break;
        }
      }

      // 检查 cargo-ndk
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
      // 检查 GTK 开发库
      if (Platform.isLinux) {
        // 尝试使用系统的 pkg-config
        var pkgConfigResult = await runCommand(
          '/usr/bin/pkg-config',
          ['--exists', 'gtk+-3.0'],
          quiet: true,
          description: 'Check GTK3',
        );

        // 如果系统 pkg-config 不存在，尝试默认路径
        if (!pkgConfigResult) {
          pkgConfigResult = await runCommand(
            'pkg-config',
            ['--exists', 'gtk+-3.0'],
            quiet: true,
            description: 'Check GTK3',
          );
        }

        if (!pkgConfigResult) {
          printWarning(
            'GTK 3 开发库未安装，请运行: sudo apt-get install libgtk-3-dev pkg-config',
          );
          return false;
        }
        printSuccess('GTK 3 开发库已安装');
      }
      return true;

    case BuildPlatform.windows:
      printStep('检查 Windows 环境...');
      if (Platform.isWindows) {
        printSuccess('Windows 环境正常');
      } else {
        printWarning('当前系统不是 Windows，跳过 Windows 平台构建');
        return false;
      }
      return true;

    case BuildPlatform.macos:
      printStep('检查 macOS 环境...');
      if (Platform.isMacOS) {
        printSuccess('macOS 环境正常');
      } else {
        printWarning('当前系统不是 macOS，跳过 macOS 平台构建');
        return false;
      }
      return true;

    case BuildPlatform.ios:
      printStep('检查 iOS 环境...');
      if (Platform.isMacOS) {
        if (await runCommand(
          'xcodebuild',
          ['-version'],
          quiet: true,
          description: 'Xcode version',
        )) {
          printSuccess('Xcode 已安装');
        } else {
          printError('Xcode 未安装');
          return false;
        }
      } else {
        printWarning('当前系统不是 macOS，跳过 iOS 平台构建');
        return false;
      }
      return true;
  }
}

Map<String, String> getAndroidEnvironment() {
  final env = Map<String, String>.from(Platform.environment);

  // 检查 ANDROID_NDK_HOME 是否已设置
  final ndkHome = env['ANDROID_NDK_HOME'];
  if (ndkHome == null || ndkHome.isEmpty) {
    printWarning('ANDROID_NDK_HOME 未设置，尝试自动检测...');

    // 尝试常见的 NDK 安装路径
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

  final ndkPath = env['ANDROID_NDK_HOME'];
  if (ndkPath == null) {
    printError('无法找到 Android NDK，请设置 ANDROID_NDK_HOME 环境变量');
    return env;
  }

  // 添加 NDK toolchain 到 PATH
  final toolchainPath = '$ndkPath/toolchains/llvm/prebuilt/linux-x86_64/bin';
  env['PATH'] = '${env['PATH']}:$toolchainPath';

  // 设置各个架构的编译器
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
  final rustDir = 'rust';

  for (final platform in config.platforms) {
    printStep('构建 ${platform.name} Rust 库...');

    switch (platform) {
      case BuildPlatform.android:
        // Android 需要为多个架构构建
        final targets = [
          'aarch64-linux-android',
          'armv7-linux-androideabi',
          'x86_64-linux-android',
          'i686-linux-android',
        ];

        // 准备 Android NDK 环境变量
        final androidEnv = getAndroidEnvironment();

        for (final target in targets) {
          printInfo('  构建 $target...');
          if (!await runCommand(
            'cargo',
            ['build', if (!config.isDebug) '--release', '--target', target],
            workingDirectory: rustDir,
            environment: androidEnv,
            description: 'Build Rust for $target',
          )) {
            printError('$target 构建失败');
            return false;
          }
        }

        // 复制到 Android jniLibs
        if (!await copyAndroidLibraries(config)) {
          return false;
        }
        printSuccess('Android Rust 库构建成功');
        break;

      case BuildPlatform.linux:
        if (!await runCommand(
          'cargo',
          ['build', if (!config.isDebug) '--release'],
          workingDirectory: rustDir,
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
          ['build', if (!config.isDebug) '--release'],
          workingDirectory: rustDir,
          description: 'Build Rust for Windows',
        )) {
          printError('Windows Rust 库构建失败');
          return false;
        }
        printSuccess('Windows Rust 库构建成功');
        break;

      case BuildPlatform.macos:
        // macOS 可能需要 universal binary
        if (!await runCommand(
          'cargo',
          ['build', if (!config.isDebug) '--release'],
          workingDirectory: rustDir,
          description: 'Build Rust for macOS',
        )) {
          printError('macOS Rust 库构建失败');
          return false;
        }
        printSuccess('macOS Rust 库构建成功');
        break;

      case BuildPlatform.ios:
        // iOS 需要多个架构
        final targets = ['aarch64-apple-ios', 'x86_64-apple-ios'];
        for (final target in targets) {
          printInfo('  构建 $target...');
          if (!await runCommand(
            'cargo',
            ['build', if (!config.isDebug) '--release', '--target', target],
            workingDirectory: rustDir,
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

Future<bool> copyAndroidLibraries(BuildConfig config) async {
  final buildMode = config.buildMode;
  final jniLibsDir = 'android/app/src/main/jniLibs';

  // 架构映射: Rust target -> Android ABI
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

    // 创建目标目录
    Directory(targetDir).createSync(recursive: true);

    // 复制库文件
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

Future<bool> buildPlatform(BuildPlatform platform, BuildConfig config) async {
  printStep('构建 ${platform.name} 应用...');

  final buildMode = config.isDebug ? 'debug' : 'release';

  switch (platform) {
    case BuildPlatform.android:
      if (!await runCommand('flutter', [
        'build',
        'apk',
        '--$buildMode',
      ], description: 'Build Android APK')) {
        printError('Android APK 构建失败');
        return false;
      }

      printSuccess('✅ Android APK 构建成功');
      printInfo('   输出: build/app/outputs/flutter-apk/app-$buildMode.apk');
      return true;

    case BuildPlatform.linux:
      // 确保使用系统 pkg-config
      final env = Map<String, String>.from(Platform.environment);
      if (!env.containsKey('PKG_CONFIG_PATH')) {
        env['PATH'] = '/usr/bin:${env['PATH']}';
      }

      if (!await runCommand(
        'flutter',
        ['build', 'linux', '--$buildMode'],
        environment: env,
        description: 'Build Linux app',
      )) {
        printError('Linux 应用构建失败');
        return false;
      }

      // 复制 Rust 库到 bundle
      final rustLib = 'rust/target/$buildMode/libcardmind_rust.so';
      final bundleLib =
          'build/linux/x64/$buildMode/bundle/lib/libcardmind_rust.so';

      try {
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
        '--$buildMode',
      ], description: 'Build Windows app')) {
        printError('Windows 应用构建失败');
        return false;
      }

      // 复制 Rust 库到 bundle
      final rustLib = 'rust/target/$buildMode/cardmind_rust.dll';
      final bundleLib = 'build/windows/x64/runner/$buildMode/cardmind_rust.dll';

      try {
        File(rustLib).copySync(bundleLib);
        printInfo('  复制 Rust 库: $rustLib -> $bundleLib');
      } catch (e) {
        printError('复制 Rust 库失败: $e');
        return false;
      }

      printSuccess('✅ Windows 应用构建成功');
      printInfo('   输出: build/windows/x64/runner/$buildMode/');
      return true;

    case BuildPlatform.macos:
      if (!await runCommand('flutter', [
        'build',
        'macos',
        '--$buildMode',
      ], description: 'Build macOS app')) {
        printError('macOS 应用构建失败');
        return false;
      }

      printSuccess('✅ macOS 应用构建成功');
      printInfo(
        '   输出: build/macos/Build/Products/${config.buildModeCapitalized}/',
      );
      return true;

    case BuildPlatform.ios:
      if (!await runCommand('flutter', [
        'build',
        'ios',
        '--$buildMode',
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

Future<void> printBuildArtifacts(BuildConfig config) async {
  print('\n${bold}构建产物:$reset\n');

  for (final platform in config.platforms) {
    final buildMode = config.buildMode;

    switch (platform) {
      case BuildPlatform.android:
        final apkPath = 'build/app/outputs/flutter-apk/app-$buildMode.apk';
        await printArtifact('Android APK', apkPath);
        break;

      case BuildPlatform.linux:
        final bundlePath = 'build/linux/x64/$buildMode/bundle/';
        await printArtifact('Linux Bundle', bundlePath);
        break;

      case BuildPlatform.windows:
        final exePath = 'build/windows/x64/runner/$buildMode/';
        await printArtifact('Windows App', exePath);
        break;

      case BuildPlatform.macos:
        final appPath =
            'build/macos/Build/Products/${config.buildModeCapitalized}/';
        await printArtifact('macOS App', appPath);
        break;

      case BuildPlatform.ios:
        final ipaPath = 'build/ios/iphoneos/';
        await printArtifact('iOS App', ipaPath);
        break;
    }
  }
}

Future<void> printArtifact(String name, String path) async {
  final entity = FileSystemEntity.typeSync(path);

  if (entity == FileSystemEntityType.notFound) {
    print('  $red✗$reset $name: $path (未找到)');
    return;
  }

  String size = '';
  if (entity == FileSystemEntityType.file) {
    final file = File(path);
    final bytes = file.lengthSync();
    size = ' (${formatBytes(bytes)})';
  } else if (entity == FileSystemEntityType.directory) {
    final dir = Directory(path);
    var totalSize = 0;
    await for (final file in dir.list(recursive: true)) {
      if (file is File) {
        totalSize += file.lengthSync();
      }
    }
    size = ' (${formatBytes(totalSize)})';
  }

  print('  $green✓$reset $name: $cyan$path$reset$size');
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

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
      // 静默模式，丢弃输出
      process.stdout.drain();
      process.stderr.drain();
    }

    final exitCode = await process.exitCode;
    return exitCode == 0;
  } catch (e) {
    if (!quiet) {
      printError('命令执行失败: $executable ${arguments.join(" ")}');
      printError('错误: $e');
    }
    return false;
  }
}

void printHeader(String message) {
  print('\n$bold$blue${"=" * 70}');
  print('  $message');
  print('${"=" * 70}$reset\n');
}

void printSection(String message) {
  print('\n$bold$magenta━━━ $message ━━━$reset\n');
}

void printStep(String message) {
  print('$bold$cyan$message$reset');
}

void printInfo(String message) {
  print('$blue$message$reset');
}

void printSuccess(String message) {
  print('$green$message$reset');
}

void printWarning(String message) {
  print('$yellow⚠ $message$reset');
}

void printError(String message) {
  print('$red✗ $message$reset');
}
