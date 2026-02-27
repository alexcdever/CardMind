import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib has no empty or disabled primary interaction handlers', () {
    final root = Directory.current;
    final libDir = Directory('${root.path}/lib');
    final emptyHandler = RegExp(r'on[A-Za-z0-9_]+\s*:\s*\(\)\s*\{\s*\}');
    final disabledPressed = RegExp(r'onPressed\s*:\s*null');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      if (emptyHandler.hasMatch(content) || disabledPressed.hasMatch(content)) {
        final relativePath = entity.path.replaceFirst('${root.path}/', '');
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Found empty/disabled interactions in: ${violations.join(', ')}',
    );
  });
}
