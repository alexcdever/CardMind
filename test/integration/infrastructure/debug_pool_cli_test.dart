import 'package:flutter_test/flutter_test.dart';

import '../../../tool/debug_pool.dart';

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
}

Never _noRunnerExpected(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('No process expected: $executable ${arguments.join(' ')}');
}
