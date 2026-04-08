import 'dart:io';

typedef Runner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

const _usage = 'Usage: dart run tool/build.dart <app|lib|run> [options]';
const _help = '''Usage: dart run tool/build.dart <app|lib|run> [options]

Commands:
  app    Build Flutter app
  lib    Build Rust dynamic library
  run    Build and run Flutter app (macOS only)

Options:
  -h, --help          Show this help message
  app --platform <p>  Set Flutter build platform (macos|linux|windows)
  lib --target <t>    Set Rust target triple for cargo build

Default behavior:
  app runs: lib -> codegen -> flutter build
  run runs: lib -> flutter build -> copy framework -> open app
  app default platform: current host executable platform (macos/linux/windows)
  lib default mode: cargo build --release

Examples:
  dart run tool/build.dart app
  dart run tool/build.dart app --platform macos
  dart run tool/build.dart lib
  dart run tool/build.dart lib --target aarch64-apple-darwin
  dart run tool/build.dart run
''';

/// 构建目标平台枚举
enum HostPlatform { macos, linux, windows, android, ios }

extension HostPlatformDetect on HostPlatform {
  /// 检测当前主机平台
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

/// 主函数
Future<void> main(List<String> args) async {
  exitCode = await runBuildCli(args);
}

/// 构建命令行入口
Future<int> runBuildCli(
  List<String> args, {
  Runner runProcess = _run,
  void Function(String) log = _stdout,
  void Function(String) logError = _stderr,
  HostPlatform? platformOverride,
  String? currentDirectory,
}) async {
  final rootDir = currentDirectory ?? Directory.current.path;
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
      rootDir: rootDir,
    );
  }
  if (args.first == 'app') {
    return _runApp(
      args.skip(1).toList(),
      runProcess: runProcess,
      log: log,
      logError: logError,
      platformOverride: platformOverride,
      rootDir: rootDir,
    );
  }
  if (args.first == 'run') {
    return _runAndOpen(
      args.skip(1).toList(),
      runProcess: runProcess,
      log: log,
      logError: logError,
      rootDir: rootDir,
    );
  }
  logError(_usage);
  return 1;
}

const Set<String> _supportedPlatforms = {'macos', 'linux', 'windows'};

/// 解析目标平台参数
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

/// 构建Flutter应用
Future<int> _runApp(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  HostPlatform? platformOverride,
  required String rootDir,
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
    rootDir: rootDir,
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

/// 构建Rust库
Future<int> _runLib(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  required String rootDir,
}) async {
  final target = _readOption(args, '--target');
  final cargoArgs = <String>['build', '--release'];
  if (target != null) {
    cargoArgs.addAll(['--target', target]);
  }
  final result = await runProcess(
    'cargo',
    cargoArgs,
    workingDirectory: '$rootDir/rust',
  );
  if (result.exitCode != 0) {
    logError(_processError(result));
    return result.exitCode;
  }

  final runtimeDylib = _runtimeDylibPath(rootDir);
  final runtimeFile = File(runtimeDylib);
  if (runtimeFile.existsSync()) {
    runtimeFile.deleteSync();
  }

  final sourceDylib = _cargoDylibPath(rootDir, target: target);
  final sourceFile = File(sourceDylib);
  if (!sourceFile.existsSync()) {
    logError('Runtime dylib sync failed: source not found at $sourceDylib');
    return 1;
  }

  try {
    runtimeFile.parent.createSync(recursive: true);
    sourceFile.copySync(runtimeDylib);
  } on FileSystemException catch (e) {
    if (runtimeFile.existsSync()) {
      runtimeFile.deleteSync();
    }
    logError('Runtime dylib sync failed: ${e.message}');
    return 1;
  }

  log('[lib] Rust library built successfully');
  log('[lib] runtime dylib: ${runtimeFile.absolute.path}');

  log('[lib] done');
  return 0;
}

String _cargoDylibPath(String rootDir, {String? target}) {
  final targetDir = target == null
      ? 'target/release'
      : 'target/$target/release';
  return '$rootDir/rust/$targetDir/libcardmind_rust.dylib';
}

String _runtimeDylibPath(String rootDir) {
  return '$rootDir/build/native/macos/libcardmind_rust.dylib';
}

/// 读取命令行选项
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

/// 格式化进程错误信息
String _processError(ProcessResult result) {
  return 'Process failed with exit code ${result.exitCode}: ${result.stderr}';
}

/// 运行外部命令
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(executable, arguments, workingDirectory: workingDirectory);
}

/// 输出到stdout
void _stdout(String message) => stdout.writeln(message);

/// 输出到stderr
void _stderr(String message) => stderr.writeln(message);

/// 构建并打开应用（macOS）
Future<int> _runAndOpen(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  required String rootDir,
}) async {
  if (!Platform.isMacOS) {
    logError('run command is only supported on macOS');
    return 1;
  }

  /// Step 1: Build Rust library (which also creates framework)
  final libExit = await _runLib(
    args,
    runProcess: runProcess,
    log: log,
    logError: logError,
    rootDir: rootDir,
  );
  if (libExit != 0) {
    return libExit;
  }

  /// Step 2: Build Flutter app
  final build = await runProcess('flutter', ['build', 'macos', '--debug']);
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  log('[build:macos] done');

  /// Step 3: Copy dylib to app bundle's Frameworks directory
  final dylibSource = File(_runtimeDylibPath(rootDir));
  final appBundle = Directory(
    '$rootDir/build/macos/Build/Products/Debug/cardmind.app',
  );
  final frameworksDir = Directory('${appBundle.path}/Contents/Frameworks');
  final dylibDest = File('${frameworksDir.path}/libcardmind_rust.dylib');

  if (!dylibSource.existsSync()) {
    logError('Runtime dylib missing for app bundle copy: ${dylibSource.path}');
    return 1;
  }

  if (!frameworksDir.existsSync()) {
    frameworksDir.createSync(recursive: true);
  }

  if (dylibDest.existsSync()) {
    dylibDest.deleteSync();
  }

  dylibSource.copySync(dylibDest.path);
  log('[dylib] copied to app bundle from ${dylibSource.path}');

  /// Step 4: Open the app
  final openResult = await runProcess('open', [appBundle.path]);
  if (openResult.exitCode != 0) {
    logError('Failed to open app: ${openResult.stderr}');
    return openResult.exitCode;
  }
  log('[run] app launched');

  return 0;
}
