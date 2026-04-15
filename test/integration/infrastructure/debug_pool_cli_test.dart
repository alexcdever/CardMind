import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/debug_pool.dart';
import '../../../tool/src/debug_pool/debug_pool_runner.dart';
import '../../../tool/src/debug_pool/flutter_run_session.dart';
import '../../../tool/src/debug_pool/macos_build_run_session.dart';
import '../../../tool/src/debug_pool/simctl_support.dart';

void main() {
  test('prints usage when owner or joiner is missing', () async {
    final logs = <String>[];

    final exit = await runDebugPoolCli(
      const [],
      log: logs.add,
      logError: logs.add,
      runner: _noRunnerExpected,
    );

    expect(exit, 1);
    expect(logs.join('\n'), contains('Usage: dart run tool/debug_pool.dart'));
  });

  test('rejects unsupported owner or joiner values', () async {
    final logs = <String>[];

    final exit = await runDebugPoolCli(
      const ['--owner', 'ios-sim', '--joiner', 'macos'],
      log: logs.add,
      logError: logs.add,
      runner: _noRunnerExpected,
    );

    expect(exit, 1);
    expect(logs.join('\n'), contains('owner only supports macos'));
  });

  test('builds flutter run command with dart-defines', () async {
    final calls = <_ProcCall>[];
    final session = FlutterRunSession(
      executable: 'flutter',
      deviceId: 'macos',
      dartDefines: const {
        'CARDMIND_DEBUG_START_IN_POOL': 'true',
        'CARDMIND_DEBUG_PIN': '1234',
      },
      processStarter: _fakeStarter(calls),
    );

    await session.start();

    expect(calls.single.executable, 'flutter');
    expect(
      calls.single.arguments,
      containsAll(<String>[
        'run',
        '-d',
        'macos',
        '--dart-define=CARDMIND_DEBUG_START_IN_POOL=true',
        '--dart-define=CARDMIND_DEBUG_PIN=1234',
      ]),
    );
  });

  test('builds macos build-run command with dart-define pairs', () async {
    final calls = <_ProcCall>[];
    final session = MacosBuildRunSession(
      executable: 'dart',
      dartDefines: const {
        'CARDMIND_DEBUG_START_IN_POOL': 'true',
        'CARDMIND_DEBUG_PIN': '1234',
      },
      processStarter: _fakeStarter(calls),
      workingDirectory: '/repo',
      appCopyName: 'cardmind-owner.app',
      appBundleId: 'com.example.cardmind.owner',
    );

    await session.start();

    expect(calls.single.executable, 'dart');
    expect(calls.single.workingDirectory, '/repo');
    expect(calls.single.arguments, <String>[
      'run',
      'tool/build.dart',
      'run',
      '--app-copy-name',
      'cardmind-owner.app',
      '--app-bundle-id',
      'com.example.cardmind.owner',
      '--dart-define',
      'CARDMIND_DEBUG_START_IN_POOL=true',
      '--dart-define',
      'CARDMIND_DEBUG_PIN=1234',
    ]);
  });

  test(
    'captures first owner invite from macos exported invite session',
    () async {
      final session = _FakeDebugSession(
        lines: const [
          'booting...',
          'pool_debug.invite:invite-123',
          'pool_debug.invite:invite-456',
        ],
      );

      final result = await DebugPoolRunner(
        runner: _noRunnerExpected,
        ownerSessionFactory: (_) async => session,
      ).captureOwnerInvite(deviceId: 'macos', pin: '1234');

      expect(result, 'invite-123');
    },
  );

  test('uses booted ios simulator when ios-device is omitted', () async {
    final calls = <_ProcCall>[];

    final deviceId = await resolveJoinerDeviceId(
      joiner: 'ios-sim',
      explicitDeviceId: null,
      runner: _fakeProcessResultRunner(
        calls,
        stdoutForCommand: <String, String>{
          'xcrun simctl list devices booted':
              '== Devices ==\n-- iOS 18.4 --\n    iPhone 16 Pro (C2A658D0-C55F-4010-A373-B3D2F4F62633) (Booted)\n',
        },
      ),
    );

    expect(deviceId, 'C2A658D0-C55F-4010-A373-B3D2F4F62633');
    expect(calls.single.arguments, <String>[
      'simctl',
      'list',
      'devices',
      'booted',
    ]);
  });

  test('prints joined result after owner and joiner complete', () async {
    final logs = <String>[];

    final exit = await runDebugPoolCli(
      const ['--owner', 'macos', '--joiner', 'ios-sim'],
      log: logs.add,
      logError: logs.add,
      orchestrator: _FakeDebugPoolRunner(
        result: const DebugPoolRunResult(
          ownerTarget: 'macos',
          joinerTarget: 'ios-sim',
          invite: 'invite-123',
          joinTraceSeen: true,
          finalStatus: 'joined:pool-123',
        ),
      ),
    );

    expect(exit, 0);
    expect(logs.join('\n'), contains('joined:pool-123'));
    expect(logs.join('\n'), contains('invite captured'));
  });
}

Never _noRunnerExpected(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('No process expected: $executable ${arguments.join(' ')}');
}

ProcessStarter _fakeStarter(List<_ProcCall> calls) {
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
    return _FakeProcess();
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

class _FakeProcess implements Process {
  @override
  Future<int> get exitCode async => 0;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _FakeDebugSession implements DebugSession {
  _FakeDebugSession({required List<String> lines}) : _lines = lines;

  final List<String> _lines;

  @override
  List<String> get recentLines => List<String>.unmodifiable(_lines);

  @override
  Stream<String> get stderrLines => const Stream<String>.empty();

  @override
  Stream<String> get stdoutLines => Stream<String>.fromIterable(_lines);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<String?> waitForLine(
    bool Function(String line) predicate, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    for (final line in _lines) {
      if (predicate(line)) {
        return line;
      }
    }
    return null;
  }
}

SimctlRunner _fakeProcessResultRunner(
  List<_ProcCall> calls, {
  required Map<String, String> stdoutForCommand,
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
    final key = '$executable ${arguments.join(' ')}';
    return ProcessResult(1, 0, stdoutForCommand[key] ?? '', '');
  };
}

class _FakeDebugPoolRunner extends DebugPoolRunner {
  _FakeDebugPoolRunner({required this.result})
    : super(runner: _noRunnerExpected);

  final DebugPoolRunResult result;

  @override
  Future<DebugPoolRunResult> run({
    required String owner,
    required String joiner,
    required String pin,
    required String? iosDeviceId,
    required bool keepRunning,
    required bool verbose,
    required void Function(String) log,
    required void Function(String) logError,
  }) async {
    return result;
  }
}
