import 'dart:convert';
import 'dart:io';
import 'fractal_doc_checker.dart';

const _usage = 'Usage: dart run tool/fractal_doc_check.dart [--base <git-ref>]';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

Future<void> main(List<String> args) async {
  exitCode = await runFractalDocCheck(args);
}

Future<int> runFractalDocCheck(
  List<String> args, {
  ProcessRunner runProcess = Process.run,
  void Function(String message) writeError = _stderrWriteln,
}) async {
  final baseIndex = args.indexOf('--base');
  var base = 'HEAD';
  if (baseIndex != -1) {
    final valueIndex = baseIndex + 1;
    if (valueIndex >= args.length || args[valueIndex].startsWith('--')) {
      writeError(_usage);
      return 1;
    }
    base = args[valueIndex];
  }

  ProcessResult diff;
  try {
    diff = await runProcess(
      'git',
      ['diff', '--name-only', '--diff-filter=ACMR', base],
    );
  } on ProcessException catch (error) {
    writeError(_formatRunProcessError(error));
    return 1;
  } on FileSystemException catch (error) {
    writeError(_formatRunProcessError(error));
    return 1;
  }
  if (diff.exitCode != 0) {
    final stderrText = _processOutputToString(diff.stderr);
    if (stderrText.trim().isEmpty) {
      writeError('git diff failed');
    } else {
      writeError(stderrText);
    }
    return diff.exitCode;
  }

  final files = _processOutputToString(diff.stdout)
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  final checker = FractalDocChecker(rootPath: Directory.current.path);
  final result = await checker.check(changedFiles: files);
  if (!result.isOk) {
    writeError(result.errors.join('\n'));
    return 1;
  }
  return 0;
}

void _stderrWriteln(String message) {
  stderr.writeln(message);
}

String _processOutputToString(Object? output) {
  if (output == null) return '';
  if (output is String) return output;
  if (output is List<int>) return utf8.decode(output);
  return output.toString();
}

String _formatRunProcessError(Object error) {
  if (error is ProcessException) {
    final message = error.message;
    if (message.isNotEmpty) {
      return 'Failed to run git diff: $message';
    }
    return 'Failed to run git diff: $error';
  }
  if (error is FileSystemException) {
    final message = error.message;
    if (message.isNotEmpty) {
      return 'Failed to run git diff: $message';
    }
    return 'Failed to run git diff: $error';
  }
  return 'Failed to run git diff: $error';
}
