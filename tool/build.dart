import 'dart:io';

import 'src/git_gate/host_build.dart';

typedef Runner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

typedef PathExists = bool Function(String path);

const _usage = 'Usage: dart run tool/build.dart <app|lib|run> [options]';
const _help = '''Usage: dart run tool/build.dart <app|lib|run> [options]

Commands:
  app    Build Flutter app
  lib    Build Rust dynamic library
  run    Build and run Flutter app (macOS only)

Options:
  -h, --help          Show this help message
  app --platform <p>  Set Flutter build platform (android|macos|linux|windows)
  app --android-format <f>  Set Android output (apk|appbundle|split-apk)
  lib --target <t>    Set Rust target triple for cargo build
  run --app-copy-name <name>  Launch an isolated macOS app bundle copy
  run --app-bundle-id <id>    Override bundle id for the isolated app copy

Default behavior:
  app runs: lib -> codegen -> flutter build
  run runs: lib -> flutter build -> copy framework -> open app
  app default platform: current host executable platform (macos/linux/windows)
  lib default mode: cargo build --release

Examples:
  dart run tool/build.dart app
  dart run tool/build.dart app --platform macos
  dart run tool/build.dart app --platform android
  dart run tool/build.dart app --platform android --android-format appbundle
  dart run tool/build.dart app --platform android --android-format split-apk
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
  PathExists pathExists = _pathExists,
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
      platformOverride: platformOverride,
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
      pathExists: pathExists,
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

const Set<String> _supportedPlatforms = {
  'android',
  'macos',
  'linux',
  'windows',
};

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
      return 'android';
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
  required PathExists pathExists,
}) async {
  late final String platform;
  late final List<String> flutterBuildArgs;
  try {
    platform = _resolvePlatform(args, platformOverride: platformOverride);
    flutterBuildArgs = platform == 'android'
        ? _resolveAndroidFlutterBuildArgs(args)
        : <String>['build', platform];
  } on FormatException catch (e) {
    logError(e.message);
    return 1;
  }

  final libExit = platform == 'android'
      ? await _runAndroidLib(
          runProcess: runProcess,
          log: log,
          logError: logError,
          rootDir: rootDir,
          pathExists: pathExists,
        )
      : await _runLib(
          args,
          runProcess: runProcess,
          log: log,
          logError: logError,
          rootDir: rootDir,
          platformOverride: platformOverride,
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

  final build = await runProcess('flutter', flutterBuildArgs);
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  log('[build:$platform] done');
  return 0;
}

Future<int> _runAndroidLib({
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  required String rootDir,
  required PathExists pathExists,
}) async {
  final outputDir = '$rootDir/build/android-jni';
  final result = await runProcess('cargo', [
    'ndk',
    '-t',
    'armeabi-v7a',
    '-t',
    'arm64-v8a',
    '-t',
    'x86_64',
    '-o',
    outputDir,
    'build',
    '--release',
    '-j',
    '2',
  ], workingDirectory: '$rootDir/rust-backend');
  if (result.exitCode != 0) {
    logError(_processError(result));
    return result.exitCode;
  }
  for (final abi in _androidAbis) {
    final libraryPath = '$outputDir/$abi/libcardmind_backend.so';
    if (!pathExists(libraryPath)) {
      logError('Android Rust library missing: $libraryPath');
      return 1;
    }
  }
  log('[lib:android] runtime libraries: $outputDir');
  return 0;
}

const List<String> _androidAbis = <String>[
  'armeabi-v7a',
  'arm64-v8a',
  'x86_64',
];

List<String> _resolveAndroidFlutterBuildArgs(List<String> args) {
  final format = _readOption(args, '--android-format');
  if (args.contains('--android-format') && format == null) {
    throw const FormatException('Missing Android output format');
  }
  return switch (format) {
    null || 'apk' => <String>['build', 'apk'],
    'appbundle' => <String>['build', 'appbundle'],
    'split-apk' => <String>['build', 'apk', '--split-per-abi'],
    _ => throw const FormatException('Unsupported Android output format'),
  };
}

bool _pathExists(String path) => File(path).existsSync();

/// 构建Rust库
///
/// 平台规格（cargo 产物名 + 运行态目标路径）来自 host_build.dart 的
/// `hostRuntimeSpec`，与 gate 的 build-lib 共用同一真相源；平台默认取当前 host，
/// 测试可通过 `platformOverride` 注入。
Future<int> _runLib(
  List<String> args, {
  required Runner runProcess,
  required void Function(String) log,
  required void Function(String) logError,
  required String rootDir,
  HostPlatform? platformOverride,
}) async {
  final target = _readOption(args, '--target');
  final cargoArgs = <String>['build', '--release'];
  if (target != null) {
    cargoArgs.addAll(['--target', target]);
  }

  final HostBuildPlatform host;
  try {
    host = _hostBuildPlatformFor(
      platformOverride ?? HostPlatformDetect.detect(),
    );
  } on FormatException catch (e) {
    logError(e.message);
    return 1;
  }

  final paths = _resolveLibPaths(rootDir, host: host, target: target);

  final result = await runProcess(
    'cargo',
    cargoArgs,
    workingDirectory: '$rootDir/rust-backend',
  );
  if (result.exitCode != 0) {
    logError(_processError(result));
    return result.exitCode;
  }

  final sourceFile = File(paths.cargoSource);
  if (!sourceFile.existsSync()) {
    logError(
      'Runtime dylib sync failed: source not found at ${paths.cargoSource}',
    );
    return 1;
  }

  final runtimeFile = File(paths.runtimeDest);
  try {
    runtimeFile.parent.createSync(recursive: true);
    if (runtimeFile.existsSync()) {
      runtimeFile.deleteSync();
    }
    sourceFile.copySync(paths.runtimeDest);
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

/// host 运行态平台映射：lib 子命令只服务 Windows/macOS/Linux host。
HostBuildPlatform _hostBuildPlatformFor(HostPlatform platform) {
  switch (platform) {
    case HostPlatform.windows:
      return HostBuildPlatform.windows;
    case HostPlatform.macos:
      return HostBuildPlatform.macos;
    case HostPlatform.linux:
      return HostBuildPlatform.linux;
    case HostPlatform.android:
    case HostPlatform.ios:
      throw const FormatException(
        'lib command supports Windows/macOS/Linux hosts only',
      );
  }
}

/// lib 子命令的路径：cargo 产物 + 运行态目标（平台规格来自 host_build.dart）。
({String cargoSource, String runtimeDest}) _resolveLibPaths(
  String rootDir, {
  required HostBuildPlatform host,
  String? target,
}) {
  if (target == null) {
    final spec = hostRuntimeSpec(host);
    return (
      cargoSource: '$rootDir/${spec.cargoSourceRel}',
      runtimeDest: '$rootDir/${spec.runtimeDestRel}',
    );
  }

  /// 带 `--target` 时 cargo 产物在 `rust-backend/target/<triple>/release/` 下，
  /// 文件名与运行态目标按 triple 识别的平台取（识别不出时回退 host 平台）。
  final spec = hostRuntimeSpec(_runtimeDestPlatformForTarget(target, host));
  return (
    cargoSource:
        '$rootDir/rust-backend/target/$target/release/'
        '${_cargoArtifactFileNameForTarget(target, host)}',
    runtimeDest: '$rootDir/${spec.runtimeDestRel}',
  );
}

/// 由 target triple 推断 cargo 产物文件名；识别不出时回退 host 平台规格。
String _cargoArtifactFileNameForTarget(String target, HostBuildPlatform host) {
  final lower = target.toLowerCase();
  if (lower.contains('windows')) {
    return _artifactFileName(HostBuildPlatform.windows);
  }
  if (lower.contains('darwin')) {
    return _artifactFileName(HostBuildPlatform.macos);
  }
  if (lower.contains('android') || lower.contains('linux')) {
    return _artifactFileName(HostBuildPlatform.linux);
  }
  return _artifactFileName(host);
}

/// 由 target triple 推断运行态目标平台；没有 host 运行态路径的目标（如 Android）
/// 回退 host 平台。
HostBuildPlatform _runtimeDestPlatformForTarget(
  String target,
  HostBuildPlatform host,
) {
  final lower = target.toLowerCase();
  if (lower.contains('windows')) return HostBuildPlatform.windows;
  if (lower.contains('darwin')) return HostBuildPlatform.macos;
  if (lower.contains('linux') && !lower.contains('android')) {
    return HostBuildPlatform.linux;
  }
  return host;
}

/// cargo 产物文件名取自 host_build.dart 的平台规格（一个真相源）。
String _artifactFileName(HostBuildPlatform platform) =>
    hostRuntimeSpec(platform).cargoSourceRel.split('/').last;

/// `run` 子命令（仅 macOS）使用的运行态库路径。
String _macosRuntimeDylibPath(String rootDir) =>
    '$rootDir/${hostRuntimeSpec(HostBuildPlatform.macos).runtimeDestRel}';

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
///
/// Windows 上 flutter 无扩展名可执行文件是 bash 脚本（仅 MSYS 可解析），
/// Windows CreateProcess 无法直接启动；必须使用 flutter.bat。
/// dart/cargo/flutter_rust_bridge_codegen 在 Windows 上均有真实 .exe，无需处理。
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  final effectiveExecutable = Platform.isWindows && executable == 'flutter'
      ? 'flutter.bat'
      : executable;
  return Process.run(
    effectiveExecutable,
    arguments,
    workingDirectory: workingDirectory,
  );
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
  final appCopyName = _readOption(args, '--app-copy-name');
  final appBundleId = _readOption(args, '--app-bundle-id');
  if (!Platform.isMacOS) {
    logError('run command is only supported on macOS');
    return 1;
  }
  if (appBundleId != null && (appCopyName == null || appCopyName.isEmpty)) {
    logError('--app-bundle-id requires --app-copy-name');
    return 1;
  }
  final appCopyNameError = _validateAppCopyName(appCopyName);
  if (appCopyNameError != null) {
    logError(appCopyNameError);
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
  final dartDefines = _readMultiOption(args, '--dart-define');
  final buildArgs = <String>['build', 'macos', '--debug'];
  for (final dartDefine in dartDefines) {
    buildArgs.add('--dart-define=$dartDefine');
  }
  final build = await runProcess('flutter', buildArgs);
  if (build.exitCode != 0) {
    logError(_processError(build));
    return build.exitCode;
  }
  log('[build:macos] done');

  /// Step 3: Copy dylib to app bundle's Frameworks directory
  final dylibSource = File(_macosRuntimeDylibPath(rootDir));
  final baseAppBundle = Directory(
    '$rootDir/build/macos/Build/Products/Debug/cardmind.app',
  );
  final appBundle = _resolveLaunchAppBundle(
    baseAppBundle: baseAppBundle,
    appCopyName: appCopyName,
  );
  if (appCopyName != null && appCopyName.isNotEmpty) {
    if (!baseAppBundle.existsSync()) {
      logError('Base app bundle missing: ${baseAppBundle.path}');
      return 1;
    }
    _replaceDirectory(appBundle, baseAppBundle);
    if (appBundleId != null && appBundleId.isNotEmpty) {
      final plistExit = await _rewriteAppBundleIdentifier(
        appBundle,
        appBundleId,
        runProcess: runProcess,
        logError: logError,
      );
      if (plistExit != 0) {
        return plistExit;
      }
      log('[app] isolated bundle prepared: $appCopyName ($appBundleId)');
    } else {
      log('[app] isolated bundle prepared: $appCopyName');
    }
  }
  final frameworksDir = Directory('${appBundle.path}/Contents/Frameworks');
  final dylibDest = File('${frameworksDir.path}/libcardmind_backend.dylib');

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

  final installName = await runProcess('install_name_tool', <String>[
    '-id',
    '@rpath/libcardmind_backend.dylib',
    dylibDest.path,
  ]);
  if (installName.exitCode != 0) {
    logError('Failed to set Rust dylib install name: ${installName.stderr}');
    return installName.exitCode;
  }

  if (appCopyName != null && appCopyName.isNotEmpty) {
    final codesignResult = await runProcess('codesign', <String>[
      '--force',
      '--deep',
      '--sign',
      '-',
      appBundle.path,
    ]);
    if (codesignResult.exitCode != 0) {
      logError('Failed to codesign isolated app: ${codesignResult.stderr}');
      return codesignResult.exitCode;
    }
    log('[app] isolated bundle re-signed');
  }

  /// Step 4: Open the app
  final openArgs = appCopyName == null || appCopyName.isEmpty
      ? <String>[appBundle.path]
      : <String>['-n', appBundle.path];
  final openResult = await runProcess('open', openArgs);
  if (openResult.exitCode != 0) {
    logError('Failed to open app: ${openResult.stderr}');
    return openResult.exitCode;
  }
  log('[run] app launched');

  return 0;
}

List<String> _readMultiOption(List<String> args, String name) {
  final values = <String>[];
  for (var i = 0; i < args.length; i += 1) {
    if (args[i] != name) {
      continue;
    }
    if (i + 1 >= args.length) {
      continue;
    }
    values.add(args[i + 1]);
    i += 1;
  }
  return values;
}

Directory _resolveLaunchAppBundle({
  required Directory baseAppBundle,
  required String? appCopyName,
}) {
  final copyName = appCopyName?.trim();
  if (copyName == null || copyName.isEmpty) {
    return baseAppBundle;
  }
  return Directory('${Directory(baseAppBundle.parent.path).path}/$copyName');
}

void _replaceDirectory(Directory destination, Directory source) {
  if (destination.existsSync()) {
    destination.deleteSync(recursive: true);
  }
  destination.createSync(recursive: true);
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    final relativePath = entity.path.substring(source.path.length + 1);
    final targetPath = '${destination.path}/$relativePath';
    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
      continue;
    }
    if (entity is File) {
      File(targetPath).parent.createSync(recursive: true);
      entity.copySync(targetPath);
      continue;
    }
    if (entity is Link) {
      Link(targetPath).parent.createSync(recursive: true);
      Link(targetPath).createSync(entity.targetSync(), recursive: true);
    }
  }
}

Future<int> _rewriteAppBundleIdentifier(
  Directory appBundle,
  String bundleId, {
  required Runner runProcess,
  required void Function(String) logError,
}) async {
  final infoPlist = File('${appBundle.path}/Contents/Info.plist');
  if (!infoPlist.existsSync()) {
    logError('App Info.plist not found at ${infoPlist.path}');
    return 1;
  }
  final result = await runProcess('plutil', <String>[
    '-replace',
    'CFBundleIdentifier',
    '-string',
    bundleId,
    infoPlist.path,
  ]);
  if (result.exitCode != 0) {
    logError('Failed to rewrite isolated app bundle id: ${result.stderr}');
    return result.exitCode;
  }
  return 0;
}

String? _validateAppCopyName(String? appCopyName) {
  final copyName = appCopyName?.trim();
  if (copyName == null || copyName.isEmpty) {
    return null;
  }
  if (!copyName.endsWith('.app')) {
    return 'invalid --app-copy-name: must end with .app';
  }
  if (copyName.contains('/') ||
      copyName.contains(r'\') ||
      copyName.contains('..')) {
    return 'invalid --app-copy-name: must be a single app bundle name';
  }
  if (copyName == '.' || copyName == '..') {
    return 'invalid --app-copy-name: must be a single app bundle name';
  }
  return null;
}
