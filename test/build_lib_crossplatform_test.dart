import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build.dart' as build;

/// 验收标准 3：`dart run tool/build.dart lib` 的平台规格（源码级守卫）。
///
/// 本机（Windows）跑不到真 macOS/Linux，因此平台由 `runBuildCli(platformOverride:)`
/// 注入：测试在临时仓库根里按各平台规格预置 cargo 产物，再断言运行态目标路径被真实写出。
/// 断言的是"规格"本身（cargo 产物名 + 运行态目标路径），不依赖当前 host。
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('build_lib_spec_');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // 清理失败不影响断言结果
    }
  });

  /// 临时仓库根（正斜杠形式，与 tool/build.dart 的路径拼接一致）。
  String repoRoot() => root.path.replaceAll(r'\', '/');

  /// 在临时仓库根下按相对路径写入 cargo 产物，返回写入内容。
  String placeCargoArtifact(String relativePath, String content) {
    final file = File('${repoRoot()}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return content;
  }

  test('3 macOS 规格：target/release/libcardmind_backend.dylib → '
      'build/native/macos/libcardmind_backend.dylib', () async {
    const content = 'macos-dylib-content';
    placeCargoArtifact(
      'rust-backend/target/release/libcardmind_backend.dylib',
      content,
    );

    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.macos,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(exit, 0, reason: 'macOS 规格必须能找到 cargo 产物并同步（errors=$errors）');
    expect(calls.single.arguments, <String>['build', '--release']);
    expect(calls.single.workingDirectory, '${repoRoot()}/rust-backend');

    final runtime = File(
      '${repoRoot()}/build/native/macos/libcardmind_backend.dylib',
    );
    expect(runtime.existsSync(), isTrue, reason: 'macOS 运行态目标路径必须被写出');
    expect(runtime.readAsStringSync(), content);
  });

  test('3 Windows 规格：target/release/cardmind_backend.dll → '
      'build/windows/x64/runner/Release/cardmind_backend.dll', () async {
    const content = 'windows-dll-content';
    placeCargoArtifact(
      'rust-backend/target/release/cardmind_backend.dll',
      content,
    );

    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.windows,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(exit, 0, reason: 'Windows 规格必须能找到 cargo 产物并同步（errors=$errors）');
    expect(calls.single.arguments, <String>['build', '--release']);

    final runtime = File(
      '${repoRoot()}/build/windows/x64/runner/Release/cardmind_backend.dll',
    );
    expect(runtime.existsSync(), isTrue, reason: 'Windows 运行态目标路径必须被写出');
    expect(runtime.readAsStringSync(), content);
  });

  test('3 Linux 规格：target/release/libcardmind_backend.so → '
      'build/linux/x64/release/bundle/lib/libcardmind_backend.so', () async {
    const content = 'linux-so-content';
    placeCargoArtifact(
      'rust-backend/target/release/libcardmind_backend.so',
      content,
    );

    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.linux,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(exit, 0, reason: 'Linux 规格必须能找到 cargo 产物并同步（errors=$errors）');
    expect(calls.single.arguments, <String>['build', '--release']);

    final runtime = File(
      '${repoRoot()}/build/linux/x64/release/bundle/lib/libcardmind_backend.so',
    );
    expect(runtime.existsSync(), isTrue, reason: 'Linux 运行态目标路径必须被写出');
    expect(runtime.readAsStringSync(), content);
  });

  test('3 --target aarch64-apple-darwin 时 cargo 产物仍在 '
      'rust-backend/target/<triple>/release/ 下', () async {
    const content = 'macos-arm64-dylib-content';
    placeCargoArtifact(
      'rust-backend/target/aarch64-apple-darwin/release/'
      'libcardmind_backend.dylib',
      content,
    );

    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib', '--target', 'aarch64-apple-darwin'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.macos,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(
      exit,
      0,
      reason:
          '--target 时 cargo 产物必须在 target/<triple>/release/ 下被找到'
          '（errors=$errors）',
    );
    expect(calls.single.arguments, <String>[
      'build',
      '--release',
      '--target',
      'aarch64-apple-darwin',
    ]);

    final runtime = File(
      '${repoRoot()}/build/native/macos/libcardmind_backend.dylib',
    );
    expect(runtime.existsSync(), isTrue);
    expect(runtime.readAsStringSync(), content);
  });

  test('4 缺库（默认路径）：非零退出，且错误信息含缺失产物的绝对路径', () async {
    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.windows,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(exit, isNot(0), reason: 'cargo 产物缺失必须非零退出');
    expect(calls.single.arguments, <String>['build', '--release']);
    expect(
      errors.join('\n'),
      contains(
        '${repoRoot()}/rust-backend/target/release/cardmind_backend.dll',
      ),
      reason: '错误信息必须含缺失文件的绝对路径（临时仓库根是绝对路径）',
    );
  });

  test('4 缺库（--target）：非零退出，且错误信息含 triple 目录下的绝对路径', () async {
    final calls = <_CargoCall>[];
    final errors = <String>[];

    final exit = await build.runBuildCli(
      ['lib', '--target', 'x86_64-unknown-linux-gnu'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.windows,
      runProcess: _recordingRunner(calls),
      log: (_) {},
      logError: errors.add,
    );

    expect(exit, isNot(0), reason: 'cargo 产物缺失必须非零退出');
    expect(
      errors.join('\n'),
      contains(
        '${repoRoot()}/rust-backend/target/x86_64-unknown-linux-gnu/release/'
        'libcardmind_backend.so',
      ),
      reason: '错误信息必须含 triple 目录下缺失文件的绝对路径',
    );
  });

  test('1 同步后的运行态库时间戳被刷新（不早于本次同步）', () async {
    final source = File(
      '${repoRoot()}/rust-backend/target/release/cardmind_backend.dll',
    );
    source.parent.createSync(recursive: true);
    source.writeAsStringSync('stale-mtime-content');
    source.setLastModifiedSync(DateTime(2001));

    final exit = await build.runBuildCli(
      ['lib'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.windows,
      runProcess: _recordingRunner(<_CargoCall>[]),
      log: (_) {},
      logError: (_) {},
    );

    expect(exit, 0);
    final runtime = File(
      '${repoRoot()}/build/windows/x64/runner/Release/cardmind_backend.dll',
    );
    expect(runtime.existsSync(), isTrue);
    expect(
      runtime.lastModifiedSync().isAfter(source.lastModifiedSync()),
      isTrue,
      reason: '运行态库 mtime 必须反映本次同步，而不是 cargo 产物的 mtime',
    );
    expect(
      DateTime.now().difference(runtime.lastModifiedSync()) <
          const Duration(minutes: 1),
      isTrue,
      reason: '运行态库 mtime 必须落在本次同步时间附近',
    );
  });

  test('3 --target 指向其它平台时，运行态目标跟随 triple 推断的平台', () async {
    const content = 'linux-so-cross-content';
    placeCargoArtifact(
      'rust-backend/target/x86_64-unknown-linux-gnu/release/'
      'libcardmind_backend.so',
      content,
    );

    final exit = await build.runBuildCli(
      ['lib', '--target', 'x86_64-unknown-linux-gnu'],
      currentDirectory: repoRoot(),
      platformOverride: build.HostPlatform.windows,
      runProcess: _recordingRunner(<_CargoCall>[]),
      log: (_) {},
      logError: (_) {},
    );

    expect(exit, 0);
    final runtime = File(
      '${repoRoot()}/build/linux/x64/release/bundle/lib/libcardmind_backend.so',
    );
    expect(
      runtime.existsSync(),
      isTrue,
      reason: '跨平台 --target 的运行态目标取 triple 推断平台的路径，文件名与产物一致',
    );
    expect(runtime.readAsStringSync(), content);
  });
}

Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
})
_recordingRunner(List<_CargoCall> calls) {
  return (executable, arguments, {workingDirectory}) async {
    calls.add(_CargoCall(executable, arguments, workingDirectory));
    return ProcessResult(1, 0, '', '');
  };
}

class _CargoCall {
  const _CargoCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}
