// input: 向 quality CLI 传入子命令与帮助参数。
// output: 返回码、提示文案与进程调用顺序符合约定。
// pos: 覆盖质量脚本分支与参数校验，防止 lint/test 门禁执行缺失。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/quality.dart';

void main() {
  test('prints usage when subcommand is missing', () async {
    final logs = <String>[];
    final exit = await runQualityCli(
      const [],
      log: logs.add,
      logError: logs.add,
      runProcess: _noProcessExpected,
    );
    expect(exit, 1);
    expect(
      logs.join('\n'),
      contains('Usage: dart run tool/quality.dart <flutter|rust|all>'),
    );
  });

  test(
    'flutter runs analyze then test with coverage then boundary scan in order',
    () async {
      final calls = <_ProcCall>[];
      final exit = await runQualityCli(const [
        'flutter',
      ], runProcess: _fakeRunner(calls));
      expect(exit, 0);
      expect(calls.length, 3);
      expect(calls[0].executable, 'flutter');
      expect(calls[0].arguments, ['analyze']);
      expect(calls[1].executable, 'flutter');
      expect(calls[1].arguments, ['test', '--coverage']);
      expect(calls[2].executable, 'dart');
      expect(calls[2].arguments, [
        'tool/test_boundary_scanner.dart',
        '--scope=flutter',
      ]);
      expect(calls[0].workingDirectory, isNull);
      expect(calls[1].workingDirectory, isNull);
      expect(calls[2].workingDirectory, isNull);
    },
  );

  test('rust runs fmt then clippy then test in rust directory', () async {
    final calls = <_ProcCall>[];
    final exit = await runQualityCli(const [
      'rust',
    ], runProcess: _fakeRunner(calls));
    expect(exit, 0);
    expect(calls.length, 5);
    expect(calls[0].executable, 'cargo');
    expect(calls[0].arguments, ['fmt', '--all', '--', '--check']);
    expect(calls[1].executable, 'cargo');
    expect(calls[1].arguments, [
      'clippy',
      '--all-targets',
      '--all-features',
      '--',
      '-D',
      'warnings',
    ]);
    expect(calls[2].executable, 'cargo');
    expect(calls[2].arguments, ['test', '--', '--test-threads=1']);
    expect(calls[3].executable, 'cargo');
    expect(calls[3].arguments, [
      'tarpaulin',
      '--out',
      'Lcov',
      '--output-dir',
      '.',
      '--exclude-files',
      'src/frb_generated.rs',
      '--exclude-files',
      'tool/**',
    ]);
    expect(calls[4].executable, 'dart');
    expect(calls[4].arguments, [
      'tool/test_boundary_scanner.dart',
      '--scope=rust',
    ]);
    expect(calls[0].workingDirectory, endsWith('/rust'));
    expect(calls[1].workingDirectory, endsWith('/rust'));
    expect(calls[2].workingDirectory, endsWith('/rust'));
    expect(calls[3].workingDirectory, endsWith('/rust'));
    expect(calls[4].workingDirectory, isNull);
  });

  test('all runs flutter checks then rust checks in order', () async {
    final calls = <_ProcCall>[];
    final exit = await runQualityCli(const [
      'all',
    ], runProcess: _fakeRunner(calls));
    expect(exit, 0);
    expect(calls.length, 8);
    // Flutter checks
    expect(calls[0].executable, 'flutter');
    expect(calls[0].arguments, ['analyze']);
    expect(calls[1].executable, 'flutter');
    expect(calls[1].arguments, ['test', '--coverage']);
    expect(calls[2].executable, 'dart');
    expect(calls[2].arguments, [
      'tool/test_boundary_scanner.dart',
      '--scope=flutter',
    ]);
    // Rust checks
    expect(calls[3].executable, 'cargo');
    expect(calls[3].arguments, ['fmt', '--all', '--', '--check']);
    expect(calls[4].executable, 'cargo');
    expect(calls[4].arguments, [
      'clippy',
      '--all-targets',
      '--all-features',
      '--',
      '-D',
      'warnings',
    ]);
    expect(calls[5].executable, 'cargo');
    expect(calls[5].arguments, ['test', '--', '--test-threads=1']);
    expect(calls[6].executable, 'cargo');
    expect(calls[6].arguments, [
      'tarpaulin',
      '--out',
      'Lcov',
      '--output-dir',
      '.',
      '--exclude-files',
      'src/frb_generated.rs',
      '--exclude-files',
      'tool/**',
    ]);
    expect(calls[7].executable, 'dart');
    expect(calls[7].arguments, [
      'tool/test_boundary_scanner.dart',
      '--scope=rust',
    ]);
  });

  test('returns command exit code on flutter analyze failure', () async {
    final exit = await runQualityCli(
      const ['flutter'],
      runProcess: _scriptedRunner([ProcessResult(1, 42, '', 'analyze failed')]),
    );
    expect(exit, 42);
  });

  test('returns command exit code on rust clippy failure', () async {
    final exit = await runQualityCli(
      const ['rust'],
      runProcess: _scriptedRunner([
        ProcessResult(1, 0, '', ''),
        ProcessResult(2, 5, '', 'clippy failed'),
      ]),
    );
    expect(exit, 5);
  });

  test('returns error for unknown subcommand', () async {
    final logs = <String>[];
    final exit = await runQualityCli(
      const ['unknown'],
      runProcess: _noProcessExpected,
      logError: logs.add,
    );
    expect(exit, 1);
    expect(
      logs.join('\n'),
      contains(
        'Usage: dart run tool/quality.dart <flutter|rust|all> [options]',
      ),
    );
  });

  test('prints usage for --help', () async {
    final logs = <String>[];
    final exit = await runQualityCli(
      const ['--help'],
      runProcess: _noProcessExpected,
      log: logs.add,
      logError: logs.add,
    );
    expect(exit, 0);
    expect(
      logs.join('\n'),
      contains(
        'Usage: dart run tool/quality.dart <flutter|rust|all> [options]',
      ),
    );
    expect(logs.join('\n'), contains('Commands:'));
    expect(
      logs.join('\n'),
      contains('flutter  Run Flutter lint, tests, and boundary scan'),
    );
    expect(logs.join('\n'), contains('rust     Run Rust lint and tests'));
    expect(
      logs.join('\n'),
      contains('all      Run Flutter then Rust quality checks'),
    );
  });
}

Future<ProcessResult> _noProcessExpected(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('No process expected: $executable ${arguments.join(' ')}');
}

Runner _fakeRunner(List<_ProcCall> calls) {
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add(
      _ProcCall(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return ProcessResult(0, 0, '', '');
  };
}

Runner _scriptedRunner(List<ProcessResult> results) {
  var i = 0;
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (i >= results.length) {
      throw StateError('No scripted result left for $executable');
    }
    final result = results[i];
    i += 1;
    return result;
  };
}

class _ProcCall {
  _ProcCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}
