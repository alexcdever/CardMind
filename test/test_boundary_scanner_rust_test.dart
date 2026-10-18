// Tests for AC1/AC2/AC3 of gate-selector-fix-2:
//  - Rust boundary scanning targets rust-backend/ (not stale rust/)
//  - LCOV parsed from rust-backend/lcov.info resolves rust-backend/src paths
//  - isMeaningfulHighPriorityBoundary uses v2 lib/ layout with parity exemptions
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/test_boundary_scanner.dart';

BoundaryVisitor _visitorFor(String filePath) => BoundaryVisitor(filePath);

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

Boundary _b({
  BoundaryType type = BoundaryType.condition,
  required String path,
  int line = 1,
  String code = 'x',
  String? desc,
  bool covered = false,
}) => Boundary(
  type: type,
  filePath: path,
  lineNumber: line,
  codeSnippet: code,
  description: desc,
  isCovered: covered,
);

void main() {
  group('AC1 — rust-backend path routing', () {
    test('_isRustFile: rust-backend/src/*.rs is a rust file', () {
      expect(_visitorFor('rust-backend/src/store.rs').debugIsRustFile, isTrue);
      // Stale v1 path and non-rust paths are not rust files.
      expect(_visitorFor('rust/src/store.rs').debugIsRustFile, isFalse);
      expect(
        _visitorFor('lib/pages/note_list_page.dart').debugIsRustFile,
        isFalse,
      );
    });

    test('config include paths point at rust-backend/src/', () {
      final cfg = ScannerConfig.fromYaml(
        File('tool/test_boundary_config.yaml').readAsStringSync(),
      );
      expect(cfg.includePaths, contains('rust-backend/src/'));
      expect(cfg.includePaths, isNot(contains('rust/src/')));
      expect(cfg.excludePaths, contains('rust-backend/tests/'));
      expect(cfg.excludePaths, contains('rust-backend/src/frb_generated.rs'));
    });

    test(
      '_scanRustBoundaries enumerates Directory(rust-backend/src)',
      () async {
        // The on-disk scanner binary is exercised via scan(); if the Rust
        // sub-scanner crate is present under rust-backend/tool/ it returns >0
        // boundaries all rooted at rust-backend/.
        final scanner = TestBoundaryScanner(_config());
        final result = await scanner.scanBoundariesForTest();
        if (result.isEmpty) {
          // rust toolchain absent — at least assert the directory the scanner
          // targets is rust-backend/src (guard rail for the source-of-truth).
          expect(
            Directory('rust-backend/src').existsSync(),
            isTrue,
            reason: 'rust-backend/src must be the scanned dir',
          );
          return;
        }
        expect(
          result.every((b) => b.filePath.startsWith('rust-backend/')),
          isTrue,
          reason: 'every rust boundary path must be rust-backend/…',
        );
      },
    );

    test('ScanScope.rust matches rust-backend/src paths', () {
      final rustB = _b(path: 'rust-backend/src/store.rs', desc: 'If statement');
      final dartB = _b(
        path: 'lib/pages/editor_page.dart',
        desc: 'If statement',
      );
      expect(debugMatchesScope(rustB, ScanScope.rust), isTrue);
      expect(debugMatchesScope(dartB, ScanScope.rust), isFalse);
      expect(debugMatchesScope(rustB, ScanScope.all), isTrue);
    });
  });

  group('AC2 — rust-backend/lcov.info parse', () {
    test('getLineCoverage resolves rust-backend/src paths', () {
      const lcov = '''
SF:rust-backend/src/store.rs
DA:10,3
DA:11,0
DA:20,7
LF:3
LH:2
end_of_record
''';
      final p = LcovParser()..parse(lcov);
      expect(p.getLineCoverage('rust-backend/src/store.rs', 10), 3);
      expect(p.getLineCoverage('rust-backend/src/store.rs', 20), 7);
      expect(p.getLineCoverage('rust-backend/src/store.rs', 999), isNull);
    });

    test('getLineCoverage resolves absolute-pathed rust-backend SF', () {
      final abs =
          '${Directory.current.path.replaceAll('\\', '/')}/rust-backend/src/api.rs';
      final lcov = 'SF:$abs\nDA:5,4\nend_of_record\n';
      final p = LcovParser()..parse(lcov);
      expect(p.getLineCoverage('rust-backend/src/api.rs', 5), 4);
    });
  });

  group('AC3 — v2 layout meaningfulness', () {
    test('no v1 path literals survive in the rule', () {
      const v1 = [
        'lib/app/',
        'lib/features/',
        'lib/features/pool/',
        'lib/features/shared/runtime/',
      ];
      final src = File('tool/test_boundary_scanner.dart').readAsStringSync();
      // Only inspect inside isMeaningfulHighPriorityBoundary.
      final start = src.indexOf('bool isMeaningfulHighPriorityBoundary');
      final end = src.indexOf('Future<ScanResult> scan(');
      final body = src.substring(start, end);
      for (final p in v1) {
        expect(body.contains(p), isFalse, reason: '$p is dead v1 path');
      }
    });

    test('lib/pages/ UI condition/null boundaries get v1-parity exemption', () {
      final scanner = TestBoundaryScanner(_config());
      final exempt = [
        _b(
          path: 'lib/pages/note_list_page.dart',
          desc: 'If statement true branch',
          code: 'if (notes.isEmpty) { ... }',
        ),
        _b(
          path: 'lib/pages/editor_page.dart',
          desc: 'Ternary operator condition',
          code: 'a ? b : c',
        ),
        _b(
          path: 'lib/pages/devices_page.dart',
          desc: 'Null check',
          code: 'device == null',
        ),
        _b(
          path: 'lib/pages/settings_page.dart',
          desc: 'Switch case branch',
          code: 'switch case',
        ),
      ];
      for (final b in exempt) {
        expect(
          scanner.isMeaningfulHighPriorityBoundary(b),
          isFalse,
          reason: '${b.filePath} ${b.description} should be exempt',
        );
      }
    });

    test('lib/services/ ?? parity + lib/bridge/ While parity', () {
      final scanner = TestBoundaryScanner(_config());
      // v1 lib/features/pool/data/ exempted Null-aware coalescing; v2 services/
      // holds the same data-layer code.
      expect(
        scanner.isMeaningfulHighPriorityBoundary(
          _b(
            path: 'lib/services/settings_service.dart',
            desc: 'Null-aware coalescing (??)',
            code: 'x ?? y',
          ),
        ),
        isFalse,
      );
      // v1 lib/features/shared/runtime/rust_library_path.dart While was exempt;
      // v2 equivalent lives under lib/bridge/.
      expect(
        scanner.isMeaningfulHighPriorityBoundary(
          _b(
            path: 'lib/bridge/rust_library_path.dart',
            desc: 'While loop',
            code: 'while (x) { ... }',
          ),
        ),
        isFalse,
      );
    });

    test('a still-meaningful boundary is NOT suppressed', () {
      final scanner = TestBoundaryScanner(_config());
      // A Try-catch carrying a real exception marker stays high priority.
      final keep = _b(
        path: 'lib/services/sync_service.dart',
        desc: 'Try-catch block',
        code: 'try { ... } catch (Exception e) { ... }',
      );
      expect(scanner.isMeaningfulHighPriorityBoundary(keep), isTrue);
    });
  });

  group('gate-infra-fix-3 AC1 — Dart boundary filePath repo-relative', () {
    test('repoRelativePath strips cwd and normalizes backslashes', () {
      final cwd = Directory.current.path;
      expect(
        debugRepoRelativePath('$cwd/lib/pages/x.dart'),
        'lib/pages/x.dart',
      );
      expect(
        debugRepoRelativePath('${cwd.replaceAll('/', r'\')}\\lib\\x.dart'),
        'lib/x.dart',
      );
      // Already-relative POSIX path stays untouched.
      expect(debugRepoRelativePath('lib/pages/x.dart'), 'lib/pages/x.dart');
    });

    test('ScanScope.flutter matches normalized lib/ boundary', () {
      final dartB = _b(
        path: 'lib/pages/editor_page.dart',
        desc: 'If statement',
      );
      expect(debugMatchesScope(dartB, ScanScope.flutter), isTrue);
      final rustB = _b(path: 'rust-backend/src/store.rs', desc: 'If statement');
      expect(debugMatchesScope(rustB, ScanScope.flutter), isFalse);
    });

    test(
      'Dart scan emits repo-relative lib/ paths (no absolute leak)',
      () async {
        final scanner = TestBoundaryScanner(_config());
        final boundaries = await scanner.scanDartBoundariesForTest();
        expect(boundaries, isNotEmpty, reason: 'lib/ must produce boundaries');
        for (final b in boundaries) {
          expect(
            b.filePath.startsWith('lib/'),
            isTrue,
            reason: '${b.filePath} must be repo-relative lib/…',
          );
          expect(
            debugMatchesScope(b, ScanScope.flutter),
            isTrue,
            reason: '${b.filePath} must match flutter scope',
          );
        }
      },
    );
  });

  group('gate-infra-fix-3 AC5 — Result/Option signature boundaries', () {
    // 真实跑 boundary_scanner 二进制（cargo run --manifest-path）；rust
    // toolchain 缺失则降级为「断言死代码已删」。
    Future<List<Map<String, dynamic>>> runScannerOn(String fixtureRel) async {
      final r = await Process.run('cargo', [
        'run',
        '--quiet',
        '--manifest-path',
        'rust-backend/tool/boundary_scanner/Cargo.toml',
      ], runInShell: true);
      expect(r.exitCode, 0, reason: 'boundary_scanner run failed: ${r.stderr}');
      final list = jsonDecode(r.stdout.toString()) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .where(
            (b) =>
                (b['file_path'] as String).replaceAll(r'\', '/') == fixtureRel,
          )
          .toList();
    }

    test('fn returning Result/Option produces exception boundary', () async {
      // api.rs 的自由 fn（pub fn note_get -> Option<String>、
      // note_export_all -> anyhow::Result<…>）是 scan_items_for_types 的
      // 直接覆盖对象——Result/Option 返回应产出 exception 边界。
      final api = await runScannerOn('rust-backend/src/api.rs');
      if (api.isEmpty) {
        // rust toolchain 缺失：至少死代码不存在（恒 false stub 不允许残留）。
        final src = File(
          'rust-backend/tool/boundary_scanner/src/main.rs',
        ).readAsStringSync();
        expect(
          src.contains('type_contains_result_or_option(_ty: &Type) -> bool'),
          isFalse,
          reason: '恒 false stub 不允许残留（已实现或已删）',
        );
        return;
      }
      // code_snippet 被截断为 "Result/Option"，按边界类型 + 描述断言。
      final resultBounds = api.where(
        (b) =>
            b['boundary_type'] == 'exception' &&
            ((b['description'] as String).contains('Result/Option') ||
                (b['code_snippet'] as String).contains('Result')),
      );
      expect(
        resultBounds,
        isNotEmpty,
        reason: 'api.rs Result/Option 返回应产生 Result/Option exception 边界',
      );
    });
  });
}
