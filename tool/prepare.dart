import 'dart:convert';
import 'dart:io';

import 'platforms.dart';

export 'platforms.dart';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String cyan = '\x1B[36m';
const String bold = '\x1B[1m';

class ValidateResult {
  final bool isValid;
  final String? error;

  const ValidateResult.valid() : isValid = true, error = null;
  const ValidateResult.invalid(this.error) : isValid = false;
}

class PrepareContext {
  PrepareContext({required this.host, required Map<String, String> env})
      : env = Map<String, String>.from(env);

  final HostPlatform host;
  final Map<String, String> env;
  final Map<String, String> overrides = {};
  final Map<String, String> shellExports = {};
  final List<String> pathAdditions = [];

  void setEnv(String key, String value, {bool exportToShell = false}) {
    env[key] = value;
    overrides[key] = value;
    if (exportToShell) {
      shellExports[key] = value;
    }
  }

  void addPath(String path) {
    if (pathAdditions.contains(path)) {
      return;
    }
    pathAdditions.add(path);
    final current = env['PATH'] ?? '';
    env['PATH'] = current.isEmpty ? path : '$path:$current';
    overrides['PATH'] = env['PATH']!;
  }
}

Future<void> main(List<String> args) async {
  final host = detectHostPlatform();
  final platforms = parsePlatforms(args, host);
  if (platforms == null) {
    printError('平台参数无效: ${args.join(' ')}');
    exit(2);
  }

  final supported = resolveDefaultPlatforms(host);
  final validation = validateRequestedPlatforms(supported, platforms);
  if (!validation.isValid) {
    printError(validation.error ?? '平台参数无效');
    exit(2);
  }

  final context = PrepareContext(host: host, env: Platform.environment);

  printSection('检查项目结构');
  if (!Directory('rust').existsSync()) {
    printError('未找到 rust/ 目录');
    exit(1);
  }
  if (!File('pubspec.yaml').existsSync()) {
    printError('未找到 pubspec.yaml，请在项目根目录运行');
    exit(1);
  }

  printSection('检查基础工具');
  if (!await ensureRustup(context)) {
    exit(1);
  }
  if (!await ensureFlutter(context)) {
    exit(1);
  }
  if (!await ensureFrb(context)) {
    exit(1);
  }

  if (platforms.contains(BuildPlatform.android)) {
    printSection('准备 Android 环境');
    if (!await prepareAndroidEnvironment(context)) {
      exit(1);
    }
  }

  if (platforms.contains(BuildPlatform.ios) ||
      platforms.contains(BuildPlatform.macos)) {
    printSection('检查 Xcode');
    if (!await ensureXcode(context)) {
      exit(1);
    }
    printSection('准备 Apple Rust 目标');
    if (!await ensureAppleRustTargets(context, platforms)) {
      exit(1);
    }
  }

  if (!await writeShellEnv(context)) {
    exit(1);
  }

  await writePrepareEnv(File('tool/.prepare_env.json'), context.overrides);
  printSuccess('准备完成');
}

ValidateResult validateRequestedPlatforms(
  Set<BuildPlatform> supported,
  Set<BuildPlatform> requested,
) {
  final unsupported = requested.difference(supported);
  if (unsupported.isEmpty) {
    return const ValidateResult.valid();
  }
  return ValidateResult.invalid('当前系统不支持: ${unsupported.join(', ')}');
}

Future<bool> ensureRustup(PrepareContext context) async {
  if (!await runCommand(
    'rustup',
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    if (!await installPackage(context, 'rustup')) {
      printError('rustup 安装失败');
      return false;
    }
  }

  final home = context.env['HOME'];
  if (home == null || home.isEmpty) {
    printError('HOME 未设置，无法配置 Rust 环境');
    return false;
  }

  final cargoBin = Directory('$home/.cargo/bin');
  if (!cargoBin.existsSync() || !File('${cargoBin.path}/cargo').existsSync()) {
    if (!await runCommand(
      'rustup-init',
      ['-y'],
      env: context.env,
      description: 'Install Rust toolchain',
    )) {
      printError('Rust 工具链安装失败');
      return false;
    }
  }

  context.addPath(cargoBin.path);
  return true;
}

Future<bool> ensureFlutter(PrepareContext context) async {
  if (await runCommand(
    'flutter',
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    printSuccess('Flutter 已安装');
    return true;
  }

  printWarning('Flutter 未安装，尝试安装...');
  if (!await installPackage(context, 'flutter', isCask: true)) {
    printError('Flutter 安装失败');
    return false;
  }

  if (!await runCommand(
    'flutter',
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    printError('Flutter 安装后仍不可用');
    return false;
  }

  printSuccess('Flutter 安装成功');
  return true;
}

Future<bool> ensureFrb(PrepareContext context) async {
  final codegen = _toolExecutable('flutter_rust_bridge_codegen');
  if (await runCommand(
    codegen,
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    printSuccess('flutter_rust_bridge_codegen 已安装');
    return true;
  }

  printWarning('flutter_rust_bridge_codegen 未安装，尝试安装...');
  if (!await runCommand(
    'cargo',
    ['install', 'flutter_rust_bridge_codegen'],
    env: context.env,
    description: 'Install flutter_rust_bridge_codegen',
  )) {
    printError('flutter_rust_bridge_codegen 安装失败');
    return false;
  }

  if (!await runCommand(
    codegen,
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    printError('flutter_rust_bridge_codegen 安装后仍不可用');
    return false;
  }

  printSuccess('flutter_rust_bridge_codegen 安装成功');
  return true;
}

Future<bool> ensureCargoNdk(PrepareContext context) async {
  final cargoNdk = _toolExecutable('cargo-ndk');
  if (await runCommand(
    cargoNdk,
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    return true;
  }

  printWarning('cargo-ndk 未安装，尝试安装...');
  return runCommand(
    'cargo',
    ['install', 'cargo-ndk'],
    env: context.env,
    description: 'Install cargo-ndk',
  );
}

Future<bool> prepareAndroidEnvironment(PrepareContext context) async {
  final sdkRoot = resolveAndroidSdkRoot(context.env, context.host);
  if (sdkRoot == null) {
    printError('无法找到 Android SDK，请设置 ANDROID_SDK_ROOT');
    return false;
  }
  context.setEnv('ANDROID_SDK_ROOT', sdkRoot, exportToShell: true);
  context.setEnv('ANDROID_HOME', sdkRoot, exportToShell: true);

  if (!await ensureJava(context)) {
    return false;
  }

  Directory? ndkDir;
  final flutterSdkRoot = resolveFlutterSdkRoot(context.env);
  final requiredNdkVersion = flutterSdkRoot == null
      ? null
      : resolveFlutterNdkVersion(flutterSdkRoot);
  if (requiredNdkVersion != null && requiredNdkVersion.isNotEmpty) {
    final requiredDir = Directory('$sdkRoot/ndk/$requiredNdkVersion');
    if (!requiredDir.existsSync() ||
        !hasNdkSourceProperties(requiredDir)) {
      printWarning('未找到 Flutter 要求的 NDK $requiredNdkVersion，尝试安装...');
      final sdkmanager = findSdkManager(sdkRoot);
      if (sdkmanager == null) {
        printError('无法自动安装 NDK，请在 Android Studio 中安装');
        return false;
      }
      if (!await runCommand(
        sdkmanager,
        ['--install', 'ndk;$requiredNdkVersion'],
        env: context.env,
        description: 'Install Android NDK',
      )) {
        printError('Android NDK 安装失败');
        return false;
      }
    }
    if (!requiredDir.existsSync() ||
        !hasNdkSourceProperties(requiredDir)) {
      printError('Flutter 需要的 NDK 版本不可用: $requiredNdkVersion');
      return false;
    }
    ndkDir = requiredDir;
  } else {
    final ndkHome = context.env['ANDROID_NDK_HOME'];
    if (ndkHome != null && ndkHome.isNotEmpty) {
      final candidate = Directory(ndkHome);
      if (candidate.existsSync()) {
        if (hasNdkSourceProperties(candidate)) {
          ndkDir = candidate;
        } else {
          printWarning('ANDROID_NDK_HOME 指向的 NDK 缺少 source.properties，已忽略');
        }
      }
    }

    ndkDir ??= selectHighestNdk(Directory('$sdkRoot/ndk'));
  }
  if (ndkDir == null) {
    printWarning('未找到 Android NDK，尝试安装...');
    final sdkmanager = findSdkManager(sdkRoot);
    final latest = sdkmanager == null
        ? null
        : await resolveLatestNdkVersion(sdkmanager, context.env);
    if (sdkmanager == null || latest == null) {
      printError('无法自动安装 NDK，请在 Android Studio 中安装');
      return false;
    }
    if (!await runCommand(
      sdkmanager,
      ['--install', 'ndk;$latest'],
      env: context.env,
      description: 'Install Android NDK',
    )) {
      printError('Android NDK 安装失败');
      return false;
    }
    ndkDir = selectHighestNdk(Directory('$sdkRoot/ndk'));
  }

  if (ndkDir == null) {
    printError('无法找到有效的 Android NDK（缺少 source.properties）');
    return false;
  }

  final prebuilt = selectPrebuiltDir(ndkDir, context.host);
  if (prebuilt == null) {
    printError('无法找到 NDK 预编译工具链目录');
    return false;
  }

  context.setEnv('ANDROID_NDK_HOME', ndkDir.path, exportToShell: true);
  context.addPath('${prebuilt.path}/bin');

  context.setEnv('CC_aarch64_linux_android', 'aarch64-linux-android21-clang');
  context.setEnv(
    'CXX_aarch64_linux_android',
    'aarch64-linux-android21-clang++',
  );
  context.setEnv('AR_aarch64_linux_android', 'llvm-ar');
  context.setEnv(
    'CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER',
    'aarch64-linux-android21-clang',
  );

  context.setEnv('CC_armv7_linux_androideabi', 'armv7a-linux-androideabi21-clang');
  context.setEnv(
    'CXX_armv7_linux_androideabi',
    'armv7a-linux-androideabi21-clang++',
  );
  context.setEnv('AR_armv7_linux_androideabi', 'llvm-ar');
  context.setEnv(
    'CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER',
    'armv7a-linux-androideabi21-clang',
  );

  context.setEnv('CC_i686_linux_android', 'i686-linux-android21-clang');
  context.setEnv('CXX_i686_linux_android', 'i686-linux-android21-clang++');
  context.setEnv('AR_i686_linux_android', 'llvm-ar');
  context.setEnv(
    'CARGO_TARGET_I686_LINUX_ANDROID_LINKER',
    'i686-linux-android21-clang',
  );

  context.setEnv('CC_x86_64_linux_android', 'x86_64-linux-android21-clang');
  context.setEnv('CXX_x86_64_linux_android', 'x86_64-linux-android21-clang++');
  context.setEnv('AR_x86_64_linux_android', 'llvm-ar');
  context.setEnv(
    'CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER',
    'x86_64-linux-android21-clang',
  );

  if (!await ensureCargoNdk(context)) {
    printError('cargo-ndk 安装失败');
    return false;
  }

  final targets = [
    'aarch64-linux-android',
    'armv7-linux-androideabi',
    'x86_64-linux-android',
    'i686-linux-android',
  ];
  if (!await runCommand(
    'rustup',
    ['target', 'add', ...targets],
    env: context.env,
    description: 'Install Rust Android targets',
  )) {
    printError('Rust Android 目标安装失败');
    return false;
  }

  printSuccess('Android 环境已准备');
  return true;
}

Future<bool> ensureXcode(PrepareContext context) async {
  if (await runCommand(
    'xcodebuild',
    ['-version'],
    env: context.env,
    quiet: true,
  )) {
    printSuccess('Xcode 已安装');
    return true;
  }

  printWarning('Xcode 未安装，尝试命令行安装...');
  await runCommand('xcode-select', ['--install'], env: context.env);
  if (!await runCommand(
    'xcodebuild',
    ['-version'],
    env: context.env,
    quiet: true,
  )) {
    printError('Xcode 未安装，请在 App Store 中安装完整 Xcode');
    return false;
  }

  printSuccess('Xcode 已安装');
  return true;
}

Future<bool> ensureJava(PrepareContext context) async {
  if (await runCommand(
    'java',
    ['-version'],
    env: context.env,
    quiet: true,
  )) {
    return true;
  }

  printWarning('Java 未安装，尝试安装...');
  final package = javaPackageName(context.host);
  if (package == null) {
    printError('当前系统无法自动安装 Java');
    return false;
  }
  if (!await installPackage(context, package)) {
    printError('Java 安装失败');
    return false;
  }

  final javaHome = await resolveJavaHome(context.host);
  if (javaHome != null) {
    context.setEnv('JAVA_HOME', javaHome, exportToShell: true);
    context.addPath('$javaHome/bin');
  }

  if (!await runCommand(
    'java',
    ['-version'],
    env: context.env,
    quiet: true,
  )) {
    printError('Java 安装后仍不可用');
    return false;
  }

  return true;
}

String? javaPackageName(HostPlatform host) {
  switch (host) {
    case HostPlatform.macos:
    case HostPlatform.linux:
      return 'openjdk@17';
    case HostPlatform.windows:
      return 'openjdk17';
    case HostPlatform.other:
      return null;
  }
}

Future<String?> resolveJavaHome(HostPlatform host) async {
  switch (host) {
    case HostPlatform.macos:
      final brewResult = await Process.run(
        'brew',
        ['--prefix', 'openjdk@17'],
      );
      if (brewResult.exitCode == 0) {
        final prefix = brewResult.stdout.toString().trim();
        if (prefix.isNotEmpty) {
          final homeCandidate =
              '$prefix/libexec/openjdk.jdk/Contents/Home';
          if (Directory(homeCandidate).existsSync()) {
            return homeCandidate;
          }
          if (Directory(prefix).existsSync()) {
            return prefix;
          }
        }
      }
      final result = await Process.run('/usr/libexec/java_home', ['-v', '17']);
      if (result.exitCode != 0) {
        return null;
      }
      return parseJavaHomeOutput(result.stdout.toString());
    case HostPlatform.linux:
    case HostPlatform.windows:
    case HostPlatform.other:
      return null;
  }
}

String? parseJavaHomeOutput(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed.split('\n').first.trim();
}

Future<bool> ensureAppleRustTargets(
  PrepareContext context,
  Set<BuildPlatform> platforms,
) async {
  final targets = resolveAppleRustTargets(platforms);
  if (targets.isEmpty) {
    return true;
  }
  if (!await runCommand(
    'rustup',
    ['target', 'add', ...targets],
    env: context.env,
    description: 'Install Rust Apple targets',
  )) {
    printError('Rust Apple 目标安装失败');
    return false;
  }
  return true;
}

List<String> resolveAppleRustTargets(Set<BuildPlatform> platforms) {
  final targets = <String>[];
  if (platforms.contains(BuildPlatform.ios)) {
    targets.addAll(['aarch64-apple-ios', 'x86_64-apple-ios']);
  }
  if (platforms.contains(BuildPlatform.macos)) {
    targets.addAll(['aarch64-apple-darwin', 'x86_64-apple-darwin']);
  }
  return targets;
}

String? resolveAndroidSdkRoot(Map<String, String> env, HostPlatform host) {
  final sdkRoot = env['ANDROID_SDK_ROOT'];
  if (sdkRoot != null && sdkRoot.isNotEmpty) {
    return sdkRoot;
  }
  final androidHome = env['ANDROID_HOME'];
  if (androidHome != null && androidHome.isNotEmpty) {
    return androidHome;
  }

  final home = env['HOME'] ?? env['USERPROFILE'];
  if (home == null || home.isEmpty) {
    return null;
  }

  final candidates = <String>[];
  switch (host) {
    case HostPlatform.macos:
      candidates.addAll([
        '$home/Library/Android/sdk',
        '$home/Android/Sdk',
      ]);
      break;
    case HostPlatform.linux:
      candidates.addAll([
        '$home/Android/Sdk',
        '$home/android-sdk',
      ]);
      break;
    case HostPlatform.windows:
      final localAppData = env['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        candidates.add('$localAppData/Android/Sdk');
      }
      candidates.add('$home/AppData/Local/Android/Sdk');
      break;
    case HostPlatform.other:
      break;
  }

  for (final candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

Directory? selectHighestNdk(Directory ndkRoot) {
  if (!ndkRoot.existsSync()) {
    return null;
  }
  final dirs = ndkRoot
      .listSync()
      .whereType<Directory>()
      .where(hasNdkSourceProperties)
      .toList();
  if (dirs.isEmpty) {
    return null;
  }
  dirs.sort((a, b) {
    final aName = _basename(a.path);
    final bName = _basename(b.path);
    return _compareVersion(aName, bName);
  });
  return dirs.last;
}

bool hasNdkSourceProperties(Directory ndkDir) {
  return File('${ndkDir.path}/source.properties').existsSync();
}

Directory? selectPrebuiltDir(Directory ndkDir, HostPlatform host) {
  final base = Directory('${ndkDir.path}/toolchains/llvm/prebuilt');
  if (!base.existsSync()) {
    return null;
  }
  final candidates = <String>[];
  switch (host) {
    case HostPlatform.macos:
      candidates.addAll(['darwin-arm64', 'darwin-x86_64']);
      break;
    case HostPlatform.linux:
      candidates.add('linux-x86_64');
      break;
    case HostPlatform.windows:
      candidates.add('windows-x86_64');
      break;
    case HostPlatform.other:
      break;
  }
  for (final name in candidates) {
    final dir = Directory('${base.path}/$name');
    if (dir.existsSync()) {
      return dir;
    }
  }
  return null;
}

String? findSdkManager(String sdkRoot) {
  final candidates = [
    '$sdkRoot/cmdline-tools/latest/bin/sdkmanager',
    '$sdkRoot/cmdline-tools/bin/sdkmanager',
    '$sdkRoot/tools/bin/sdkmanager',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

String? resolveFlutterSdkRoot(
  Map<String, String> env, {
  String localPropertiesPath = 'android/local.properties',
}) {
  final flutterRoot = env['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    return flutterRoot;
  }
  final file = File(localPropertiesPath);
  if (!file.existsSync()) {
    return null;
  }
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final index = trimmed.indexOf('=');
    if (index == -1) {
      continue;
    }
    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    if (key == 'flutter.sdk' && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? resolveFlutterNdkVersion(String flutterSdkRoot) {
  final file = File(
    '$flutterSdkRoot/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
  );
  if (!file.existsSync()) {
    return null;
  }
  final content = file.readAsStringSync();
  final match = RegExp(
    r'ndkVersion:\s*String\s*=\s*"([0-9.]+)"',
  ).firstMatch(content);
  return match?.group(1);
}

Future<String?> resolveLatestNdkVersion(
  String sdkmanager,
  Map<String, String> env,
) async {
  final result = await Process.run(sdkmanager, ['--list'], environment: env);
  if (result.exitCode != 0) {
    return null;
  }

  final stdoutText = result.stdout.toString();
  final regex = RegExp(r'ndk;([0-9.]+)');
  final versions = <String>{};
  for (final match in regex.allMatches(stdoutText)) {
    versions.add(match.group(1)!);
  }
  if (versions.isEmpty) {
    return null;
  }

  final sorted = versions.toList()
    ..sort((a, b) => _compareVersion(a, b));
  return sorted.last;
}

Future<void> writePrepareEnv(File file, Map<String, String> env) async {
  await file.writeAsString(jsonEncode(env));
}

Future<Map<String, String>> readPrepareEnv(File file) async {
  final content = await file.readAsString();
  final decoded = jsonDecode(content) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value.toString()));
}

Future<bool> writeShellEnv(PrepareContext context) async {
  final home = context.env['HOME'];
  if (home == null || home.isEmpty) {
    printError('HOME 未设置，无法写入 shell 配置');
    return false;
  }

  final file = File('$home/.zshrc');
  final existing = file.existsSync() ? await file.readAsLines() : <String>[];
  final cleaned = <String>[];
  for (final line in existing) {
    final trimmed = line.trimLeft();
    if (trimmed == '# CardMind prepare') {
      continue;
    }
    final isManagedExport = context.shellExports.keys
        .any((key) => trimmed.startsWith('export $key='));
    final isManagedPath = context.pathAdditions
        .any((path) => trimmed.contains(path));
    if (isManagedExport || isManagedPath) {
      continue;
    }
    cleaned.add(line);
  }

  if (cleaned.isNotEmpty && cleaned.last.trim().isNotEmpty) {
    cleaned.add('');
  }
  cleaned.add('# CardMind prepare');

  for (final entry in context.shellExports.entries) {
    cleaned.add('export ${entry.key}="${entry.value}"');
  }
  for (final path in context.pathAdditions) {
    cleaned.add('export PATH="$path:\$PATH"');
  }

  await file.writeAsString('${cleaned.join('\n')}\n');
  return true;
}

Future<bool> installPackage(
  PrepareContext context,
  String package, {
  bool isCask = false,
}) async {
  final manager = packageManagerCommand(context.host);
  if (manager == null) {
    printError('当前系统不支持自动安装');
    return false;
  }

  if (!await runCommand(
    manager,
    ['--version'],
    env: context.env,
    quiet: true,
  )) {
    printError('未找到包管理器 $manager，请先安装');
    return false;
  }

  switch (context.host) {
    case HostPlatform.macos:
    case HostPlatform.linux:
      final args = <String>['install'];
      if (isCask && context.host == HostPlatform.macos) {
        args.add('--cask');
      }
      args.add(package);
      return runCommand(
        manager,
        args,
        env: context.env,
        description: 'Install $package',
      );
    case HostPlatform.windows:
      return runCommand(
        manager,
        ['install', package],
        env: context.env,
        description: 'Install $package',
      );
    case HostPlatform.other:
      printError('当前系统不支持自动安装');
      return false;
  }
}

String? packageManagerCommand(HostPlatform host) {
  switch (host) {
    case HostPlatform.macos:
      return 'brew';
    case HostPlatform.windows:
      return 'scoop';
    case HostPlatform.linux:
      return 'brew';
    case HostPlatform.other:
      return null;
  }
}

Future<bool> runCommand(
  String executable,
  List<String> arguments, {
  Map<String, String>? env,
  bool quiet = false,
  String? description,
}) async {
  if (!quiet && description != null) {
    printInfo('  → $description');
  }

  try {
    final process = await Process.start(
      executable,
      arguments,
      environment: env,
      runInShell: Platform.isWindows,
    );

    if (!quiet) {
      process.stdout.listen((data) => stdout.add(data));
      process.stderr.listen((data) => stderr.add(data));
    } else {
      process.stdout.drain();
      process.stderr.drain();
    }

    final exitCode = await process.exitCode;
    return exitCode == 0;
  } catch (e) {
    if (!quiet) {
      printError('命令执行失败: $executable ${arguments.join(' ')}');
      printError('错误: $e');
    }
    return false;
  }
}

String _toolExecutable(String name) {
  if (Platform.isWindows) {
    return '$name.exe';
  }
  return name;
}

String _basename(String path) {
  final parts = path.split(Platform.pathSeparator);
  return parts.isEmpty ? path : parts.last;
}

int _compareVersion(String a, String b) {
  final aParts = _parseVersionParts(a);
  final bParts = _parseVersionParts(b);
  final maxLength = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < maxLength; i++) {
    final aValue = i < aParts.length ? aParts[i] : 0;
    final bValue = i < bParts.length ? bParts[i] : 0;
    if (aValue != bValue) {
      return aValue.compareTo(bValue);
    }
  }
  return 0;
}

List<int> _parseVersionParts(String version) {
  return version
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
}

void printSection(String message) {
  stdout.writeln('\n$bold$cyan$message$reset');
}

void printInfo(String message) {
  stdout.writeln('$blue$message$reset');
}

void printSuccess(String message) {
  stdout.writeln('$green$message$reset');
}

void printWarning(String message) {
  stdout.writeln('$yellow⚠ $message$reset');
}

void printError(String message) {
  stderr.writeln('$red✗ $message$reset');
}
