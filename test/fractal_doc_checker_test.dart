import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/fractal_doc_checker.dart';

void main() {
  test('fails when changed file lacks header', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['lib/foo.dart']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('missing header'));
  });

  test('rejects absolute path', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));

    final checker = FractalDocChecker(rootPath: root.path);
    final result = await checker.check(changedFiles: ['/etc/passwd']);
    expect(result.isOk, isFalse);
    expect(result.errors.single, contains('absolute path not allowed'));
  });
}
