import 'dart:convert';
import 'dart:io';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

class FlutterRunSession {
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

  Stream<String> get stdoutLines => _process == null
      ? const Stream<String>.empty()
      : _process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter());

  Stream<String> get stderrLines => _process == null
      ? const Stream<String>.empty()
      : _process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter());

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
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }
    process.stdin.writeln('q');
    await process.exitCode;
  }
}
