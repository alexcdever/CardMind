import 'dart:convert';
import 'dart:io';
import 'dart:async';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

abstract class DebugSession {
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  List<String> get recentLines;

  Future<void> start();
  Future<void> stop();
  Future<String?> waitForLine(
    bool Function(String line) predicate, {
    Duration timeout = const Duration(seconds: 30),
  });
}

class FlutterRunSession implements DebugSession {
  FlutterRunSession({
    required this.executable,
    required this.deviceId,
    required this.dartDefines,
    required this.processStarter,
    this.workingDirectory,
  });

  final String executable;
  final String deviceId;
  final Map<String, String> dartDefines;
  final ProcessStarter processStarter;
  final String? workingDirectory;

  Process? _process;
  final StreamController<String> _lineController =
      StreamController<String>.broadcast();
  final List<String> _recentLines = <String>[];

  @override
  Stream<String> get stdoutLines => _lineController.stream;

  @override
  Stream<String> get stderrLines => _lineController.stream;

  @override
  List<String> get recentLines => List<String>.unmodifiable(_recentLines);

  @override
  Future<void> start() async {
    final args = <String>['run', '-d', deviceId];
    for (final entry in dartDefines.entries) {
      args.add('--dart-define=${entry.key}=${entry.value}');
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
    process.stdin.writeln('q');
    await process.exitCode;
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
    try {
      return await _lineController.stream
          .firstWhere(predicate)
          .timeout(timeout);
    } on TimeoutException {
      return null;
    }
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
