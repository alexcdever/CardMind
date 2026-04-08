// input: 向 build CLI 传入子命令、平台参数与帮助参数。
// output: 返回码、提示文案与进程调用顺序符合约定。
// pos: 覆盖构建脚本分支与参数校验，防止错误构建路径。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/build.dart';

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
      contains('Usage: dart run tool/build.dart <app|lib|run>'),
    );
  });

  test(
    'lib runs cargo build in rust directory with release by default',
    () async {
      final calls = <_ProcCall>[];
      final tempRoot = await _createWorkspaceWithCargoDylib();
      final exit = await runBuildCli(
        const ['lib'],
        runProcess: _fakeRunner(calls),
        currentDirectory: tempRoot.path,
      );
      expect(exit, 0);
      expect(calls.single.executable, 'cargo');
      expect(calls.single.arguments, ['build', '--release']);
      expect(calls.single.workingDirectory, endsWith('/rust'));
    },
  );

  test(
    'lib syncs macOS dylib into build/native/macos after cargo build',
    () async {
      final calls = <_ProcCall>[];
      final tempRoot = await Directory.systemTemp.createTemp(
        'cardmind-build-cli-',
      );
      final source = File(
        '${tempRoot.path}/rust/target/release/libcardmind_rust.dylib',
      )..createSync(recursive: true);
      source.writeAsStringSync('fresh dylib');

      final exit = await runBuildCli(
        const ['lib'],
        runProcess: _fakeRunner(calls),
        currentDirectory: tempRoot.path,
      );

      final synced = File(
        '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
      );
      expect(exit, 0);
      expect(synced.existsSync(), isTrue);
      expect(synced.readAsStringSync(), 'fresh dylib');
    },
  );

  test('lib removes stale runtime dylib before syncing new one', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-build-cli-',
    );
    File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
      ..createSync(recursive: true)
      ..writeAsStringSync('new dylib');
    File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
      ..createSync(recursive: true)
      ..writeAsStringSync('stale dylib');

    final exit = await runBuildCli(
      const ['lib'],
      runProcess: _fakeRunner(<_ProcCall>[]),
      currentDirectory: tempRoot.path,
    );

    final synced = File(
      '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
    );
    expect(exit, 0);
    expect(synced.readAsStringSync(), 'new dylib');
  });

  test(
    'lib deletes stale runtime dylib when source dylib is missing',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cardmind-build-cli-',
      );
      final stale =
          File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
            ..createSync(recursive: true)
            ..writeAsStringSync('stale dylib');

      final exit = await runBuildCli(
        const ['lib'],
        runProcess: _fakeRunner(<_ProcCall>[]),
        currentDirectory: tempRoot.path,
      );

      expect(exit, isNonZero);
      expect(stale.existsSync(), isFalse);
    },
  );

  test('lib stops immediately when cargo build fails', () async {
    final logs = <String>[];
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-build-cli-',
    );
    File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
      ..createSync(recursive: true)
      ..writeAsStringSync('stale dylib');

    final exit = await runBuildCli(
      const ['lib'],
      runProcess: _fakeRunner(
        <_ProcCall>[],
        resultForExecutable: {'cargo': ProcessResult(0, 1, '', 'cargo failed')},
      ),
      currentDirectory: tempRoot.path,
      log: logs.add,
    );

    expect(exit, 1);
    expect(
      logs.join('\n'),
      isNot(contains('build/native/macos/libcardmind_rust.dylib')),
    );
    expect(
      File(
        '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
      ).readAsStringSync(),
      'stale dylib',
    );
  });

  test('lib prints official runtime dylib absolute path after sync', () async {
    final logs = <String>[];
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-build-cli-',
    );
    File('${tempRoot.path}/rust/target/release/libcardmind_rust.dylib')
      ..createSync(recursive: true)
      ..writeAsStringSync('fresh dylib');

    final exit = await runBuildCli(
      const ['lib'],
      runProcess: _fakeRunner(<_ProcCall>[]),
      currentDirectory: tempRoot.path,
      log: logs.add,
    );

    expect(exit, 0);
    expect(
      logs.join('\n'),
      contains(
        File(
          '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
        ).absolute.path,
      ),
    );
  });

  test(
    'lib --target reads cargo dylib from rust/target/<triple>/release',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cardmind-build-cli-',
      );
      File(
          '${tempRoot.path}/rust/target/aarch64-apple-darwin/release/libcardmind_rust.dylib',
        )
        ..createSync(recursive: true)
        ..writeAsStringSync('target dylib');

      final exit = await runBuildCli(
        const ['lib', '--target', 'aarch64-apple-darwin'],
        runProcess: _fakeRunner(<_ProcCall>[]),
        currentDirectory: tempRoot.path,
      );

      expect(exit, 0);
      expect(
        File(
          '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
        ).readAsStringSync(),
        'target dylib',
      );
    },
  );

  test('app runs lib then codegen then flutter build in order', () async {
    final calls = <_ProcCall>[];
    final tempRoot = await _createWorkspaceWithCargoDylib();
    final exit = await runBuildCli(
      const ['app', '--platform', 'macos'],
      runProcess: _fakeRunner(calls),
      currentDirectory: tempRoot.path,
    );
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
      final tempRoot = await _createWorkspaceWithCargoDylib();
      final exit = await runBuildCli(
        const ['app'],
        runProcess: _fakeRunner(calls),
        platformOverride: HostPlatform.macos,
        currentDirectory: tempRoot.path,
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
      contains('Usage: dart run tool/build.dart <app|lib|run>'),
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
      contains('Usage: dart run tool/build.dart <app|lib|run>'),
    );
    expect(logs.join('\n'), contains('Commands:'));
    expect(logs.join('\n'), contains('app    Build Flutter app'));
    expect(logs.join('\n'), contains('lib    Build Rust dynamic library'));
    expect(
      logs.join('\n'),
      contains('run    Build and run Flutter app (macOS only)'),
    );
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
      contains('Usage: dart run tool/build.dart <app|lib|run>'),
    );
    expect(logs.join('\n'), contains('Default behavior:'));
    expect(
      logs.join('\n'),
      contains('app runs: lib -> codegen -> flutter build'),
    );
  });

  test(
    'run logs and copies dylib from build/native/macos into app bundle',
    () async {
      final calls = <_ProcCall>[];
      final logs = <String>[];
      final tempRoot = await _createWorkspaceWithCargoDylib();
      File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
        ..createSync(recursive: true)
        ..writeAsStringSync('stale runtime dylib');
      Directory(
        '${tempRoot.path}/build/macos/Build/Products/Debug/cardmind.app/Contents/Frameworks',
      ).createSync(recursive: true);

      final exit = await runBuildCli(
        const ['run'],
        runProcess: _fakeRunner(calls),
        currentDirectory: tempRoot.path,
        platformOverride: HostPlatform.macos,
        log: logs.add,
      );

      final copied = File(
        '${tempRoot.path}/build/macos/Build/Products/Debug/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib',
      );
      expect(exit, 0);
      expect(copied.readAsStringSync(), 'cargo dylib');
      expect(calls.map((call) => call.executable).toList(), contains('cargo'));
      expect(
        calls.map((call) => call.executable).toList(),
        contains('flutter'),
      );
      expect(
        logs.join('\n'),
        contains('build/native/macos/libcardmind_rust.dylib'),
      );
      expect(
        logs.join('\n'),
        isNot(contains('rust/target/release/libcardmind_rust.dylib')),
      );
    },
  );

  test(
    'run reports official runtime dylib path when bundle copy input disappears after lib step',
    () async {
      final logs = <String>[];
      final tempRoot = await _createWorkspaceWithCargoDylib();
      final runtime =
          File('${tempRoot.path}/build/native/macos/libcardmind_rust.dylib')
            ..createSync(recursive: true)
            ..writeAsStringSync('stale runtime dylib');

      var removedAfterBuild = false;
      final runner = _fakeRunner(
        <_ProcCall>[],
        afterCall: (call) {
          if (!removedAfterBuild && call.executable == 'flutter') {
            removedAfterBuild = true;
            if (runtime.existsSync()) {
              runtime.deleteSync();
            }
          }
        },
      );

      final exit = await runBuildCli(
        const ['run'],
        runProcess: runner,
        currentDirectory: tempRoot.path,
        platformOverride: HostPlatform.macos,
        logError: logs.add,
      );

      expect(exit, isNonZero);
      expect(
        logs.join('\n'),
        contains('build/native/macos/libcardmind_rust.dylib'),
      );
    },
  );
}

Future<ProcessResult> _noProcessExpected(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('No process expected: $executable ${arguments.join(' ')}');
}

Runner _fakeRunner(
  List<_ProcCall> calls, {
  Map<String, ProcessResult>? resultForExecutable,
  void Function(_ProcCall call)? afterCall,
}) {
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
    afterCall?.call(calls.last);
    return resultForExecutable?[executable] ?? ProcessResult(0, 0, '', '');
  };
}

Future<Directory> _createWorkspaceWithCargoDylib({String? target}) async {
  final tempRoot = await Directory.systemTemp.createTemp('cardmind-build-cli-');
  final relative = target == null
      ? 'rust/target/release/libcardmind_rust.dylib'
      : 'rust/target/$target/release/libcardmind_rust.dylib';
  File('${tempRoot.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync('cargo dylib');
  return tempRoot;
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
