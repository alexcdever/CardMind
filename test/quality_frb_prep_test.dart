import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/quality.dart' as quality;

/// 验收标准 5：`dart run tool/quality.dart flutter` 的 FRB 准备步骤在 Windows 上
/// 不再走 `dart tool/build.dart lib` 子进程——那条路径硬编码 macOS dylib，Windows 必失败。
///
/// 本测试断言"准备步骤的命令形状"：先 `cargo build --release`（在 `rust-backend/` 下）
/// 再用 `flutter_rust_bridge_codegen generate`，且不含 `dart tool/build.dart` 子进程。
/// 运行态库被真实同步、FRB 准备不中止（退出 0）由真实入口
/// （`dart run tool/quality.dart flutter`）自检覆盖。
void main() {
  test('5 FRB 准备改用进程内跨平台同步：cargo build --release + codegen，'
      '不再有 tool/build.dart 子进程', () async {
    final calls = <_ProcessCall>[];
    final logs = <String>[];
    final errors = <String>[];

    await quality.runQualityCli(
      ['flutter'],
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add(_ProcessCall(executable, arguments, workingDirectory));
        return ProcessResult(1, 0, '', '');
      },
      log: logs.add,
      logError: errors.add,
    );

    final buildDartCalls = calls
        .where(
          (c) =>
              c.executable == 'dart' && c.arguments.contains('tool/build.dart'),
        )
        .toList();
    expect(
      buildDartCalls,
      isEmpty,
      reason: 'Windows 上 `dart tool/build.dart lib` 必失败，FRB 准备不得再调用它',
    );

    final cargoBuilds = calls.where((c) => c.executable == 'cargo').toList();
    expect(
      cargoBuilds,
      hasLength(1),
      reason:
          'FRB 准备必须先真实构建 host 动态库（实际调用：${calls.map((c) => c.command).toList()}）',
    );
    expect(cargoBuilds.single.arguments, <String>['build', '--release']);
    expect(cargoBuilds.single.workingDirectory, endsWith('rust-backend'));

    expect(
      calls.where((c) => c.executable == 'flutter_rust_bridge_codegen'),
      hasLength(1),
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
