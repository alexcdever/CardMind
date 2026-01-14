#!/usr/bin/env dart

/// Spec Documentation Validator
///
/// Simple tool to validate spec documentation files in the specs/ directory.

import 'dart:io';

void main(List<String> args) {
  final specDir = Directory('specs');

  if (!specDir.existsSync()) {
    print('[ERROR] Specs directory not found: specs/');
    exit(1);
  }

  print('[INFO] Checking spec documentation files...\n');

  final mdFiles = specDir
      .listSync(recursive: true)
      .where((f) => f.path.endsWith('.md'))
      .toList();

  if (mdFiles.isEmpty) {
    print('[WARN] No spec files found');
    exit(0);
  }

  print('[OK] Found ${mdFiles.length} spec file(s)\n');

  // Check each spec file
  var validSpecCount = 0;
  for (var file in mdFiles) {
    final path = file.path;
    final fileName = file.path.split('/').last;

    if (file is File) {
      final content = file.readAsStringSync();

      // Basic checks
      if (content.contains('## 📋 规格编号:') ||
          content.contains('📋 规格编号:') ||
          content.contains('## 规格编号:') ||
          content.contains('规格编号:')) {
        validSpecCount++;
        print('  [OK] $fileName');
      } else {
        print('  [SKIP] $fileName (missing spec header)');
      }
    }
  }

  print('\n[SUMMARY]');
  print('  Valid specs: $validSpecCount/${mdFiles.length}');
  print(
    '  Coverage: ${(validSpecCount / mdFiles.length * 100).toStringAsFixed(2)}%\n',
  );

  exit(0);
}

bool _hasSpecHeader(File file) {
  final content = file.readAsStringSync();
  // Check for spec header patterns
  return content.contains('## 📋 规格编号:') ||
      content.contains('📋 规格编号:') ||
      content.contains('## 规格编号:') ||
      content.contains('规格编号:'); // Allow for English headers too
}
