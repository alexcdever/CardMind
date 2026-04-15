import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'flutter_run_session.dart';

class MacosBuildRunSession implements DebugSession {
  MacosBuildRunSession({
    required this.executable,
    required this.dartDefines,
    required this.processStarter,
    required this.workingDirectory,
    this.appCopyName,
    this.appBundleId,
    this.appSupportDir,
    this.invitePath,
    this.statusPath,
  });

  final String executable;
  final Map<String, String> dartDefines;
  final ProcessStarter processStarter;
  final String workingDirectory;
  final String? appCopyName;
  final String? appBundleId;
  final String? appSupportDir;
  final String? invitePath;
  final String? statusPath;

  final StreamController<String> _lineController =
      StreamController<String>.broadcast();
  final List<String> _recentLines = <String>[];
  Process? _process;

  @override
  Stream<String> get stdoutLines => _lineController.stream;

  @override
  Stream<String> get stderrLines => _lineController.stream;

  @override
  List<String> get recentLines => List<String>.unmodifiable(_recentLines);

  @override
  Future<void> start() async {
    final supportDir = appSupportDir;
    if (supportDir != null && supportDir.isNotEmpty) {
      final directory = Directory(supportDir);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
    final args = <String>['run', 'tool/build.dart', 'run'];
    if (appCopyName != null && appCopyName!.isNotEmpty) {
      args.addAll(<String>['--app-copy-name', appCopyName!]);
    }
    if (appBundleId != null && appBundleId!.isNotEmpty) {
      args.addAll(<String>['--app-bundle-id', appBundleId!]);
    }
    for (final entry in dartDefines.entries) {
      args.add('--dart-define');
      args.add('${entry.key}=${entry.value}');
    }
    _process = await processStarter(
      executable,
      args,
      workingDirectory: workingDirectory,
    );
    unawaited(_pipeLines(_process!.stdout));
    unawaited(_pipeLines(_process!.stderr));
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }
    if (process.kill()) {
      await process.exitCode;
    }
    final appCopy = appCopyName;
    if (appCopy != null && appCopy.isNotEmpty) {
      await Process.run('pkill', <String>[
        '-f',
        '$workingDirectory/build/macos/Build/Products/Debug/$appCopy',
      ]);
    }
  }

  @override
  Future<String?> waitForLine(
    bool Function(String line) predicate, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    for (final line in _recentLines) {
      if (predicate(line)) {
        return line;
      }
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final invite = await _readInviteLine();
      if (invite != null && predicate(invite)) {
        return invite;
      }

      final status = await _readStatusLine();
      if (status != null && predicate(status)) {
        return status;
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  Future<String?> _readInviteLine() async {
    final path = invitePath;
    if (path == null) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final value = file.readAsStringSync().trim();
    if (value.isEmpty) {
      return null;
    }
    return 'pool_debug.invite:$value';
  }

  Future<String?> _readStatusLine() async {
    final path = statusPath;
    if (path == null) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final lines = file
        .readAsStringSync()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }
    return lines.last;
  }

  Future<void> _pipeLines(Stream<List<int>> source) async {
    await for (final line
        in source.transform(utf8.decoder).transform(const LineSplitter())) {
      _recentLines.add(line);
      if (_recentLines.length > 200) {
        _recentLines.removeAt(0);
      }
      _lineController.add(line);
    }
  }
}
