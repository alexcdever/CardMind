import 'dart:io';

import 'src/debug_pool/debug_pool_runner.dart';

typedef Runner =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

const _usage = 'Usage: dart run tool/debug_pool.dart --owner macos --joiner <macos|ios-sim> [options]';

Future<void> main(List<String> args) async {
  exitCode = await runDebugPoolCli(args);
}

Future<int> runDebugPoolCli(
  List<String> args, {
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
  Runner runner = _run,
  DebugPoolRunner? orchestrator,
}) async {
  if (args.isEmpty) {
    logError(_usage);
    return 1;
  }

  final owner = _readOption(args, '--owner');
  final joiner = _readOption(args, '--joiner');
  if (owner == null || joiner == null) {
    logError(_usage);
    return 1;
  }
  if (owner != 'macos') {
    logError('owner only supports macos');
    return 1;
  }
  if (joiner != 'macos' && joiner != 'ios-sim') {
    logError('joiner only supports macos or ios-sim');
    return 1;
  }
  if (_readOption(args, '--ios-device') != null && joiner != 'ios-sim') {
    logError('--ios-device only works with --joiner ios-sim');
    return 1;
  }

  final effectiveOrchestrator = orchestrator ?? DebugPoolRunner(runner: runner);
  final result = await effectiveOrchestrator.run(
    owner: owner,
    joiner: joiner,
    pin: _readOption(args, '--pin') ?? '1234',
    iosDeviceId: _readOption(args, '--ios-device'),
    keepRunning: args.contains('--keep-running'),
    verbose: args.contains('--verbose'),
    log: log,
    logError: logError,
  );
  log('owner: ${result.ownerTarget}');
  log('joiner: ${result.joinerTarget}');
  log('invite captured: ${result.invite.isNotEmpty}');
  log('join trace seen: ${result.joinTraceSeen}');
  log('final status: ${result.finalStatus}');
  return 0;
}

String? _readOption(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

Future<Process> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

void _stdout(String message) => stdout.writeln(message);

void _stderr(String message) => stderr.writeln(message);
