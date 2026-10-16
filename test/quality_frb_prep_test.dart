import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/quality.dart' as quality;
import '../tool/src/git_gate/host_build.dart';
import '../tool/src/git_gate/runner.dart';

/// 验收标准 5：`dart run tool/quality.dart flutter` 的 FRB 准备步骤在 Windows 上
/// 不再走 `dart tool/build.dart lib` 子进程——那条路径硬编码 macOS dylib，Windows 必失败。
///
/// 断言命令形状（`cargo build --release` 在 `rust-backend/` 下 + FRB codegen，且没有
/// `dart tool/build.dart` 子进程）、FRB 准备退出 0，以及 cargo 产物被**真实**同步到运行态
/// 路径。注入临时仓库根：测试不碰共享的运行态库（并发跑其它 suite 时它们可能正加载它）。
void main() {
  late Directory repoRoot;
  late HostRuntimeSpec spec;
  late String artifactContent;

  setUp(() {
    repoRoot = Directory.systemTemp.createTempSync('quality_frb_prep_');
    spec = hostRuntimeSpec(detectHostPlatform());
    artifactContent = 'fake ${spec.cargoSourceRel} content';
    final artifact = File('${repoRoot.path}/${spec.cargoSourceRel}');
    artifact.parent.createSync(recursive: true);
    artifact.writeAsStringSync(artifactContent);
  });

  tearDown(() {
    try {
      repoRoot.deleteSync(recursive: true);
    } on FileSystemException {
      // 清理失败不影响断言结果
    }
  });

  test('5 FRB 准备改用进程内跨平台同步：cargo build --release + codegen，'
      '不再有 tool/build.dart 子进程', () async {
    final calls = <_ProcessCall>[];
    final logs = <String>[];
    final errors = <String>[];

    final exit = await quality.runQualityCli(
      ['flutter'],
      repoRoot: repoRoot.path,
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add(_ProcessCall(executable, arguments, workingDirectory));
        return ProcessResult(1, 0, '', '');
      },
      log: logs.add,
      logError: errors.add,
    );

    expect(
      calls.where(
        (c) =>
            c.executable == 'dart' && c.arguments.contains('tool/build.dart'),
      ),
      isEmpty,
      reason: 'Windows 上 `dart tool/build.dart lib` 必失败，FRB 准备不得再调用它',
    );

    final cargoBuilds = calls.where((c) => c.executable == 'cargo').toList();
    expect(
      cargoBuilds,
      hasLength(1),
      reason:
          'FRB 准备必须先真实构建 host 动态库（实际调用：'
          '${calls.map((c) => c.command).toList()}）',
    );
    expect(cargoBuilds.single.arguments, <String>['build', '--release']);
    expect(
      cargoBuilds.single.workingDirectory?.replaceAll(r'\', '/'),
      '${repoRoot.path.replaceAll(r'\', '/')}/rust-backend',
    );
    expect(
      calls.where((c) => c.executable == 'flutter_rust_bridge_codegen'),
      hasLength(1),
    );

    expect(exit, 0, reason: 'FRB 准备不得中止（errors=$errors）');
    expect(errors, isEmpty, reason: 'FRB 准备不得报错（含 Runtime dylib sync failed）');

    final runtime = File('${repoRoot.path}/${spec.runtimeDestRel}');
    expect(
      runtime.existsSync(),
      isTrue,
      reason: '运行态库必须被真实同步到 ${spec.runtimeDestRel}',
    );
    expect(
      runtime.readAsStringSync(),
      artifactContent,
      reason: '同步的必须是 cargo 产物内容',
    );
  });

  test('Windows 上 flutter 命令必须解析为 flutter.bat（否则 CreateProcess 找不到文件）', () {
    expect(
      resolveExecutable('flutter', isWindows: true),
      'flutter.bat',
      reason: 'Windows 上无扩展名的 flutter 是 bash 脚本，必须走 flutter.bat',
    );
    expect(resolveExecutable('flutter', isWindows: false), 'flutter');
    expect(
      resolveExecutable('cargo', isWindows: true),
      'cargo',
      reason: 'cargo/dart/flutter_rust_bridge_codegen 在 Windows 上是真实 .exe',
    );
  });
}

class _ProcessCall {
  const _ProcessCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  String get command => '$executable ${arguments.join(' ')}';
}
