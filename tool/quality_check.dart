#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// CardMind 质量检查脚本
///
/// 运行完整的代码质量检查，包括静态分析和测试，收集所有错误信息
///
/// Usage:
///   dart tool/quality_check.dart [options]
///
/// Options:
///   --check-only      仅检查，不尝试自动修复
///   --auto-fix        自动修复简单问题（格式化、lint）
///   --flutter-only    仅检查 Flutter/Dart 代码
///   --rust-only       仅检查 Rust 代码
///   --no-tests        跳过测试，仅运行静态检查
///   --no-save-errors  不保存错误日志到 /tmp
///
/// Examples:
///   dart tool/quality_check.dart                    # 完整检查
///   dart tool/quality_check.dart --check-only       # 仅检查
///   dart tool/quality_check.dart --auto-fix         # 检查并自动修复
///   dart tool/quality_check.dart --flutter-only     # 仅检查 Flutter

import 'dart:io';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String bold = '\x1B[1m';

// 错误收集
final List<String> flutterErrors = [];
final List<String> flutterTestErrors = [];
final List<String> rustErrors = [];
final List<String> rustTestErrors = [];

// 统计
int totalChecks = 0;
int passedChecks = 0;
int failedChecks = 0;

void main(List<String> arguments) async {
  final autoFix = arguments.contains('--auto-fix');
  final flutterOnly = arguments.contains('--flutter-only');
  final rustOnly = arguments.contains('--rust-only');
  final noTests = arguments.contains('--no-tests');
  final saveErrors = !arguments.contains('--no-save-errors');

  printHeader('CardMind 质量检查');
  print('模式: ${autoFix ? "自动修复" : "仅检查"}');
  print(
    '范围: ${flutterOnly
        ? "Flutter"
        : rustOnly
        ? "Rust"
        : "全部"}',
  );
  print('测试: ${noTests ? "跳过" : "包含"}');
  print('');

  var hasErrors = false;

  // Process Flutter/Dart code
  if (!rustOnly) {
    printSection('Flutter/Dart 代码检查');
    hasErrors = await processFlutter(autoFix, noTests) || hasErrors;
  }

  // Process Rust code
  if (!flutterOnly) {
    printSection('Rust 代码检查');
    hasErrors = await processRust(autoFix, noTests) || hasErrors;
  }

  // Generate summary
  printSummary();

  // Save errors to file
  if (saveErrors && hasErrors) {
    await saveErrorsToFile();
  }

  // Exit with appropriate code
  if (hasErrors) {
    printError('\n❌ 质量检查失败，发现 $failedChecks 个问题');
    if (saveErrors) {
      final errorLogPath = await saveErrorsToFile();
      print('\n📋 错误详情已保存到: $yellow$errorLogPath$reset');
      print('💡 提示: 你可以将此文件提供给 AI 进行修复');
    }
    exit(1);
  } else {
    printSuccess('\n✅ 所有质量检查通过！');
    exit(0);
  }
}

/// Process Flutter/Dart code
Future<bool> processFlutter(bool autoFix, bool noTests) async {
  var hasErrors = false;

  // 1. Run dart format
  printStep('1. 代码格式化 (dart format)');
  totalChecks++;
  if (autoFix) {
    final formatResult = await runCommand('dart', [
      'format',
      '.',
    ], captureOutput: false);
    if (formatResult.exitCode == 0) {
      printSuccess('代码格式化完成');
      passedChecks++;
    } else {
      printError('代码格式化失败');
      flutterErrors.add('[dart format] 格式化失败');
      failedChecks++;
      hasErrors = true;
    }
  } else {
    final formatCheck = await runCommand('dart', [
      'format',
      '--set-exit-if-changed',
      '--output=none',
      '.',
    ], captureOutput: false);
    if (formatCheck.exitCode == 0) {
      printSuccess('代码格式正确');
      passedChecks++;
    } else {
      printWarning('发现格式问题（使用 --auto-fix 自动修复）');
      flutterErrors.add('[dart format] 代码格式不符合规范');
      failedChecks++;
      hasErrors = true;
    }
  }

  // 2. Run dart fix (only in auto-fix mode)
  if (autoFix) {
    printStep('2. 应用 Dart 修复 (dart fix)');
    totalChecks++;
    final fixResult = await runCommand('dart', [
      'fix',
      '--apply',
    ], captureOutput: false);
    if (fixResult.exitCode == 0) {
      printSuccess('Dart 修复已应用');
      passedChecks++;
    } else {
      printWarning('部分修复无法自动应用');
      passedChecks++; // 不算作错误
    }
  }

  // 3. Run flutter analyze
  printStep('${autoFix ? "3" : "2"}. 静态分析 (flutter analyze)');
  totalChecks++;
  final analyzeResult = await runCommand('flutter', [
    'analyze',
  ], captureOutput: true);
  if (analyzeResult.exitCode == 0) {
    printSuccess('静态分析通过');
    passedChecks++;
  } else {
    printError('静态分析发现问题');
    flutterErrors.add('[flutter analyze]\n${analyzeResult.output}');
    failedChecks++;
    hasErrors = true;
  }

  // 4. Run flutter test
  if (!noTests) {
    printStep('${autoFix ? "4" : "3"}. 运行测试 (flutter test)');
    totalChecks++;
    final testResult = await runCommand('flutter', [
      'test',
    ], captureOutput: true);
    if (testResult.exitCode == 0) {
      printSuccess('所有测试通过');
      passedChecks++;
    } else {
      printError('测试失败');
      flutterTestErrors.add('[flutter test]\n${testResult.output}');
      failedChecks++;
      hasErrors = true;
    }
  }

  return hasErrors;
}

/// Process Rust code
Future<bool> processRust(bool autoFix, bool noTests) async {
  var hasErrors = false;
  const rustDir = 'rust';

  // Check if rust directory exists
  if (!Directory(rustDir).existsSync()) {
    printWarning('未找到 Rust 目录，跳过 Rust 检查');
    return false;
  }

  // 1. Run cargo fmt
  printStep('1. 代码格式化 (cargo fmt)');
  totalChecks++;
  if (autoFix) {
    final fmtResult = await runCommand(
      'cargo',
      ['fmt'],
      workingDirectory: rustDir,
      captureOutput: false,
    );
    if (fmtResult.exitCode == 0) {
      printSuccess('代码格式化完成');
      passedChecks++;
    } else {
      printError('代码格式化失败');
      rustErrors.add('[cargo fmt] 格式化失败');
      failedChecks++;
      hasErrors = true;
    }
  } else {
    final fmtCheck = await runCommand(
      'cargo',
      ['fmt', '--', '--check'],
      workingDirectory: rustDir,
      captureOutput: false,
    );
    if (fmtCheck.exitCode == 0) {
      printSuccess('代码格式正确');
      passedChecks++;
    } else {
      printWarning('发现格式问题（使用 --auto-fix 自动修复）');
      rustErrors.add('[cargo fmt] 代码格式不符合规范');
      failedChecks++;
      hasErrors = true;
    }
  }

  // 2. Run cargo check
  printStep('2. 编译检查 (cargo check)');
  totalChecks++;
  final checkResult = await runCommand(
    'cargo',
    ['check'],
    workingDirectory: rustDir,
    captureOutput: true,
  );
  if (checkResult.exitCode == 0) {
    printSuccess('编译检查通过');
    passedChecks++;
  } else {
    printError('编译检查失败');
    rustErrors.add('[cargo check]\n${checkResult.output}');
    failedChecks++;
    hasErrors = true;
  }

  // 3. Run cargo clippy
  printStep('3. Clippy 检查 (cargo clippy)');
  totalChecks++;
  final clippyArgs = [
    'clippy',
    '--all-targets',
    '--all-features',
    '--',
    '-D',
    'warnings',
  ];
  final clippyResult = await runCommand(
    'cargo',
    clippyArgs,
    workingDirectory: rustDir,
    captureOutput: true,
  );
  if (clippyResult.exitCode == 0) {
    printSuccess('Clippy 检查通过');
    passedChecks++;
  } else {
    printError('Clippy 发现问题');
    rustErrors.add('[cargo clippy]\n${clippyResult.output}');
    failedChecks++;
    hasErrors = true;
  }

  // 4. Run cargo test
  if (!noTests) {
    printStep('4. 运行测试 (cargo test)');
    totalChecks++;
    final testResult = await runCommand(
      'cargo',
      ['test', '--all-features'],
      workingDirectory: rustDir,
      captureOutput: true,
    );
    if (testResult.exitCode == 0) {
      printSuccess('所有测试通过');
      passedChecks++;
    } else {
      printError('测试失败');
      rustTestErrors.add('[cargo test]\n${testResult.output}');
      failedChecks++;
      hasErrors = true;
    }
  }

  return hasErrors;
}

/// Command result
class CommandResult {
  final int exitCode;
  final String output;

  CommandResult(this.exitCode, this.output);
}

/// Run command and capture output
Future<CommandResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool captureOutput = false,
}) async {
  final workDir = workingDirectory ?? '.';

  print('$blue  → $executable ${arguments.join(" ")}$reset');

  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workDir,
    runInShell: Platform.isWindows,
  );

  final stdoutBuffer = <int>[];
  final stderrBuffer = <int>[];

  if (captureOutput) {
    // Capture output for error reporting
    process.stdout.listen(stdoutBuffer.addAll);
    process.stderr.listen(stderrBuffer.addAll);
  } else {
    // Stream output to console
    process.stdout.listen((data) => stdout.add(data));
    process.stderr.listen((data) => stderr.add(data));
  }

  final exitCode = await process.exitCode;

  final output = captureOutput
      ? String.fromCharCodes(stdoutBuffer) + String.fromCharCodes(stderrBuffer)
      : '';

  return CommandResult(exitCode, output);
}

/// Save errors to file
Future<String> saveErrorsToFile() async {
  final now = DateTime.now();
  final timestamp = now.toString();

  // Generate filename with date and time (format: YYYY-MM-DD-HH:MM:SS)
  final filename =
      'cardmind_errors_'
      '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}'
      '.log';

  final errorFilePath = '/tmp/$filename';
  final buffer = StringBuffer();

  buffer.writeln('=' * 80);
  buffer.writeln('CardMind 错误报告');
  buffer.writeln('生成时间: $timestamp');
  buffer.writeln('=' * 80);
  buffer.writeln();

  // Flutter/Dart errors
  if (flutterErrors.isNotEmpty || flutterTestErrors.isNotEmpty) {
    buffer.writeln('━━━ Flutter/Dart 错误 ━━━');
    buffer.writeln();

    if (flutterErrors.isNotEmpty) {
      for (final error in flutterErrors) {
        buffer.writeln(error);
        buffer.writeln();
      }
    }

    if (flutterTestErrors.isNotEmpty) {
      for (final error in flutterTestErrors) {
        final filteredError = _filterTestOutput(error, isFlutter: true);
        buffer.writeln(filteredError);
        buffer.writeln();
      }
    }
  }

  // Rust errors
  if (rustErrors.isNotEmpty || rustTestErrors.isNotEmpty) {
    buffer.writeln('━━━ Rust 错误 ━━━');
    buffer.writeln();

    if (rustErrors.isNotEmpty) {
      for (final error in rustErrors) {
        buffer.writeln(error);
        buffer.writeln();
      }
    }

    if (rustTestErrors.isNotEmpty) {
      for (final error in rustTestErrors) {
        final filteredError = _filterTestOutput(error, isFlutter: false);
        buffer.writeln(filteredError);
        buffer.writeln();
      }
    }
  }

  // Summary
  buffer.writeln('━━━ 错误统计 ━━━');
  buffer.writeln();
  buffer.writeln('Flutter 静态检查错误: ${flutterErrors.length}');
  buffer.writeln('Flutter 测试失败: ${flutterTestErrors.length}');
  buffer.writeln('Rust 静态检查错误: ${rustErrors.length}');
  buffer.writeln('Rust 测试失败: ${rustTestErrors.length}');
  buffer.writeln();
  buffer.writeln(
    '总计: ${flutterErrors.length + flutterTestErrors.length + rustErrors.length + rustTestErrors.length} 个问题需要修复',
  );
  buffer.writeln();
  buffer.writeln('=' * 80);

  // Write to file
  final errorFile = File(errorFilePath);
  await errorFile.writeAsString(buffer.toString());

  printSuccess('错误日志已保存到: $errorFilePath');

  return errorFilePath;
}

/// Filter test output to only include failures
String _filterTestOutput(String output, {required bool isFlutter}) {
  final lines = output.split('\n');
  final filteredLines = <String>[];
  var inFailureSection = false;
  var captureNextLines = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (isFlutter) {
      // Flutter test patterns
      if (line.contains('FAILED') ||
          line.contains('EXCEPTION CAUGHT') ||
          line.contains('Test failed') ||
          line.contains('Expected:') ||
          line.contains('Actual:') ||
          line.contains('Which:') ||
          line.contains('package:flutter_test') ||
          line.contains('══╡') ||
          line.contains('Some tests failed')) {
        inFailureSection = true;
        captureNextLines = 10;
        filteredLines.add(line);
      } else if (line.contains('All tests passed') ||
          line.contains('+') && line.contains(':') && !line.contains('-')) {
        inFailureSection = false;
        captureNextLines = 0;
      } else if (inFailureSection || captureNextLines > 0) {
        filteredLines.add(line);
        if (captureNextLines > 0) captureNextLines--;
      } else if (line.contains('-') && line.contains(':')) {
        filteredLines.add(line);
        captureNextLines = 5;
      }
    } else {
      // Rust test patterns
      if (line.contains('FAILED') ||
          line.contains('panicked at') ||
          line.contains('failures:') ||
          line.contains('error:') ||
          line.contains('error[E') ||
          line.contains('thread') && line.contains('panicked') ||
          line.contains('test result: FAILED')) {
        inFailureSection = true;
        captureNextLines = 15;
        filteredLines.add(line);
      } else if (line.contains('test result: ok') ||
          line.contains('running') && line.contains('test')) {
        inFailureSection = false;
        captureNextLines = 0;
      } else if (inFailureSection || captureNextLines > 0) {
        filteredLines.add(line);
        if (captureNextLines > 0) captureNextLines--;
      } else if (line.trim().startsWith('test ') && line.contains('... ok')) {
        // Skip passed tests
        continue;
      } else if (line.trim().isEmpty && filteredLines.isNotEmpty) {
        // Keep empty lines for readability
        filteredLines.add(line);
      }
    }
  }

  // If no failures found, return a summary
  if (filteredLines.isEmpty) {
    return '[测试失败但无法解析详细错误信息]\n$output';
  }

  return filteredLines.join('\n');
}

/// Print summary
void printSummary() {
  printSection('检查结果汇总');
  print('');
  print('总检查项: $totalChecks');
  print('${green}通过: $passedChecks$reset');
  print('${red}失败: $failedChecks$reset');
  print('');
}

// Print helper functions
void printHeader(String message) {
  print('\n$bold$blue${"=" * 60}');
  print('  $message');
  print('${"=" * 60}$reset\n');
}

void printSection(String message) {
  print('\n$bold$yellow━━━ $message ━━━$reset\n');
}

void printStep(String message) {
  print('\n$bold$message$reset');
}

void printSuccess(String message) {
  print('$green✓ $message$reset');
}

void printWarning(String message) {
  print('$yellow⚠ $message$reset');
}

void printError(String message) {
  print('$red✗ $message$reset');
}
