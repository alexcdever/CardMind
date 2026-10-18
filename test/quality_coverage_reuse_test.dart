// Tests for fix-coverage-pipeline AC1/AC2/AC3:
//  - AC1: `dart run tool/test_boundary_scanner.dart --scope=flutter --reuse-coverage`
//    在 coverage/lcov.info 已存在时不再执行 `flutter test`（复用既有覆盖率）。
//  - AC2: `dart run tool/quality.dart flutter` 传给扫描器的参数含复用开关，
//    且整条链里 `flutter test` 子进程只出现 1 次。
//  - AC3: 带开关时扫描结果边界数与不带开关时一致（行为等价，靠共享代码路径 +
//    本文件的边界计数断言保障）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/quality.dart' as quality;
import '../tool/src/git_gate/host_build.dart';
import '../tool/test_boundary_scanner.dart';

ScannerConfig _config() => ScannerConfig(
  includePaths: const ['lib/', 'rust-backend/src/'],
  excludePaths: const [
    'lib/bridge_generated/',
    'test/',
    'rust-backend/tests/',
    'rust-backend/src/frb_generated.rs',
  ],
  weights: const {
    BoundaryType.condition: 1.0,
    BoundaryType.null_: 1.0,
    BoundaryType.exception: 1.0,
    BoundaryType.input: 1.0,
    BoundaryType.async: 0.7,
    BoundaryType.collection: 0.7,
    BoundaryType.lifecycle: 0.7,
    BoundaryType.interaction: 1.0,
  },
  ignorePatterns: const [
    'test/',
    r'frb_generated.rs$',
    r'.g.dart$',
    r'.freezed.dart$',
  ],
);

class _CoverageCall {
  const _CoverageCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  String get command => '$executable ${arguments.join(' ')}';
}

void main() {
  group('AC1 — --reuse-coverage 复用已有覆盖率', () {
    test('reuseCoverage: true 时 flutter test 调用次数 = 0', () async {
      final coverageCalls = <_CoverageCall>[];
      // scan() 需要 coverage/lcov.info 存在才不告警；工作目录下没有也在
      // 容忍范围内（仅 warning），覆盖率采集计数才是本断言对象。
      final scanner = TestBoundaryScanner(
        _config(),
        coverageRunner: (executable, arguments) async {
          coverageCalls.add(_CoverageCall(executable, arguments));
          return ProcessResult(1, 0, '', '');
        },
      );

      await scanner.scan(scope: ScanScope.flutter, reuseCoverage: true);

      expect(
        coverageCalls
            .where(
              (c) => c.executable == 'flutter' && c.arguments.contains('test'),
            )
            .length,
        0,
        reason:
            'reuseCoverage 开启后扫描器不得再跑 flutter test --coverage'
            '（实际调用：${coverageCalls.map((c) => c.command).toList()}）',
      );
    });

    test('对照腿：reuseCoverage 缺省（false）时 flutter test 调用次数 = 1', () async {
      final coverageCalls = <_CoverageCall>[];
      final scanner = TestBoundaryScanner(
        _config(),
        coverageRunner: (executable, arguments) async {
          coverageCalls.add(_CoverageCall(executable, arguments));
          return ProcessResult(1, 0, '', '');
        },
      );

      await scanner.scan(scope: ScanScope.flutter);

      expect(
        coverageCalls
            .where(
              (c) => c.executable == 'flutter' && c.arguments.contains('test'),
            )
            .length,
        1,
        reason: '不带复用开关时扫描器必须照旧跑一遍 flutter test --coverage',
      );
    });

    test('reuseCoverage 不改变扫描边界总数（AC3 行为等价）', () async {
      int collectCount = 0;
      final scanner = TestBoundaryScanner(
        _config(),
        coverageRunner: (executable, arguments) async {
          collectCount++;
          return ProcessResult(1, 0, '', '');
        },
      );

      final reused = await scanner.scan(
        scope: ScanScope.flutter,
        reuseCoverage: true,
      );
      final fresh = await scanner.scan(scope: ScanScope.flutter);

      expect(collectCount, 1, reason: '只有第二次（不带开关）扫描应采集覆盖率');
      expect(
        reused.boundaries.length,
        fresh.boundaries.length,
        reason: 'reuseCoverage 不得改变扫描出的边界总数',
      );
    });
  });

  group('AC2 — quality.dart flutter 链使用复用开关', () {
    late Directory repoRoot;

    setUp(() {
      repoRoot = Directory.systemTemp.createTempSync('quality_coverage_reuse_');
      final spec = hostRuntimeSpec(detectHostPlatform());
      final artifact = File('${repoRoot.path}/${spec.cargoSourceRel}');
      artifact.parent.createSync(recursive: true);
      artifact.writeAsStringSync('fake cargo artifact');
    });

    tearDown(() {
      try {
        repoRoot.deleteSync(recursive: true);
      } on FileSystemException {
        // 清理失败不影响断言结果
      }
    });

    test('传给 test_boundary_scanner 的参数含 --reuse-coverage，'
        '且 flutter test 子进程全链只出现 1 次', () async {
      final calls = <_CoverageCall>[];

      final exit = await quality.runQualityCli(
        ['flutter'],
        repoRoot: repoRoot.path,
        runProcess: (executable, arguments, {workingDirectory}) async {
          calls.add(_CoverageCall(executable, arguments));
          return ProcessResult(1, 0, '', '');
        },
        log: (_) {},
        logError: (_) {},
      );

      expect(exit, 0);

      final scannerCalls = calls
          .where(
            (c) =>
                c.executable == 'dart' &&
                c.arguments.contains('tool/test_boundary_scanner.dart'),
          )
          .toList();
      expect(
        scannerCalls,
        hasLength(1),
        reason:
            'flutter 链必须恰好调用一次边界扫描器'
            '（实际调用：${calls.map((c) => c.command).toList()}）',
      );
      expect(
        scannerCalls.single.arguments,
        contains('--reuse-coverage'),
        reason: '扫描器调用必须带复用开关，否则它内部会再跑一遍 flutter test --coverage',
      );

      // 核心可观测计数：整条链里 `flutter test` 只出现 1 次。
      expect(
        calls
            .where(
              (c) => c.executable == 'flutter' && c.arguments.contains('test'),
            )
            .length,
        1,
        reason:
            'quality.dart 自己跑一遍 flutter test --coverage 后，'
            '扫描器侧不得再触发第二遍',
      );
    });
  });
}
