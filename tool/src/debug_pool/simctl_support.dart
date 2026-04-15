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

Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}
