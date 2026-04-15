import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/debug_pool.dart';
import '../../../tool/src/debug_pool/debug_pool_runner.dart';
import '../../../tool/src/debug_pool/flutter_run_session.dart';

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

  test('captures first owner invite from session logs', () async {
    final session = _FakeFlutterRunSession(
      lines: const [
        'booting...',
        'flutter: pool_debug.invite:invite-123',
        'flutter: pool_debug.invite:invite-456',
      ],
    );

    final result = await DebugPoolRunner(
      runner: _noRunnerExpected,
      ownerSessionFactory: (_) async => session,
    ).captureOwnerInvite(deviceId: 'macos', pin: '1234');

    expect(result, 'invite-123');
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

class _FakeFlutterRunSession extends FlutterRunSession {
  _FakeFlutterRunSession({required List<String> lines})
    : _lines = lines,
      super(
        executable: 'flutter',
        deviceId: 'macos',
        dartDefines: const {},
        processStarter: _unusedStarter,
      );

  final List<String> _lines;

  @override
  Stream<String> get stdoutLines => Stream<String>.fromIterable(_lines);

  @override
  Stream<String> get stderrLines => const Stream<String>.empty();

  @override
  Future<void> start() async {}
}

Never _unusedStarter(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('No process expected: $executable ${arguments.join(' ')}');
}
