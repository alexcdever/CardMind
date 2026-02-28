// input: test/fractal_doc_checker_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/fractal_doc_bootstrap.dart';
import '../tool/fractal_doc_checker.dart';
import '../tool/fractal_doc_check.dart';

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
    final backslashFile =
        File('${root.path}/build\\foo.dart')..createSync(recursive: true);
    backslashFile.writeAsStringSync('void main() {}');

    final checker = FractalDocChecker(rootPath: root.path);
    final result =
        await checker.check(changedFiles: ['build/foo.dart', 'build\\foo.dart']);
    expect(result.isOk, isTrue);
    expect(result.errors, isEmpty);
  });

  test('bootstrap creates DIR.md and headers', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    await bootstrapFractalDocs(rootPath: root.path);

    expect(File('${root.path}/lib/DIR.md').existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content.split('\n').first, contains('input:'));
  });

  test('bootstrap adds headers only to dart and rs files', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final dartFile =
        File('${root.path}/lib/foo.dart')..createSync(recursive: true);
    dartFile.writeAsStringSync('void main() {}');
    final rsFile = File('${root.path}/lib/foo.rs')..createSync(recursive: true);
    rsFile.writeAsStringSync('fn main() {}');
    final jsFile = File('${root.path}/lib/foo.js')..createSync(recursive: true);
    jsFile.writeAsStringSync('console.log("x");');

    await bootstrapFractalDocs(rootPath: root.path);

    final dartContent = dartFile.readAsStringSync();
    final rsContent = rsFile.readAsStringSync();
    final jsContent = jsFile.readAsStringSync();
    expect(dartContent.split('\n').first, contains('input:'));
    expect(rsContent.split('\n').first, contains('input:'));
    expect(jsContent.split('\n').first, 'console.log("x");');
  });

  test('bootstrap creates DIR.md for ancestor directories', () async {
    final root = Directory.systemTemp.createTempSync('fractal-doc-test');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/lib/feature/sub/foo.dart')
      ..createSync(recursive: true);
    file.writeAsStringSync('void main() {}');

    await bootstrapFractalDocs(rootPath: root.path);

    expect(File('${root.path}/lib/feature/DIR.md').existsSync(), isTrue);
  });

  test('fractal doc CLI reports missing --base value', () async {
    var runCalled = false;
    Future<ProcessResult> fakeRun(
      String executable,
      List<String> arguments,
    ) async {
      runCalled = true;
      return ProcessResult(0, 0, '', '');
    }

    final errors = <String>[];
    final exit = await runFractalDocCheck(
      ['--base'],
      runProcess: fakeRun,
      writeError: errors.add,
    );
    expect(runCalled, isFalse);
    expect(exit, isNot(0));
    expect(errors.single, contains('Usage:'));
  });

  test('fractal doc CLI reports git diff failure', () async {
    var runCalled = false;
    Future<ProcessResult> fakeRun(
      String executable,
      List<String> arguments,
    ) async {
      runCalled = true;
      return ProcessResult(0, 1, '', 'diff failed');
    }

    final errors = <String>[];
    final exit = await runFractalDocCheck(
      [],
      runProcess: fakeRun,
      writeError: errors.add,
    );
    expect(runCalled, isTrue);
    expect(exit, isNot(0));
    expect(errors.single, contains('diff failed'));
  });

  test('fractal doc CLI reports process exception', () async {
    Future<ProcessResult> fakeRun(
      String executable,
      List<String> arguments,
    ) async {
      throw ProcessException('git', ['diff'], 'no git');
    }

    final errors = <String>[];
    final exit = await runFractalDocCheck(
      [],
      runProcess: fakeRun,
      writeError: errors.add,
    );
    expect(exit, isNot(0));
    expect(errors.single, contains('git diff'));
    expect(errors.single, contains('no git'));
  });
}
