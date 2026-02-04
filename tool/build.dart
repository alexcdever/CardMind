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
  printSection('bridge');
  printInfo('桥接构建流程尚未实现');
}

Future<void> runApp(BuildConfig config) async {
  printHeader('🔨 CardMind 构建工具');
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
