import 'dart:io';

import 'package:cardmind/app/debug_startup_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'debug status export is enabled when any debug bootstrap switch is set',
    () {
      expect(
        shouldEnableDefaultDebugStatusExport(
          debugStartInPool: true,
          debugAutoCreatePool: false,
          debugAutoPin: '',
          debugAutoJoinCode: '',
        ),
        isTrue,
      );
      expect(
        shouldEnableDefaultDebugStatusExport(
          debugStartInPool: false,
          debugAutoCreatePool: true,
          debugAutoPin: '',
          debugAutoJoinCode: '',
        ),
        isTrue,
      );
      expect(
        shouldEnableDefaultDebugStatusExport(
          debugStartInPool: false,
          debugAutoCreatePool: false,
          debugAutoPin: '1234',
          debugAutoJoinCode: '',
        ),
        isTrue,
      );
      expect(
        shouldEnableDefaultDebugStatusExport(
          debugStartInPool: false,
          debugAutoCreatePool: false,
          debugAutoPin: '',
          debugAutoJoinCode: 'join-code',
        ),
        isTrue,
      );
    },
  );

  test(
    'debug status export is disabled when all debug bootstrap switches are empty',
    () {
      expect(
        shouldEnableDefaultDebugStatusExport(
          debugStartInPool: false,
          debugAutoCreatePool: false,
          debugAutoPin: '',
          debugAutoJoinCode: '',
        ),
        isFalse,
      );
    },
  );

  test(
    'invite export is enabled only when pool bootstrap and auto create are both enabled',
    () {
      expect(
        shouldEnableDefaultInviteExport(
          debugStartInPool: true,
          debugAutoCreatePool: true,
        ),
        isTrue,
      );
      expect(
        shouldEnableDefaultInviteExport(
          debugStartInPool: true,
          debugAutoCreatePool: false,
        ),
        isFalse,
      );
      expect(
        shouldEnableDefaultInviteExport(
          debugStartInPool: false,
          debugAutoCreatePool: true,
        ),
        isFalse,
      );
    },
  );

  test('writeStartupDebugStatus appends line when path is present', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-debug-startup-',
    );
    final logFile = File('${tempRoot.path}/debug/status.log');

    await writeStartupDebugStatus(logFile.path, 'main_started');
    await writeStartupDebugStatus(logFile.path, 'app_ready');

    expect(logFile.readAsStringSync(), 'main_started\napp_ready\n');
  });

  test('writeStartupDebugStatus returns when path is empty', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-debug-startup-',
    );
    final logFile = File('${tempRoot.path}/debug/status.log');

    await writeStartupDebugStatus('', 'ignored');
    await writeStartupDebugStatus(null, 'ignored');

    expect(logFile.existsSync(), isFalse);
  });
}
