#!/usr/bin/env dart

/// Batch rename test functions from test_xxx to it_should_xxx format
/// Run: dart tool/rename_tests.dart

import 'dart:io';

void main(List<String> args) {
  final testFiles = [
    'rust/tests/card_store_test.rs',
    'rust/tests/sqlite_test.rs',
    'rust/tests/sync_integration_test.rs',
    'rust/tests/loro_integration_test.rs',
    'rust/tests/loro_sync_test.rs',
    'rust/tests/performance_test.rs',
    'rust/tests/mdns_discovery_test.rs',
    'rust/tests/p2p_network_test.rs',
  ];

  var totalRenamed = 0;
  var totalFiles = 0;

  for (final filePath in testFiles) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('[SKIP] File not found: $filePath');
      continue;
    }

    totalFiles++;
    var content = file.readAsStringSync();
    final originalContent = content;

    // Simple string replacement for fn test_ -> fn it_should_
    content = content.replaceAll('fn test_', 'fn it_should_');

    if (content != originalContent) {
      // Count occurrences
      final count = 'fn test_'.allMatches(originalContent).length;
      totalRenamed += count;
      file.writeAsStringSync(content);
      print('[OK] $filePath: $count functions renamed');
    } else {
      print('[SKIP] $filePath: no changes needed');
    }
  }

  print('\n[SUMMARY]');
  print('  Files processed: $totalFiles');
  print('  Functions renamed: $totalRenamed');
  print('  Status: ${totalRenamed > 0 ? "SUCCESS" : "NO CHANGES"}');
}
