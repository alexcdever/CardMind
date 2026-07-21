import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build.dart' as build;

void main() {
  test('android app build keeps Rust and Flutter targets aligned', () async {
    final calls = <_ProcessCall>[];

    final exitCode = await build.runBuildCli(
      ['app', '--platform', 'android'],
      currentDirectory: 'D:/CardMind',
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add(_ProcessCall(executable, arguments, workingDirectory));
        return ProcessResult(1, 0, '', '');
      },
      log: (_) {},
      logError: (_) {},
      pathExists: (_) => true,
    );

    expect(exitCode, 0);
    expect(calls, hasLength(3));
    expect(calls[0].executable, 'cargo');
    expect(calls[0].workingDirectory, 'D:/CardMind/rust-backend');
    expect(
      calls[0].arguments,
      containsAllInOrder([
        'ndk',
        '-t',
        'armeabi-v7a',
        '-t',
        'arm64-v8a',
        '-t',
        'x86_64',
        '-o',
        'D:/CardMind/build/android-jni',
        'build',
        '--release',
      ]),
    );
    expect(calls[1].executable, 'flutter_rust_bridge_codegen');
    expect(calls[2].executable, 'flutter');
    expect(calls[2].arguments, ['build', 'apk']);
  });

  for (final testCase in <({String format, List<String> arguments})>[
    (format: 'appbundle', arguments: <String>['build', 'appbundle']),
    (
      format: 'split-apk',
      arguments: <String>['build', 'apk', '--split-per-abi'],
    ),
  ]) {
    test('android ${testCase.format} keeps the Rust build pipeline', () async {
      final calls = <_ProcessCall>[];

      final exitCode = await build.runBuildCli(
        ['app', '--platform', 'android', '--android-format', testCase.format],
        currentDirectory: 'D:/CardMind',
        runProcess: (executable, arguments, {workingDirectory}) async {
          calls.add(_ProcessCall(executable, arguments, workingDirectory));
          return ProcessResult(1, 0, '', '');
        },
        log: (_) {},
        logError: (_) {},
        pathExists: (_) => true,
      );

      expect(exitCode, 0);
      expect(calls, hasLength(3));
      expect(calls.first.executable, 'cargo');
      expect(calls.last.arguments, testCase.arguments);
    });
  }

  test('android build fails when a Rust ABI artifact is missing', () async {
    final errors = <String>[];

    final exitCode = await build.runBuildCli(
      ['app', '--platform', 'android'],
      currentDirectory: 'D:/CardMind',
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(1, 0, '', ''),
      log: (_) {},
      logError: errors.add,
      pathExists: (path) => !path.contains('armeabi-v7a'),
    );

    expect(exitCode, 1);
    expect(
      errors,
      contains(
        'Android Rust library missing: '
        'D:/CardMind/build/android-jni/armeabi-v7a/libcardmind_backend.so',
      ),
    );
  });

  test('android build rejects unsupported output formats', () async {
    final errors = <String>[];

    final exitCode = await build.runBuildCli(
      ['app', '--platform', 'android', '--android-format', 'archive'],
      currentDirectory: 'D:/CardMind',
      runProcess: (executable, arguments, {workingDirectory}) async =>
          ProcessResult(1, 0, '', ''),
      log: (_) {},
      logError: errors.add,
      pathExists: (_) => true,
    );

    expect(exitCode, 1);
    expect(errors, contains('Unsupported Android output format'));
  });

  test('android build rejects a missing output format value', () async {
    final errors = <String>[];
    var processCalled = false;

    final exitCode = await build.runBuildCli(
      ['app', '--platform', 'android', '--android-format'],
      currentDirectory: 'D:/CardMind',
      runProcess: (executable, arguments, {workingDirectory}) async {
        processCalled = true;
        return ProcessResult(1, 0, '', '');
      },
      log: (_) {},
      logError: errors.add,
      pathExists: (_) => true,
    );

    expect(exitCode, 1);
    expect(processCalled, isFalse);
    expect(errors, contains('Missing Android output format'));
  });
}

class _ProcessCall {
  const _ProcessCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}
