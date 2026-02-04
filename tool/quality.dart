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

Future<void> main(List<String> arguments) async {
  printHeader('🔍 CardMind 质量检查');

  if (!await runRustChecks()) {
    exit(1);
  }

  if (!await runBridgeBuild()) {
    exit(1);
  }

  if (!await runFlutterChecks()) {
    exit(1);
  }

  printSuccess('✅ 质量检查通过');
}

Future<bool> runRustChecks() async {
  printSection('🦀 Rust 代码检查');

  if (!await runCommand(
    'cargo',
    ['fmt'],
    workingDirectory: 'rust',
    description: 'cargo fmt',
  )) {
    printError('cargo fmt 失败');
    return false;
  }

  if (!await runCommand(
    'cargo',
    ['check'],
    workingDirectory: 'rust',
    description: 'cargo check',
  )) {
    printError('cargo check 失败');
    return false;
  }

  if (!await runCommand(
    'cargo',
    ['clippy', '--all-targets', '--all-features', '--', '-D', 'warnings'],
    workingDirectory: 'rust',
    description: 'cargo clippy',
  )) {
    printError('cargo clippy 失败');
    return false;
  }

  if (!await runCommand(
    'cargo',
    ['test', '--all-features'],
    workingDirectory: 'rust',
    description: 'cargo test',
  )) {
    printError('cargo test 失败');
    return false;
  }

  printSuccess('✅ Rust 检查通过');
  return true;
}

Future<bool> runBridgeBuild() async {
  printSection('🔧 生成桥接与动态库');

  final args = ['tool/build.dart', 'bridge', ...bridgePlatformArgs()];
  if (!await runCommand('dart', args, description: 'build.dart bridge')) {
    printError('桥接构建失败');
    return false;
  }

  printSuccess('✅ 桥接构建完成');
  return true;
}

List<String> bridgePlatformArgs() {
  if (Platform.isLinux) {
    return ['--linux', '--android'];
  }
  if (Platform.isWindows) {
    return ['--windows', '--android'];
  }
  if (Platform.isMacOS) {
    return ['--macos', '--android', '--ios'];
  }
  return [];
}

Future<bool> runFlutterChecks() async {
  printSection('🎯 Dart/Flutter 代码检查');

  if (!await runCommand('dart', [
    'fix',
    '--apply',
  ], description: 'dart fix --apply')) {
    printError('dart fix 失败');
    return false;
  }

  if (!await runCommand('dart', ['format', '.'], description: 'dart format')) {
    printError('dart format 失败');
    return false;
  }

  if (!await runCommand('flutter', [
    'analyze',
  ], description: 'flutter analyze')) {
    printError('flutter analyze 失败');
    return false;
  }

  if (!await runCommand('flutter', ['test'], description: 'flutter test')) {
    printError('flutter test 失败');
    return false;
  }

  printSuccess('✅ Dart/Flutter 检查通过');
  return true;
}

Future<bool> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  String? description,
}) async {
  if (description != null) {
    printInfo('  → $description');
  }

  try {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );

    process.stdout.listen((data) => stdout.add(data));
    process.stderr.listen((data) => stderr.add(data));

    final exitCode = await process.exitCode;
    return exitCode == 0;
  } catch (e) {
    printError('命令执行失败: $executable ${arguments.join(' ')}');
    printError('错误: $e');
    return false;
  }
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
