import 'dart:io';

typedef SimctlRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

Future<String> resolveJoinerDeviceId({
  required String joiner,
  required String? explicitDeviceId,
  SimctlRunner runner = _run,
}) async {
  if (joiner != 'ios-sim') {
    return joiner;
  }
  if (explicitDeviceId != null && explicitDeviceId.isNotEmpty) {
    return explicitDeviceId;
  }

  final result = await runner('xcrun', const ['simctl', 'list', 'devices', 'booted']);
  if (result.exitCode != 0) {
    throw StateError('failed to query booted iOS simulator: ${result.stderr}');
  }

  final match = RegExp(r'\(([0-9A-F-]{36})\) \(Booted\)').firstMatch(
    result.stdout.toString(),
  );
  if (match == null) {
    throw StateError('no booted iOS simulator found');
  }
  return match.group(1)!;
}

Future<String> readIosSimulatorFinalStatus({
  required String deviceId,
  String bundleId = 'com.example.cardmind',
  SimctlRunner runner = _run,
  Duration timeout = const Duration(seconds: 45),
  Duration pollInterval = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final container = await _readAppContainer(
      deviceId: deviceId,
      bundleId: bundleId,
      runner: runner,
    );
    final logFile = File('$container/Library/Application Support/debug_status.log');
    if (logFile.existsSync()) {
      final status = _extractFinalStatus(logFile.readAsStringSync());
      if (status != null) {
        return status;
      }
    }
    await Future<void>.delayed(pollInterval);
  }
  throw StateError('timed out waiting for iOS simulator join result');
}

Future<String> _readAppContainer({
  required String deviceId,
  required String bundleId,
  required SimctlRunner runner,
}) async {
  final result = await runner(
    'xcrun',
    <String>['simctl', 'get_app_container', deviceId, bundleId, 'data'],
  );
  if (result.exitCode != 0) {
    throw StateError('failed to read iOS app container: ${result.stderr}');
  }
  final path = result.stdout.toString().trim();
  if (path.isEmpty) {
    throw StateError('iOS app container path is empty');
  }
  return path;
}

String? extractFinalStatus(String content) => _extractFinalStatus(content);

String? _extractFinalStatus(String content) {
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  String? finalStatus;
  for (final line in lines) {
    if (line.startsWith('joined:') || line.startsWith('join_error:')) {
      finalStatus = line;
    }
  }
  return finalStatus;
}

Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}
