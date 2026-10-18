// Tests for fix-coverage-data-absence AC1/AC2/AC3:
//  - AC1: rust-backend/lcov.info 缺失时报告 Rust 小节显式标注「无覆盖率数据」，
//         不得以事实口吻写 0 (0.0%)；对照腿：有数据时无标记且正常给覆盖率数字。
//  - AC2: coverage/lcov.info 缺失时 Flutter/Dart 小节同样标注；对照腿同上。
//  - AC3/兼容性: ScanResult 默认构造（不传缺失标记）行为与旧版一致，
//         报告不出现「无覆盖率数据」字样。
import 'package:flutter_test/flutter_test.dart';

import '../tool/test_boundary_scanner.dart';

ScannerConfig _config() => ScannerConfig(
  includePaths: const ['lib/', 'rust-backend/src/'],
  excludePaths: const [],
  weights: const {BoundaryType.condition: 1.0},
  ignorePatterns: const [],
);

Boundary _dart({bool covered = false}) => Boundary(
  type: BoundaryType.condition,
  filePath: 'lib/pages/editor_page.dart',
  lineNumber: 10,
  codeSnippet: 'if (x)',
  isCovered: covered,
);

Boundary _rust({bool covered = false}) => Boundary(
  type: BoundaryType.condition,
  filePath: 'rust-backend/src/store.rs',
  lineNumber: 20,
  codeSnippet: 'if x {',
  isCovered: covered,
);

/// 截取报告中某个 `## xxx` 小节到下一个 `## ` 之前的正文。
String _section(String report, String heading) {
  final start = report.indexOf(heading);
  expect(start, isNonNegative, reason: '报告应包含小节 $heading');
  final rest = report.substring(start + heading.length);
  final next = rest.indexOf('\n## ');
  return next == -1 ? rest : rest.substring(0, next);
}

ScanResult _result(
  List<Boundary> boundaries, {
  bool flutterMissing = false,
  bool rustMissing = false,
}) => ScanResult(
  boundaries: boundaries,
  coveredBoundaries: boundaries.where((b) => b.isCovered).toList(),
  uncoveredBoundaries: boundaries.where((b) => !b.isCovered).toList(),
  flutterCoverageDataMissing: flutterMissing,
  rustCoverageDataMissing: rustMissing,
);

void main() {
  group('AC1 — Rust 覆盖率缺失显式标注', () {
    test('rust lcov 缺失：Rust 小节含「无覆盖率数据」且无 0 (0.0%)', () {
      // 模拟 scan() 在 rust-backend/lcov.info 不存在时的产物：
      // Rust 边界全部 isCovered=false（无数据可判），并携带缺失标记。
      final report = ReportGenerator(
        _config(),
      ).generate(_result([_rust()], rustMissing: true));

      final rustSection = _section(report, '## Rust 统计');
      expect(
        rustSection,
        contains('无覆盖率数据'),
        reason: '缺数据必须显式标注，不得伪装成 0% 覆盖',
      );
      expect(
        rustSection,
        isNot(contains('0 (0.0%)')),
        reason: '「已覆盖: 0 (0.0%)」会被误读为真实的 0% 覆盖',
      );
    });

    test('对照腿：rust lcov 存在且有命中，Rust 小节无缺失标记、正常给数字', () {
      final report = ReportGenerator(
        _config(),
      ).generate(_result([_rust(covered: true)]));

      final rustSection = _section(report, '## Rust 统计');
      expect(rustSection, isNot(contains('无覆盖率数据')));
      expect(rustSection, contains('已覆盖: 1'));
      expect(rustSection, contains('100.0%'));
    });
  });

  group('AC2 — Flutter 覆盖率缺失显式标注', () {
    test('flutter lcov 缺失：Flutter/Dart 小节含「无覆盖率数据」且无 0 (0.0%)', () {
      final report = ReportGenerator(
        _config(),
      ).generate(_result([_dart()], flutterMissing: true));

      final dartSection = _section(report, '## Flutter/Dart 统计');
      expect(dartSection, contains('无覆盖率数据'));
      expect(dartSection, isNot(contains('0 (0.0%)')));
    });

    test('对照腿：flutter lcov 存在且有命中，Flutter 小节无缺失标记', () {
      final report = ReportGenerator(
        _config(),
      ).generate(_result([_dart(covered: true)]));

      final dartSection = _section(report, '## Flutter/Dart 统计');
      expect(dartSection, isNot(contains('无覆盖率数据')));
      expect(dartSection, contains('已覆盖: 1'));
      expect(dartSection, contains('100.0%'));
    });
  });

  group('AC3 — 缺失标记不改变边界判定与退出码语义', () {
    test('缺失标记下未覆盖边界仍进入报告（退出码数据源不受影响）', () {
      // main() 的 exit(1) 只看 uncoveredBoundaries + 高优先级判定；
      // 缺失标记是纯报告元数据，不得吞掉边界本身。
      final result = _result([_rust()], rustMissing: true);
      expect(result.uncoveredBoundaries, hasLength(1));

      final report = ReportGenerator(_config()).generate(result);
      // Rust 边界仍在报告中列出（高优先级未覆盖小节）。
      expect(report, contains('rust-backend/src/store.rs:20'));
    });

    test('兼容性：不传缺失标记时报告无任何「无覆盖率数据」字样', () {
      final report = ReportGenerator(
        _config(),
      ).generate(_result([_dart(), _rust()]));
      expect(report, isNot(contains('无覆盖率数据')));
    });
  });
}
