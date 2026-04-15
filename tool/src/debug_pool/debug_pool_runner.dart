import 'dart:io';
import 'dart:async';

import '../../debug_pool.dart';
import 'flutter_run_session.dart';
import 'macos_build_run_session.dart';
import 'simctl_support.dart';

typedef SessionFactory =
    Future<DebugSession> Function(DebugSessionConfig config);

class DebugPoolRunner {
  DebugPoolRunner({
    required this.runner,
    SessionFactory? ownerSessionFactory,
    SessionFactory? joinerSessionFactory,
    SimctlRunner? simctlRunner,
  }) : ownerSessionFactory = ownerSessionFactory ?? _defaultOwnerSessionFactory,
       joinerSessionFactory =
           joinerSessionFactory ?? _defaultJoinerSessionFactory,
       simctlRunner = simctlRunner ?? _runSimctl;

  final Runner runner;
  final SessionFactory ownerSessionFactory;
  final SessionFactory joinerSessionFactory;
  final SimctlRunner simctlRunner;

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
    const ownerBundleId = 'com.example.cardmind.owner';
    DebugSession? ownerSession;
    DebugSession? joinerSession;
    try {
      ownerSession = await ownerSessionFactory(
        DebugSessionConfig(
          deviceId: owner,
          targetKind: owner,
          appCopyName: 'cardmind-owner.app',
          appBundleId: ownerBundleId,
          pin: pin,
          runner: runner,
        ),
      );
      await ownerSession.start();
      final invite = await _waitForInvite(ownerSession);

      final resolvedJoinerTarget = await resolveJoinerDeviceId(
        joiner: joiner,
        explicitDeviceId: iosDeviceId,
        runner: simctlRunner,
      );
      final joinerBundleId = joiner == 'macos'
          ? 'com.example.cardmind.joiner'
          : null;
      final joinerStatusPath = joinerBundleId == null
          ? null
          : _macosDebugStatusPath(joinerBundleId);
      joinerSession = await joinerSessionFactory(
        DebugSessionConfig(
          deviceId: resolvedJoinerTarget,
          targetKind: joiner,
          appCopyName: joiner == 'macos' ? 'cardmind-joiner.app' : null,
          appBundleId: joinerBundleId,
          pin: pin,
          runner: runner,
          invite: invite,
          debugStatusPath: joinerStatusPath,
        ),
      );
      await joinerSession.start();

      final traceLine = await joinerSession.waitForLine(
        (line) => line.contains('pool_debug.join.'),
        timeout: const Duration(seconds: 10),
      );
      final finalStatus = joiner == 'ios-sim'
          ? await readIosSimulatorFinalStatus(
              deviceId: resolvedJoinerTarget,
              runner: simctlRunner,
            )
          : await _readMacosFinalStatus(joinerStatusPath!);

      return DebugPoolRunResult(
        ownerTarget: owner,
        joinerTarget: joiner,
        invite: invite,
        joinTraceSeen: traceLine != null,
        finalStatus: finalStatus,
      );
    } finally {
      if (!keepRunning) {
        if (joinerSession != null) {
          await joinerSession.stop();
        }
        if (ownerSession != null) {
          await ownerSession.stop();
        }
      }
    }
  }

  Future<String> captureOwnerInvite({
    required String deviceId,
    required String pin,
  }) async {
    final session = await ownerSessionFactory(
      DebugSessionConfig(
        deviceId: deviceId,
        targetKind: deviceId,
        appCopyName: 'cardmind-owner.app',
        appBundleId: 'com.example.cardmind.owner',
        pin: pin,
        runner: runner,
      ),
    );
    await session.start();
    try {
      return await _waitForInvite(session);
    } finally {
      await session.stop();
    }
  }

  Future<String> _waitForInvite(DebugSession session) async {
    final line = await session.waitForLine((line) {
      final normalized = line.trim();
      return normalized.startsWith('flutter: pool_debug.invite:') ||
          normalized.startsWith('pool_debug.invite:');
    }, timeout: const Duration(seconds: 60));
    if (line == null) {
      throw StateError('owner invite not found in session output');
    }
    final normalized = line.trim();
    if (normalized.startsWith('flutter: pool_debug.invite:')) {
      return normalized.substring('flutter: pool_debug.invite:'.length);
    }
    return normalized.substring('pool_debug.invite:'.length);
  }

  Future<String> _readMacosFinalStatus(String statusPath) async {
    final file = File(statusPath);
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      if (file.existsSync()) {
        final status = extractFinalStatus(file.readAsStringSync());
        if (status != null) {
          return status;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('timed out waiting for macOS join result');
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

Future<DebugSession> _defaultOwnerSessionFactory(
  DebugSessionConfig config,
) async {
  if (config.targetKind == 'macos') {
    return MacosBuildRunSession(
      executable: 'dart',
      dartDefines: <String, String>{
        'CARDMIND_DEBUG_START_IN_POOL': 'true',
        'CARDMIND_DEBUG_AUTO_CREATE_POOL': 'true',
        'CARDMIND_DEBUG_PRINT_INVITE': 'true',
        'CARDMIND_DEBUG_PIN': config.pin,
      },
      processStarter: (executable, arguments, {workingDirectory}) => config
          .runner(executable, arguments, workingDirectory: workingDirectory),
      workingDirectory: Directory.current.path,
      appCopyName: config.appCopyName,
      appBundleId: config.appBundleId,
      appSupportDir: _macosAppSupportDir(config.appBundleId!),
      invitePath: _macosDebugInvitePath(config.appBundleId!),
    );
  }

  return FlutterRunSession(
    executable: 'flutter',
    deviceId: config.deviceId,
    dartDefines: <String, String>{
      'CARDMIND_DEBUG_START_IN_POOL': 'true',
      'CARDMIND_DEBUG_AUTO_CREATE_POOL': 'true',
      'CARDMIND_DEBUG_PRINT_INVITE': 'true',
      'CARDMIND_DEBUG_PIN': config.pin,
    },
    processStarter: (executable, arguments, {workingDirectory}) => config
        .runner(executable, arguments, workingDirectory: workingDirectory),
  );
}

class DebugSessionConfig {
  const DebugSessionConfig({
    required this.deviceId,
    required this.targetKind,
    required this.appCopyName,
    required this.appBundleId,
    required this.pin,
    required this.runner,
    this.invite,
    this.debugStatusPath,
  });

  final String deviceId;
  final String targetKind;
  final String? appCopyName;
  final String? appBundleId;
  final String pin;
  final Runner runner;
  final String? invite;
  final String? debugStatusPath;
}

Future<DebugSession> _defaultJoinerSessionFactory(
  DebugSessionConfig config,
) async {
  if (config.targetKind == 'macos') {
    return MacosBuildRunSession(
      executable: 'dart',
      dartDefines: <String, String>{
        'CARDMIND_DEBUG_START_IN_POOL': 'true',
        'CARDMIND_DEBUG_PIN': config.pin,
        'CARDMIND_DEBUG_JOIN_CODE': config.invite ?? '',
        'CARDMIND_DEBUG_JOIN_TRACE': 'true',
        if (config.debugStatusPath != null)
          'CARDMIND_DEBUG_STATUS_EXPORT_PATH': config.debugStatusPath!,
      },
      processStarter: (executable, arguments, {workingDirectory}) => config
          .runner(executable, arguments, workingDirectory: workingDirectory),
      workingDirectory: Directory.current.path,
      appCopyName: config.appCopyName,
      appBundleId: config.appBundleId,
      appSupportDir: _macosAppSupportDir(config.appBundleId!),
      statusPath: config.debugStatusPath,
    );
  }

  return FlutterRunSession(
    executable: 'flutter',
    deviceId: config.deviceId,
    dartDefines: <String, String>{
      'CARDMIND_DEBUG_START_IN_POOL': 'true',
      'CARDMIND_DEBUG_PIN': config.pin,
      'CARDMIND_DEBUG_JOIN_CODE': config.invite ?? '',
      'CARDMIND_DEBUG_JOIN_TRACE': 'true',
      if (config.debugStatusPath != null)
        'CARDMIND_DEBUG_STATUS_EXPORT_PATH': config.debugStatusPath!,
    },
    processStarter: (executable, arguments, {workingDirectory}) => config
        .runner(executable, arguments, workingDirectory: workingDirectory),
  );
}

Future<ProcessResult> _runSimctl(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}

String _macosAppSupportDir(String bundleId) {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw StateError('HOME is not available for macOS debug session');
  }
  return '$home/Library/Application Support/$bundleId';
}

String _macosDebugInvitePath(String bundleId) {
  return '${_macosAppSupportDir(bundleId)}/debug_invite.txt';
}

String _macosDebugStatusPath(String bundleId) {
  return '${_macosAppSupportDir(bundleId)}/debug_status.log';
}
