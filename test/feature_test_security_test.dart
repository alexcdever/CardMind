import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects shell syntax in device identifiers', () {
    final source = File('tool/feature_test.dart').readAsStringSync();
    expect(source, contains('runInShell: false'));
    expect(source, isNot(contains('runInShell: true')));
    expect(source, contains('RegExp'));
    expect(source, contains('A-Za-z0-9._:-'));
  });

  test('uses argv process launch rather than shell interpretation', () {
    final source = File('tool/feature_test.dart').readAsStringSync();
    expect(source, contains("Process.start(executable, ["));
    expect(
      source,
      contains(
        "final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';",
      ),
    );
  });
}
