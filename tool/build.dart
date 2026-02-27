import 'dart:io';

typedef Runner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

const _usage = 'Usage: dart run tool/build.dart <app|lib> [options]';
const _help = '''Usage: dart run tool/build.dart <app|lib> [options]

Commands:
  app    Build Flutter app
  lib    Build Rust dynamic library

Options:
  -h, --help          Show this help message
  app --platform <p>  Set Flutter build platform (macos|linux|windows)
  lib --target <t>    Set Rust target triple for cargo build

Default behavior:
  app runs: lib -> codegen -> flutter build
  app default platform: current host executable platform (macos/linux/windows)
  lib default mode: cargo build --release

Examples:
  dart run tool/build.dart app
  dart run tool/build.dart app --platform macos
  dart run tool/build.dart lib
  dart run tool/build.dart lib --target aarch64-apple-darwin
''';

enum HostPlatform { macos, linux, windows, android, ios }

extension HostPlatformDetect on HostPlatform {
  static HostPlatform detect() {
    if (Platform.isMacOS) {
      return HostPlatform.macos;
    }
    if (Platform.isLinux) {
      return HostPlatform.linux;
    }
    if (Platform.isWindows) {
      return HostPlatform.windows;
    }
    if (Platform.isAndroid) {
      return HostPlatform.android;
    }
    return HostPlatform.ios;
  }
}

Future<void> main(List<String> args) async {
  exitCode = await runBuildCli(args);
}

Future<int> runBuildCli(
  List<String> args, {
  Runner runProcess = _run,
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
  HostPlatform? platformOverride,
}) async {
  if (args.contains('--help') || args.contains('-h')) {
    log(_help);
    return 0;
  }
  if (args.isEmpty) {
    logError(_usage);
    return 1;
  }
  if (args.first == 'lib') {
    return _runLib(
      args.skip(1).toList(),
      runProcess: runProcess,
      log: log,
      logError: logError,
    );
  }
  if (args.first == 'app') {
    return _runApp(
      args.skip(1).toList(),
      runProcess: runProcess,
      log: log,
      logError: logError,
      platformOverride: platformOverride,
    );
  }
  logError(_usage);
  return 1;
}

Future<int> _runApp(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  HostPlatform? platformOverride,
}) async {
  late final String platform;
  try {
    platform = _resolvePlatform(args, platformOverride: platformOverride);
  } on FormatException catch (e) {
    logError(e.message);
    return 1;
  }

  final libExit = await _runLib(
    args,
    runProcess: runProcess,
    log: log,
    logError: logError,
  );
  if (libExit != 0) {
    return libExit;
  }

  final codegen = await runProcess('flutter_rust_bridge_codegen', ['generate']);
  if (codegen.exitCode != 0) {
    logError(_processError(codegen));
    return codegen.exitCode;
  }
  log('[codegen] done');

  final build = await runProcess('flutter', ['build', platform]);
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  log('[build:$platform] done');
  return 0;
}

const Set<String> _supportedPlatforms = {'macos', 'linux', 'windows'};

String _resolvePlatform(List<String> args, {HostPlatform? platformOverride}) {
  final explicit = _readOption(args, '--platform');
  if (explicit != null) {
    if (!_supportedPlatforms.contains(explicit)) {
      throw const FormatException('Unsupported platform');
    }
    return explicit;
  }

  final host = platformOverride ?? HostPlatformDetect.detect();
  switch (host) {
    case HostPlatform.macos:
      return 'macos';
    case HostPlatform.linux:
      return 'linux';
    case HostPlatform.windows:
      return 'windows';
    case HostPlatform.android:
    case HostPlatform.ios:
      throw const FormatException(
        'Current host has no default executable app target',
      );
  }
}

Future<int> _runLib(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
}) async {
  final target = _readOption(args, '--target');
  final cargoArgs = <String>['build', '--release'];
  if (target != null) {
    cargoArgs.addAll(['--target', target]);
  }
  final result = await runProcess(
    'cargo',
    cargoArgs,
    workingDirectory: '${Directory.current.path}/rust',
  );
  if (result.exitCode != 0) {
    logError(_processError(result));
    return result.exitCode;
  }
  log('[lib] done');
  return 0;
}

String? _readOption(List<String> args, String key) {
  final i = args.indexOf(key);
  if (i == -1) {
    return null;
  }
  if (i + 1 >= args.length) {
    return null;
  }
  return args[i + 1];
}

String _processError(ProcessResult result) {
  return 'Process failed with exit code ${result.exitCode}: ${result.stderr}';
}

Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}

void _stdout(String message) => stdout.writeln(message);

void _stderr(String message) => stderr.writeln(message);
