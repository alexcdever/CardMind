/// 门禁命令模型：一条可执行的外部检查/测试命令。
///
/// 纯 Dart，无外部依赖；路径统一使用 POSIX 风格相对路径。
library;

/// 命令类别（同时决定执行优先级，数值越小越先执行）。
enum CommandKind {
  formatDart(0),
  formatRust(1),
  docsLint(10),
  clippy(20),
  rustTest(30),
  buildLib(40),
  codegen(50),
  analyze(60),
  flutterTest(70);

  const CommandKind(this.priority);

  final int priority;
}

/// 一条门禁命令。
class GateCommand {
  const GateCommand({
    required this.executable,
    required this.arguments,
    required this.kind,
    required this.label,
    this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;

  /// 工作目录（相对仓库根，POSIX 风格）；null 表示仓库根。
  final String? workingDirectory;
  final CommandKind kind;
  final String label;

  /// 去重签名。
  String get signature =>
      '$executable|${arguments.join(' ')}|${workingDirectory ?? ''}';

  @override
  String toString() =>
      '$label: $executable ${arguments.join(' ')}'
      '${workingDirectory == null ? '' : ' (in $workingDirectory)'}';
}

/// 标准命令工厂。
abstract final class Commands {
  static GateCommand formatDart() => const GateCommand(
    executable: 'dart',
    arguments: <String>['format', 'lib', 'test', 'integration_test', 'tool'],
    kind: CommandKind.formatDart,
    label: 'format:dart',
  );

  static GateCommand formatRust() => const GateCommand(
    executable: 'cargo',
    arguments: <String>['fmt', '--all'],
    kind: CommandKind.formatRust,
    label: 'format:rust',
    workingDirectory: 'rust-backend',
  );

  static GateCommand docsLint() => const GateCommand(
    executable: 'dart',
    arguments: <String>['tool/lint/markdown_references_linter.dart'],
    kind: CommandKind.docsLint,
    label: 'docs:lint',
  );

  static GateCommand clippy() => const GateCommand(
    executable: 'cargo',
    arguments: <String>[
      'clippy',
      '--all-targets',
      '--all-features',
      '--',
      '-D',
      'warnings',
    ],
    kind: CommandKind.clippy,
    label: 'rust:clippy',
    workingDirectory: 'rust-backend',
  );

  static GateCommand rustTestTarget(String target) => GateCommand(
    executable: 'cargo',
    arguments: <String>['test', '--test', target],
    kind: CommandKind.rustTest,
    label: 'rust:test:$target',
    workingDirectory: 'rust-backend',
  );

  /// Rust 全量 host 测试。
  static GateCommand rustFullTest() => const GateCommand(
    executable: 'cargo',
    arguments: <String>['test', '--all-features', '--jobs', '1'],
    kind: CommandKind.rustTest,
    label: 'rust:test:full',
    workingDirectory: 'rust-backend',
  );

  /// 跨平台 host runtime build：cargo build --release（编译 host 动态库）。
  /// 产物同步到运行态路径由 host_build.dart 的 syncHostRuntimeLibrary 完成，
  /// 不再调用 tool/build.dart（其硬编码 macOS dylib 路径，Windows 必失败）。
  static GateCommand hostBuildLib() => const GateCommand(
    executable: 'cargo',
    arguments: <String>['build', '--release'],
    kind: CommandKind.buildLib,
    label: 'rust:build-lib',
    workingDirectory: 'rust-backend',
  );

  static GateCommand codegen() => const GateCommand(
    executable: 'flutter_rust_bridge_codegen',
    arguments: <String>['generate'],
    kind: CommandKind.codegen,
    label: 'frb:codegen',
  );

  static GateCommand analyze() => const GateCommand(
    executable: 'flutter',
    arguments: <String>['analyze'],
    kind: CommandKind.analyze,
    label: 'flutter:analyze',
  );

  /// flutter test；[files] 为空时表示全量测试。
  static GateCommand flutterTest(List<String> files) => GateCommand(
    executable: 'flutter',
    arguments: <String>['test', '--timeout', '3m', ...files],
    kind: CommandKind.flutterTest,
    label: files.isEmpty ? 'flutter:test:full' : 'flutter:test',
  );

  static GateCommand flutterFullTest() => flutterTest(const <String>[]);
}
