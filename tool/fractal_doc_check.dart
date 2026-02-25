import 'dart:io';
import 'fractal_doc_checker.dart';

Future<void> main(List<String> args) async {
  final base = args.contains('--base')
      ? args[args.indexOf('--base') + 1]
      : 'HEAD';
  final diff = await Process.run(
      'git', ['diff', '--name-only', '--diff-filter=ACMR', base]);
  final files = (diff.stdout as String)
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  final checker = FractalDocChecker(rootPath: Directory.current.path);
  final result = await checker.check(changedFiles: files);
  if (!result.isOk) {
    stderr.writeln(result.errors.join('\n'));
    exitCode = 1;
  }
}
