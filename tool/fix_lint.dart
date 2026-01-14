#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Automatic lint fixer for CardMind project
///
/// This script runs all static analysis tools and attempts to automatically
/// fix issues found in both Flutter/Dart and Rust code.
///
/// Usage:
///   dart tool/fix_lint.dart [--check-only] [--flutter-only] [--rust-only]
///
/// Options:
///   --check-only    Only check for issues, don't fix them
///   --flutter-only  Only process Flutter/Dart code
///   --rust-only     Only process Rust code
///
/// Spec Coding Support:
///   --spec-check    Verify specs match implementation

import 'dart:io';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String bold = '\x1B[1m';

void main(List<String> arguments) async {
  final checkOnly = arguments.contains('--check-only');
  final flutterOnly = arguments.contains('--flutter-only');
  final rustOnly = arguments.contains('--rust-only');
  final specCheck = arguments.contains('--spec-check');

  printHeader('CardMind Lint Fixer + Spec Coding Validator');

  var hasErrors = false;

  // Spec Coding validation
  if (specCheck) {
    printSection('Spec Coding Validation');
    hasErrors = await validateSpecCoding() || hasErrors;
  }

  // Process Flutter/Dart code
  if (!rustOnly) {
    printSection('Processing Flutter/Dart Code');
    hasErrors = await processFlutter(checkOnly) || hasErrors;
  }

  // Process Rust code
  if (!flutterOnly) {
    printSection('Processing Rust Code');
    hasErrors = await processRust(checkOnly) || hasErrors;
  }

  // Summary
  print('\n${'=' * 60}');
  if (hasErrors) {
    printError('❌ Some checks failed. Please review errors above.');
    exit(1);
  } else {
    printSuccess('✅ All checks passed!');
    exit(0);
  }
}

/// Spec Coding validation
Future<bool> validateSpecCoding() async {
  var hasErrors = false;

  // 1. Check spec documentation exists
  printStep('Checking spec documentation...');
  final specDir = Directory('specs');
  if (!await specDir.exists()) {
    printError('Spec directory not found');
    hasErrors = true;
  } else {
    final specFiles = await specDir.list().recursive;
    final mdFiles = specFiles.where((f) => f.path.endsWith('.md')).toList();
    printSuccess('Found ${mdFiles.length} spec documentation files');
    
    // 2. Check for spec numbering consistency
    printStep('Verifying spec numbering...');
    final hasNumberingIssues = await checkSpecNumbering(mdFiles);
    if (hasNumberingIssues) {
      hasErrors = true;
    }
    
    // 3. Check for spec implementation completeness
    printStep('Verifying spec completeness...');
    final hasCompletenessIssues = await checkSpecCompleteness(mdFiles);
    if (hasCompletenessIssues) {
      hasErrors = true;
    }
  }

  return hasErrors;
}

/// Check spec numbering consistency
Future<bool> checkSpecNumbering(List<File> specFiles) async {
  var hasIssues = false;
  
  for (final file in specFiles) {
    final content = await file.readAsString();
    
    // Check for proper spec header
    if (!content.contains('## 📋 规格编号:')) {
      if (!content.contains('# 规格编号:')) {
        printWarning('Missing spec numbering in ${file.path}');
        hasIssues = true;
      }
    }
    
    // Check for version and status
    if (!content.contains('**版本**:')) {
      printWarning('Missing version in ${file.path}');
      hasIssues = true;
    }
    
    if (!content.contains('**状态**:')) {
      printWarning('Missing status in ${file.path}');
      hasIssues = true;
    }
  }
  
  if (!hasIssues) {
    printSuccess('Spec numbering is consistent');
  }
  
  return hasIssues;
}

/// Check spec completeness
Future<bool> checkSpecCompleteness(List<File> specFiles) async {
  var hasIssues = false;
  var specsWithTests = 0;
  
  for (final file in specFiles) {
    final content = await file.readAsString();
    
    // Check for test cases section
    if (content.contains('#[test]') || content.contains('## 3. 方法规格')) {
      specsWithTests++;
    }
  }
  
  printSuccess('Found $specsWithTests specs with test cases');
  
  // Check for README
  final readmeFile = File('specs/README.md');
  if (await readmeFile.exists()) {
    printSuccess('Spec center index exists');
  } else {
    printWarning('Spec center index (specs/README.md) not found');
    hasIssues = true;
  }
  
  return hasIssues;
}

  // Process Rust code
  if (!flutterOnly) {
    printSection('Processing Rust Code');
    hasErrors = await processRust(checkOnly) || hasErrors;
  }

  // Summary
  print('\n${'=' * 60}');
  if (hasErrors) {
    printError('❌ Some checks failed. Please review errors above.');
    exit(1);
  } else {
    printSuccess('✅ All checks passed!');
    exit(0);
  }
}

Future<bool> processFlutter(bool checkOnly) async {
  var hasErrors = false;

  // 1. Run dart format
  printStep('Running dart format...');
  if (checkOnly) {
    final formatCheck = await runCommand(
      'dart',
      ['format', '--set-exit-if-changed', '--output=none', '.'],
      workingDirectory: '.',
    );
    if (!formatCheck) {
      printWarning('Code formatting issues found. Run without --check-only to fix.');
      hasErrors = true;
    } else {
      printSuccess('Code formatting is correct');
    }
  } else {
    final formatResult = await runCommand(
      'dart',
      ['format', '.'],
      workingDirectory: '.',
    );
    if (formatResult) {
      printSuccess('Code formatted successfully');
    } else {
      printError('Failed to format code');
      hasErrors = true;
    }
  }

  // 2. Run dart fix
  if (!checkOnly) {
    printStep('Running dart fix --apply...');
    final fixResult = await runCommand(
      'dart',
      ['fix', '--apply'],
      workingDirectory: '.',
    );
    if (fixResult) {
      printSuccess('Applied dart fixes');
    } else {
      printWarning('Some fixes could not be applied automatically');
    }
  }

  // 3. Run flutter analyze
  printStep('Running flutter analyze...');
  final analyzeResult = await runCommand(
    'flutter',
    ['analyze'],
    workingDirectory: '.',
  );
  if (!analyzeResult) {
    printError('Flutter analyze found issues');
    hasErrors = true;
  } else {
    printSuccess('Flutter analyze passed');
  }

  return hasErrors;
}

Future<bool> processRust(bool checkOnly) async {
  var hasErrors = false;
  const rustDir = 'rust';

  // Check if rust directory exists
  if (!Directory(rustDir).existsSync()) {
    printWarning('Rust directory not found, skipping Rust checks');
    return false;
  }

  // 1. Run cargo fmt
  printStep('Running cargo fmt...');
  if (checkOnly) {
    final fmtCheck = await runCommand(
      'cargo',
      ['fmt', '--', '--check'],
      workingDirectory: rustDir,
    );
    if (!fmtCheck) {
      printWarning('Code formatting issues found. Run without --check-only to fix.');
      hasErrors = true;
    } else {
      printSuccess('Code formatting is correct');
    }
  } else {
    final fmtResult = await runCommand(
      'cargo',
      ['fmt'],
      workingDirectory: rustDir,
    );
    if (fmtResult) {
      printSuccess('Code formatted successfully');
    } else {
      printError('Failed to format code');
      hasErrors = true;
    }
  }

  // 2. Run cargo check
  printStep('Running cargo check...');
  final checkResult = await runCommand(
    'cargo',
    ['check'],
    workingDirectory: rustDir,
  );
  if (!checkResult) {
    printError('Cargo check failed');
    hasErrors = true;
  } else {
    printSuccess('Cargo check passed');
  }

  // 3. Run cargo clippy
  printStep('Running cargo clippy...');
  final clippyArgs = [
    'clippy',
    '--all-targets',
    '--all-features',
    if (!checkOnly) '--fix',
    if (!checkOnly) '--allow-dirty',
    if (!checkOnly) '--allow-staged',
  ];
  final clippyResult = await runCommand(
    'cargo',
    clippyArgs,
    workingDirectory: rustDir,
  );
  if (!clippyResult) {
    if (checkOnly) {
      printWarning('Clippy found issues. Run without --check-only to fix.');
    } else {
      printError('Clippy found issues that could not be auto-fixed');
    }
    hasErrors = true;
  } else {
    printSuccess('Cargo clippy passed');
  }

  return hasErrors;
}

Future<bool> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final workDir = workingDirectory ?? '.';

  print('$blue  → Running: $executable ${arguments.join(" ")}$reset');

  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workDir,
    runInShell: Platform.isWindows,
  );

  // Stream stdout and stderr
  process.stdout.listen((data) {
    stdout.add(data);
  });
  process.stderr.listen((data) {
    stderr.add(data);
  });

  final exitCode = await process.exitCode;
  return exitCode == 0;
}

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
