import 'dart:io';

import '../../debug_pool.dart';
import 'flutter_run_session.dart';

typedef SessionFactory =
    Future<FlutterRunSession> Function(_OwnerSessionConfig config);

class DebugPoolRunner {
  DebugPoolRunner({
    required this.runner,
    SessionFactory? ownerSessionFactory,
  }) : ownerSessionFactory = ownerSessionFactory ?? _defaultOwnerSessionFactory;

  final Runner runner;
  final SessionFactory ownerSessionFactory;

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
    return DebugPoolRunResult(
      ownerTarget: owner,
      joinerTarget: joiner,
      invite: await captureOwnerInvite(deviceId: owner, pin: pin),
      joinTraceSeen: false,
      finalStatus: 'not_implemented',
    );
  }

  Future<String> captureOwnerInvite({
    required String deviceId,
    required String pin,
  }) async {
    final session = await ownerSessionFactory(
      _OwnerSessionConfig(deviceId: deviceId, pin: pin, runner: runner),
    );
    await session.start();
    await for (final line in session.stdoutLines) {
      final trimmed = line.trim();
      const prefix = 'flutter: pool_debug.invite:';
      if (trimmed.startsWith(prefix)) {
        return trimmed.substring(prefix.length);
      }
    }
    throw StateError('owner invite not found in session output');
  }
}

class DebugPoolRunResult {
  const DebugPoolRunResult({
    required this.ownerTarget,
    required this.joinerTarget,
    required this.invite,
    required this.joinTraceSeen,
    required this.finalStatus,
  });

  final String ownerTarget;
  final String joinerTarget;
  final String invite;
  final bool joinTraceSeen;
  final String finalStatus;
}

Future<FlutterRunSession> _defaultOwnerSessionFactory(
  _OwnerSessionConfig config,
) async {
  return FlutterRunSession(
    executable: 'flutter',
    deviceId: config.deviceId,
    dartDefines: <String, String>{
      'CARDMIND_DEBUG_START_IN_POOL': 'true',
      'CARDMIND_DEBUG_AUTO_CREATE_POOL': 'true',
      'CARDMIND_DEBUG_PRINT_INVITE': 'true',
      'CARDMIND_DEBUG_PIN': config.pin,
    },
    processStarter: (
      executable,
      arguments, {
      workingDirectory,
    }) => config.runner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    ),
  );
}

class _OwnerSessionConfig {
  const _OwnerSessionConfig({
    required this.deviceId,
    required this.pin,
    required this.runner,
  });

  final String deviceId;
  final String pin;
  final Runner runner;
}
