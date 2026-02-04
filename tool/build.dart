#!/usr/bin/env dart

import 'dart:io';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String magenta = '\x1B[35m';
const String cyan = '\x1B[36m';
const String bold = '\x1B[1m';

enum BuildPlatform { android, linux, windows, macos, ios }

class BuildConfig {
  final Set<BuildPlatform> platforms;

  BuildConfig({required this.platforms});
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('-h') || arguments.contains('--help')) {
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

Future<void> runBridge(BuildConfig config) async {
  printHeader('🔨 CardMind 构建工具');
  printSection('📋 检查构建环境');
  if (!await checkEnvironment(config)) {
    printError('环境检查失败，无法继续');
    exit(1);
  }

  printSection('🔧 生成桥接代码');
  if (!await generateBridge()) {
    printError('桥接代码生成失败');
    exit(1);
  }

  printSection('🎨 格式化生成代码');
  await formatGeneratedCode();
  printSuccess('✅ 桥接准备完成');
}

Future<void> runApp(BuildConfig config) async {
  printHeader('🔨 CardMind 构建工具');
  printSection('📋 检查构建环境');
  if (!await checkEnvironment(config)) {
    printError('环境检查失败，无法继续');
    exit(1);
  }

  printSection('🔧 生成桥接代码');
  if (!await generateBridge()) {
    printError('桥接代码生成失败');
    exit(1);
  }

  printSection('🎨 格式化生成代码');
  await formatGeneratedCode();

  printSection('app');
  printInfo('应用构建流程尚未实现');
}

void printUsage({String? error}) {
  if (error != null) {
    stderr.writeln('$red✗$reset $error');
    stderr.writeln('');
  }

  stdout.writeln('CardMind 构建脚本');
  stdout.writeln('');
  stdout.writeln('用法:');
  stdout.writeln('  dart tool/build.dart bridge [--android|--linux|--windows|--macos|--ios]');
  stdout.writeln('  dart tool/build.dart app    [--android|--linux|--windows|--macos|--ios]');
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
  if (await runCommand(
    'flutter_rust_bridge_codegen',
    ['--version'],
    quiet: true,
    description: 'FRB version',
  )) {
    printSuccess('flutter_rust_bridge_codegen 已安装');
  } else {
    printWarning('flutter_rust_bridge_codegen 未安装，尝试安装中...');
    if (await runCommand(
      'cargo',
      ['install', 'flutter_rust_bridge_codegen'],
      description: 'Install FRB',
    )) {
      printSuccess('flutter_rust_bridge_codegen 安装成功');
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

  return success;
}

Future<bool> generateBridge() async {
  final args = [
    'generate',
    '--rust-input',
    'cardmind_rust::api',
    '--dart-output',
    'lib/bridge/',
    '--c-output',
    'rust/src/bridge_generated.h',
  ];

  printInfo('运行: flutter_rust_bridge_codegen ${args.join(' ')}');
  return runCommand(
    'flutter_rust_bridge_codegen',
    args,
    description: 'Generate FRB bindings',
  );
}

Future<void> formatGeneratedCode() async {
  final dartFormat = await runCommand(
    'dart',
    ['format', 'lib/bridge/'],
    description: 'Dart format',
  );
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
