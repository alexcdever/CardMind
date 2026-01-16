#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Project Guardian 约束验证脚本
///
/// 用于验证代码是否符合 project-guardian.toml 中定义的约束规则
///
/// Usage:
///   dart tool/validate_constraints.dart [--full] [--rust-only] [--dart-only]
///
/// Options:
///   --full        运行完整验证（包括编译和测试）
///   --rust-only   仅验证 Rust 代码
///   --dart-only   仅验证 Dart 代码

import 'dart:io';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String bold = '\x1B[1m';

// 统计变量
int totalChecks = 0;
int passedChecks = 0;
int failedChecks = 0;

void main(List<String> arguments) async {
  final fullValidation = arguments.contains('--full');
  final rustOnly = arguments.contains('--rust-only');
  final dartOnly = arguments.contains('--dart-only');

  printHeader('🛡️  Project Guardian - 约束验证');
  print('');
  print('项目: CardMind');
  print('时间: ${DateTime.now()}');
  print('');

  // 检查配置文件
  await checkConfig();

  // 检查代码约束
  if (!dartOnly) {
    await checkRustConstraints();
  }

  if (!rustOnly) {
    await checkDartConstraints();
  }

  // 运行验证命令（可选）
  if (fullValidation) {
    if (!dartOnly) {
      await runRustValidation();
    }
    if (!rustOnly) {
      await runDartValidation();
    }
  } else {
    printInfo('跳过验证命令（使用 --full 运行完整验证）');
  }

  // 生成报告
  generateReport();
}

/// 检查配置文件是否存在
Future<void> checkConfig() async {
  printSection('检查 Project Guardian 配置');

  final configFile = File('project-guardian.toml');
  if (!await configFile.exists()) {
    printError('配置文件不存在: project-guardian.toml');
    exit(1);
  }

  printSuccess('配置文件存在: project-guardian.toml');
}

/// 检查 Rust 代码约束
Future<void> checkRustConstraints() async {
  printSection('检查 Rust 代码约束');

  final rustSrcDir = Directory('rust/src');
  if (!await rustSrcDir.exists()) {
    printWarning('未找到 Rust 源文件目录');
    return;
  }

  printInfo('检查禁止模式...');

  // 检查 unwrap()
  totalChecks++;
  final unwrapFiles = await findPattern(r'\.unwrap\(\)', 'rust/src', '*.rs');
  if (unwrapFiles.isNotEmpty) {
    printError('发现 unwrap() 使用 (${unwrapFiles.length} 处)');
    for (final file in unwrapFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
    await logFailure(
      'ERROR',
      'code_check',
      'rust/src/**/*.rs',
      '使用了 unwrap()',
      'AP-003',
    );
  } else {
    printSuccess('未发现 unwrap() 使用');
    passedChecks++;
  }

  // 检查 expect()
  totalChecks++;
  final expectFiles = await findPattern(r'\.expect\(', 'rust/src', '*.rs');
  if (expectFiles.isNotEmpty) {
    printError('发现 expect() 使用 (${expectFiles.length} 处)');
    for (final file in expectFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
    await logFailure(
      'ERROR',
      'code_check',
      'rust/src/**/*.rs',
      '使用了 expect()',
      'AP-003',
    );
  } else {
    printSuccess('未发现 expect() 使用');
    passedChecks++;
  }

  // 检查 panic!
  totalChecks++;
  final panicFiles = await findPattern(r'panic!', 'rust/src', '*.rs');
  if (panicFiles.isNotEmpty) {
    printError('发现 panic! 使用 (${panicFiles.length} 处)');
    for (final file in panicFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
    await logFailure(
      'ERROR',
      'code_check',
      'rust/src/**/*.rs',
      '使用了 panic!',
      'AP-003',
    );
  } else {
    printSuccess('未发现 panic! 使用');
    passedChecks++;
  }

  // 检查直接 SQLite 修改
  totalChecks++;
  final sqliteUpdateFiles =
      await findPattern(r'execute.*UPDATE.*cards', 'rust/src', '*.rs');
  if (sqliteUpdateFiles.isNotEmpty) {
    printError('发现直接修改 SQLite cards 表 (${sqliteUpdateFiles.length} 处)');
    for (final file in sqliteUpdateFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
    await logFailure(
      'ERROR',
      'code_check',
      'rust/src/**/*.rs',
      '直接修改 SQLite',
      'AP-001',
    );
  } else {
    printSuccess('未发现直接修改 SQLite');
    passedChecks++;
  }

  // 检查 todo!()
  totalChecks++;
  final todoFiles = await findPattern(r'todo!\(\)', 'rust/src', '*.rs');
  if (todoFiles.isNotEmpty) {
    printError('发现 todo!() 宏 (${todoFiles.length} 处)');
    for (final file in todoFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
  } else {
    printSuccess('未发现 todo!() 宏');
    passedChecks++;
  }

  // 检查 unimplemented!()
  totalChecks++;
  final unimplementedFiles =
      await findPattern(r'unimplemented!\(\)', 'rust/src', '*.rs');
  if (unimplementedFiles.isNotEmpty) {
    printError('发现 unimplemented!() 宏 (${unimplementedFiles.length} 处)');
    for (final file in unimplementedFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
  } else {
    printSuccess('未发现 unimplemented!() 宏');
    passedChecks++;
  }
}

/// 检查 Dart 代码约束
Future<void> checkDartConstraints() async {
  printSection('检查 Dart/Flutter 代码约束');

  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    printWarning('未找到 Dart 源文件目录');
    return;
  }

  printInfo('检查禁止模式...');

  // 检查 print() 使用（排除 debugPrint）
  totalChecks++;
  final printFiles = await findPattern(r'print\(', 'lib', '*.dart');
  // 过滤掉 debugPrint
  final badPrintFiles = <String>[];
  for (final file in printFiles) {
    final content = await File(file.split(':')[0]).readAsString();
    if (content.contains('print(') && !content.contains('debugPrint')) {
      badPrintFiles.add(file);
    }
  }

  if (badPrintFiles.isNotEmpty) {
    printError('发现 print() 使用（应使用 debugPrint）(${badPrintFiles.length} 处)');
    for (final file in badPrintFiles.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
    await logFailure(
      'ERROR',
      'code_check',
      'lib/**/*.dart',
      '使用了 print()',
      'AP-009',
    );
  } else {
    printSuccess('未发现 print() 使用');
    passedChecks++;
  }

  // 检查 TODO 注释
  totalChecks++;
  final todoComments = await findPattern(r'// TODO:', 'lib', '*.dart');
  if (todoComments.isNotEmpty) {
    printWarning('发现 TODO 注释 (${todoComments.length} 处)');
    for (final file in todoComments.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
  } else {
    printSuccess('未发现 TODO 注释');
    passedChecks++;
  }

  // 检查 FIXME 注释
  totalChecks++;
  final fixmeComments = await findPattern(r'// FIXME:', 'lib', '*.dart');
  if (fixmeComments.isNotEmpty) {
    printWarning('发现 FIXME 注释 (${fixmeComments.length} 处)');
    for (final file in fixmeComments.take(5)) {
      print('  $yellow→$reset $file');
    }
    failedChecks++;
  } else {
    printSuccess('未发现 FIXME 注释');
    passedChecks++;
  }
}

/// 运行 Rust 验证命令
Future<void> runRustValidation() async {
  printSection('运行 Rust 验证命令');

  // cargo check
  totalChecks++;
  printInfo('运行 cargo check...');
  final checkResult = await runCommand('cargo', ['check'], workingDir: 'rust');
  if (checkResult) {
    printSuccess('cargo check 通过');
    passedChecks++;
  } else {
    printError('cargo check 失败');
    failedChecks++;
  }

  // cargo clippy
  totalChecks++;
  printInfo('运行 cargo clippy...');
  final clippyResult = await runCommand(
    'cargo',
    ['clippy', '--all-targets', '--all-features', '--', '-D', 'warnings'],
    workingDir: 'rust',
  );
  if (clippyResult) {
    printSuccess('cargo clippy 通过（0 警告）');
    passedChecks++;
  } else {
    printWarning('cargo clippy 有警告');
    failedChecks++;
  }
}

/// 运行 Dart 验证命令
Future<void> runDartValidation() async {
  printSection('运行 Dart/Flutter 验证命令');

  // flutter analyze
  totalChecks++;
  printInfo('运行 flutter analyze...');
  final analyzeResult = await runCommand('flutter', ['analyze']);
  if (analyzeResult) {
    printSuccess('flutter analyze 通过');
    passedChecks++;
  } else {
    printWarning('flutter analyze 有问题');
    failedChecks++;
  }
}

/// 查找匹配模式的文件
Future<List<String>> findPattern(
  String pattern,
  String directory,
  String filePattern,
) async {
  final results = <String>[];

  try {
    final grepProcess = await Process.run(
      'grep',
      ['-rn', pattern, directory, '--include=$filePattern'],
      runInShell: true,
    );

    if (grepProcess.exitCode == 0) {
      final output = grepProcess.stdout.toString();
      results.addAll(output.split('\n').where((line) => line.isNotEmpty));
    }
  } catch (e) {
    // grep 未找到匹配或命令不存在
  }

  return results;
}

/// 运行命令
Future<bool> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDir,
}) async {
  print('$blue  → 运行: $executable ${arguments.join(" ")}$reset');

  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDir,
    runInShell: Platform.isWindows,
  );

  // 静默输出（仅在失败时显示）
  final stdout = <int>[];
  final stderr = <int>[];

  process.stdout.listen(stdout.addAll);
  process.stderr.listen(stderr.addAll);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    // 失败时显示输出
    if (stdout.isNotEmpty) {
      print(String.fromCharCodes(stdout));
    }
    if (stderr.isNotEmpty) {
      print(String.fromCharCodes(stderr));
    }
  }

  return exitCode == 0;
}

/// 记录失败到日志
Future<void> logFailure(
  String level,
  String operation,
  String file,
  String description,
  String constraint,
) async {
  final timestamp = DateTime.now().toString();
  final logFile = File('.project-guardian/failures.log');

  final entry = '''

[$timestamp] [$level] [$operation] [$file]
描述: $description
约束: $constraint
状态: 待修复

''';

  await logFile.writeAsString(entry, mode: FileMode.append);
}

/// 生成报告
void generateReport() {
  printSection('验证报告');

  print('');
  print('总检查项: $totalChecks');
  print('${green}通过: $passedChecks$reset');
  print('${red}失败: $failedChecks$reset');
  print('');

  if (failedChecks == 0) {
    printSuccess('所有检查通过！✨');
    print('');
    print('🎉 代码符合 Project Guardian 约束');
    exit(0);
  } else {
    printError('有 $failedChecks 项检查失败');
    print('');
    print('📋 请查看失败日志: .project-guardian/failures.log');
    print('📖 参考最佳实践: .project-guardian/best-practices.md');
    print('🚫 参考反模式: .project-guardian/anti-patterns.md');
    exit(1);
  }
}

// 打印辅助函数
void printHeader(String message) {
  print('\n$bold$blue${"=" * 60}');
  print('  $message');
  print('${"=" * 60}$reset\n');
}

void printSection(String message) {
  print('\n$bold$blue━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$reset');
  print('$bold$blue$message$reset');
  print('$bold$blue━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$reset');
}

void printInfo(String message) {
  print('$blue ℹ $reset$message');
}

void printSuccess(String message) {
  print('$green✅ $reset$message');
}

void printWarning(String message) {
  print('$yellow⚠️  $reset$message');
}

void printError(String message) {
  print('$red❌ $reset$message');
}
