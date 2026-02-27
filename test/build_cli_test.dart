import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build.dart';

void main() {
  test('prints usage when subcommand is missing', () async {
    final logs = <String>[];
    final exit = await runBuildCli(
      const [],
      log: logs.add,
      logError: logs.add,
      runProcess: _noProcessExpected,
    );
    expect(exit, 1);
    expect(
      logs.join('\n'),
      contains('Usage: dart run tool/build.dart <app|lib>'),
    );
  });

  test(
    'lib runs cargo build in rust directory with release by default',
    () async {
      final calls = <_ProcCall>[];
      final exit = await runBuildCli(const [
        'lib',
      ], runProcess: _fakeRunner(calls));
      expect(exit, 0);
      expect(calls.single.executable, 'cargo');
      expect(calls.single.arguments, ['build', '--release']);
      expect(calls.single.workingDirectory, endsWith('/rust'));
    },
  );

  test('app runs lib then codegen then flutter build in order', () async {
    final calls = <_ProcCall>[];
    final exit = await runBuildCli(const [
      'app',
      '--platform',
      'macos',
    ], runProcess: _fakeRunner(calls));
    expect(exit, 0);
    expect(calls[0].executable, 'cargo');
    expect(calls[1].executable, 'flutter_rust_bridge_codegen');
    expect(calls[1].arguments, ['generate']);
    expect(calls[2].executable, 'flutter');
    expect(calls[2].arguments, ['build', 'macos']);
  });

  test(
    'app defaults to host executable platform when --platform missing',
    () async {
      final calls = <_ProcCall>[];
      final exit = await runBuildCli(
        const ['app'],
        runProcess: _fakeRunner(calls),
        platformOverride: HostPlatform.macos,
      );
      expect(exit, 0);
      expect(calls.last.arguments, ['build', 'macos']);
    },
  );

  test('app rejects unsupported platform value', () async {
    final logs = <String>[];
    final exit = await runBuildCli(
      const ['app', '--platform', 'solaris'],
      runProcess: _noProcessExpected,
      logError: logs.add,
    );
    expect(exit, 1);
    expect(logs.join('\n'), contains('Unsupported platform'));
  });

  test('returns error for unknown subcommand', () async {
    final logs = <String>[];
    final exit = await runBuildCli(
      const ['unknown'],
      runProcess: _noProcessExpected,
      logError: logs.add,
    );
    expect(exit, 1);
    expect(
      logs.join('\n'),
      contains('Usage: dart run tool/build.dart <app|lib> [options]'),
    );
  });

  test('prints usage for --help', () async {
    final logs = <String>[];
    final exit = await runBuildCli(
      const ['--help'],
      runProcess: _noProcessExpected,
      log: logs.add,
      logError: logs.add,
    );
    expect(exit, 0);
    expect(
      logs.join('\n'),
      contains('Usage: dart run tool/build.dart <app|lib> [options]'),
    );
    expect(logs.join('\n'), contains('Commands:'));
    expect(logs.join('\n'), contains('app    Build Flutter app'));
    expect(logs.join('\n'), contains('lib    Build Rust dynamic library'));
    expect(logs.join('\n'), contains('Examples:'));
  });

  test('prints usage for -h', () async {
    final logs = <String>[];
    final exit = await runBuildCli(
      const ['-h'],
      runProcess: _noProcessExpected,
      log: logs.add,
      logError: logs.add,
    );
    expect(exit, 0);
    expect(
      logs.join('\n'),
      contains('Usage: dart run tool/build.dart <app|lib> [options]'),
    );
    expect(logs.join('\n'), contains('Default behavior:'));
    expect(
      logs.join('\n'),
      contains('app runs: lib -> codegen -> flutter build'),
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
