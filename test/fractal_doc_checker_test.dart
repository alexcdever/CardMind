import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/fractal_doc_checker.dart';

void main() {
  test('fails when changed file lacks header', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final dirFile = File('${root.path}/lib/DIR.md')
      ..createSync(recursive: true);
    dirFile.writeAsStringSync('foo.dart\n');
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('missing header'));
  });

  test('rejects absolute paths', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: [
      '/etc/passwd',
      'C:\\Windows\\system32',
      '\\\\server\\share\\file.txt',
      'file:///etc/passwd',
    ]);
    expect(result.isOk, isFalse);
    expect(result.errors, hasLength(4));
    expect(result.errors, contains('absolute path not allowed: /etc/passwd'));
    expect(result.errors,
        contains('absolute path not allowed: C:\\Windows\\system32'));
    expect(result.errors,
        contains('absolute path not allowed: \\\\server\\share\\file.txt'));
    expect(result.errors,
        contains('absolute path not allowed: file:///etc/passwd'));
  });

  test('fails when DIR.md not updated for changed file', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/lib/DIR.md').createSync(recursive: true);
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('// input: none\n// output: none\n// pos: none\n');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('DIR.md missing entry'));
  });

  test('does not match DIR.md substring entries', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final dirFile = File('${root.path}/lib/DIR.md')
      ..createSync(recursive: true);
    dirFile.writeAsStringSync('foo.dart.bak\n');
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('// input: none\n// output: none\n// pos: none\n');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('DIR.md missing entry'));
  });

  test('accepts markdown link entry in DIR.md', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final dirFile = File('${root.path}/lib/DIR.md')
      ..createSync(recursive: true);
    dirFile.writeAsStringSync('- [foo.dart](lib/foo.dart)\n');
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('// input: none\n// output: none\n// pos: none\n');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isTrue);
    expect(result.errors, isEmpty);
  });

  test('ignores excluded paths', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/build/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['build/foo.dart']);
    expect(result.isOk, isTrue);
  });
}
