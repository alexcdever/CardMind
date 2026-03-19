// input: 需要测试测试边界扫描器的各项功能
// output: 验证扫描器能正确识别边界、对比覆盖、生成报告
// pos: test/tool/test_boundary_scanner_test.dart - 边界扫描器单元测试，修改本文件需同步更新文件头和所属 DIR.md
// 中文注释: 测试边界扫描器的单元测试

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/test_boundary_scanner.dart';

void main() {
  group('BoundaryType', () {
    test('should have 8 boundary types', () {
      expect(BoundaryType.values.length, equals(8));
    });

    test('should include all expected types', () {
      final typeNames = BoundaryType.values.map((t) => t.name).toSet();
      expect(typeNames, contains('condition'));
      expect(typeNames, contains('null_'));
      expect(typeNames, contains('exception'));
      expect(typeNames, contains('input'));
      expect(typeNames, contains('async'));
      expect(typeNames, contains('collection'));
      expect(typeNames, contains('lifecycle'));
      expect(typeNames, contains('interaction'));
    });
  });

  group('ScannerConfig', () {
    test('should parse config from yaml', () {
      final yaml = '''
scanner:
  include:
    - lib/
  exclude:
    - test/
  weights:
    condition: 1.0
    null: 1.0
  ignore_patterns:
    - "test/"
''';

      final config = ScannerConfig.fromYaml(yaml);
      expect(config.includePaths, contains('lib/'));
      expect(config.excludePaths, contains('test/'));
      expect(config.weights[BoundaryType.condition], equals(1.0));
      expect(config.weights[BoundaryType.null_], equals(1.0));
      expect(config.ignorePatterns, contains('test/'));
    });

    test('should handle empty yaml', () {
      final yaml = '''
scanner:
  include: []
  exclude: []
  weights: {}
  ignore_patterns: []
''';

      final config = ScannerConfig.fromYaml(yaml);
      expect(config.includePaths, isEmpty);
      expect(config.excludePaths, isEmpty);
      expect(config.weights, isEmpty);
      expect(config.ignorePatterns, isEmpty);
    });
  });

  group('Boundary', () {
    test('should create boundary with all fields', () {
      final boundary = Boundary(
        type: BoundaryType.condition,
        filePath: 'lib/test.dart',
        lineNumber: 10,
        codeSnippet: 'if (x)',
        description: 'Test condition',
      );

      expect(boundary.type, equals(BoundaryType.condition));
      expect(boundary.filePath, equals('lib/test.dart'));
      expect(boundary.lineNumber, equals(10));
      expect(boundary.codeSnippet, equals('if (x)'));
      expect(boundary.description, equals('Test condition'));
    });
  });

  group('BoundaryVisitor filtering', () {
    test('should ignore noisy Flutter named arguments', () {
      final result = parseString(
        content: '''
import 'package:flutter/material.dart';

Widget buildCard() {
  return TextButton(
    onPressed: () {},
    child: const Text('保存'),
  );
}
''',
      );

      final visitor = BoundaryVisitor('lib/sample.dart', result.lineInfo);
      result.unit.visitChildren(visitor);

      expect(
        visitor.boundaries
            .where((b) => b.description == 'Named argument')
            .length,
        equals(1),
      );
      expect(visitor.boundaries.single.codeSnippet, contains('onPressed'));
    });

    test('should ignore Flutter field declarations and return statements', () {
      final result = parseString(
        content: '''
class Sample {
  final String label;

  const Sample(this.label);

  String text() {
    return label;
  }
}
''',
      );

      final visitor = BoundaryVisitor('lib/sample.dart', result.lineInfo);
      result.unit.visitChildren(visitor);

      expect(
        visitor.boundaries.where(
          (b) => b.description == 'Field without initializer',
        ),
        isEmpty,
      );
      expect(
        visitor.boundaries.where((b) => b.description == 'Return statement'),
        isEmpty,
      );
    });

    test('should emit switch branches instead of switch statement', () {
      final result = parseString(
        content: '''
enum Section { a, b }

String mapSection(Section section) {
  switch (section) {
    case Section.a:
      return 'a';
    case Section.b:
      return 'b';
  }
}
''',
      );

      final visitor = BoundaryVisitor('lib/sample.dart', result.lineInfo);
      result.unit.visitChildren(visitor);

      expect(
        visitor.boundaries
            .where((b) => b.description == 'Switch case branch')
            .length,
        2,
      );
      expect(
        visitor.boundaries.where((b) => b.description == 'Switch statement'),
        isEmpty,
      );
    });

    test('should ignore low value flutter mounted and null guards', () {
      final result = parseString(
        content: '''
import 'package:flutter/widgets.dart';

class SampleState extends State<StatefulWidget> {
  Object? session;

  void onChanged() {
    if (!mounted) {
      return;
    }
    if (session == null) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''',
      );

      final visitor = BoundaryVisitor('lib/sample.dart', result.lineInfo);
      result.unit.visitChildren(visitor);

      expect(
        visitor.boundaries.where(
          (b) =>
              b.description == 'If statement true branch' && b.lineNumber == 7,
        ),
        isEmpty,
      );
      expect(
        visitor.boundaries.where((b) => b.description == 'Null check').length,
        lessThanOrEqualTo(1),
      );
    });

    test('should ignore low value flutter try and null coalescing noise', () {
      final result = parseString(
        content: '''
import 'package:flutter/widgets.dart';

Future<void> load() async {
  try {
    throw StateError('missing');
  } on StateError {
    // ignore
  }
}

Widget buildFeedback(Widget? child, String? code) {
  return child ?? const SizedBox.shrink();
}
''',
      );

      final visitor = BoundaryVisitor('lib/sample.dart', result.lineInfo);
      result.unit.visitChildren(visitor);

      expect(
        visitor.boundaries.where((b) => b.description == 'Try-catch block'),
        isEmpty,
      );
      expect(
        visitor.boundaries.where(
          (b) => b.description == 'Null-aware coalescing (??)',
        ),
        isEmpty,
      );
    });
  });

  group('High priority boundary gate', () {
    test(
      'should ignore low value flutter high priority boundaries at exit gate',
      () {
        final config = ScannerConfig(
          includePaths: const <String>['lib/'],
          excludePaths: const <String>[],
          weights: const <BoundaryType, double>{
            BoundaryType.condition: 1,
            BoundaryType.null_: 1,
            BoundaryType.exception: 1,
            BoundaryType.input: 1,
          },
          ignorePatterns: const <String>[],
        );
        final scanner = TestBoundaryScanner(config);

        expect(
          scanner.isMeaningfulHighPriorityBoundary(
            Boundary(
              type: BoundaryType.input,
              filePath: 'lib/features/pool/pool_page.dart',
              lineNumber: 1,
              codeSnippet: 'onPressed: () => Navigator.pop()',
              description: 'Named argument',
            ),
          ),
          isFalse,
        );
        expect(
          scanner.isMeaningfulHighPriorityBoundary(
            Boundary(
              type: BoundaryType.condition,
              filePath: 'lib/app/navigation/app_homepage_page.dart',
              lineNumber: 2,
              codeSnippet: 'if (condition) { ... }',
              description: 'If statement true branch',
            ),
          ),
          isFalse,
        );
        expect(
          scanner.isMeaningfulHighPriorityBoundary(
            Boundary(
              type: BoundaryType.null_,
              filePath: 'lib/features/cards/cards_controller.dart',
              lineNumber: 33,
              codeSnippet: 'id == null',
              description: 'Null check',
            ),
          ),
          isFalse,
        );
        expect(
          scanner.isMeaningfulHighPriorityBoundary(
            Boundary(
              type: BoundaryType.null_,
              filePath:
                  'lib/features/pool/data/loro_pool_write_repository.dart',
              lineNumber: 94,
              codeSnippet: 'cached ?? const _PoolAggregate()',
              description: 'Null-aware coalescing (??)',
            ),
          ),
          isFalse,
        );
      },
    );

    test('should keep rust high priority boundaries meaningful', () {
      final config = ScannerConfig(
        includePaths: const <String>['lib/', 'rust/src/'],
        excludePaths: const <String>[],
        weights: const <BoundaryType, double>{
          BoundaryType.condition: 1,
          BoundaryType.null_: 1,
          BoundaryType.exception: 1,
          BoundaryType.input: 1,
        },
        ignorePatterns: const <String>[],
      );
      final scanner = TestBoundaryScanner(config);

      expect(
        scanner.isMeaningfulHighPriorityBoundary(
          Boundary(
            type: BoundaryType.exception,
            filePath: 'rust/src/api/mod.rs',
            lineNumber: 10,
            codeSnippet: 'map_err(|_| ApiError::new(...))',
            description: 'Try-catch block',
          ),
        ),
        isTrue,
      );
    });
  });

  group('ScanResult', () {
    test('should calculate coverage ratio correctly', () {
      final result = ScanResult(
        boundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'test.dart',
            lineNumber: 1,
            codeSnippet: 'if',
          ),
          Boundary(
            type: BoundaryType.null_,
            filePath: 'test.dart',
            lineNumber: 2,
            codeSnippet: 'null',
          ),
        ],
        coveredBoundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'test.dart',
            lineNumber: 1,
            codeSnippet: 'if',
          ),
        ],
        uncoveredBoundaries: [
          Boundary(
            type: BoundaryType.null_,
            filePath: 'test.dart',
            lineNumber: 2,
            codeSnippet: 'null',
          ),
        ],
      );

      expect(result.coverageRatio, equals(0.5));
    });

    test('should return 1.0 when no boundaries', () {
      final result = ScanResult(
        boundaries: [],
        coveredBoundaries: [],
        uncoveredBoundaries: [],
      );

      expect(result.coverageRatio, equals(1.0));
    });
  });

  group('LcovParser', () {
    test('should parse LCOV format correctly', () {
      final lcovContent = '''
SF:lib/test.dart
DA:1,1
DA:2,0
DA:3,5
end_of_record
SF:lib/other.dart
DA:10,1
end_of_record
''';

      final parser = LcovParser();
      parser.parse(lcovContent);

      expect(parser.getLineCoverage('lib/test.dart', 1), equals(1));
      expect(parser.getLineCoverage('lib/test.dart', 2), equals(0));
      expect(parser.getLineCoverage('lib/test.dart', 3), equals(5));
      expect(parser.getLineCoverage('lib/test.dart', 4), isNull);
      expect(parser.getLineCoverage('lib/other.dart', 10), equals(1));
      expect(parser.getLineCoverage('nonexistent.dart', 1), isNull);
    });

    test('should handle empty LCOV', () {
      final parser = LcovParser();
      parser.parse('');

      expect(parser.fileCoverages, isEmpty);
    });

    test('should calculate file stats', () {
      final lcovContent = '''
SF:lib/test.dart
DA:1,1
DA:2,0
DA:3,5
end_of_record
''';

      final parser = LcovParser();
      parser.parse(lcovContent);

      final stats = parser.getFileStats('lib/test.dart');
      expect(stats.totalLines, equals(3));
      expect(stats.coveredLines, equals(2));
      expect(stats.percentage, closeTo(66.67, 0.01));
    });

    test('should match absolute Rust paths with relative query path', () {
      final parser = LcovParser();
      final cwd = Directory.current.path;
      parser.parse('''
SF:$cwd/rust/src/api/mod.rs
DA:10,3
end_of_record
''');

      expect(parser.getLineCoverage('rust/src/api/mod.rs', 10), equals(3));
    });
  });

  group('Boundary with coverage', () {
    test('should track coverage status', () {
      final boundary = Boundary(
        type: BoundaryType.condition,
        filePath: 'lib/test.dart',
        lineNumber: 10,
        codeSnippet: 'if (x)',
        isCovered: true,
        executionCount: 5,
      );

      expect(boundary.isCovered, isTrue);
      expect(boundary.executionCount, equals(5));
    });
  });

  group('ReportGenerator', () {
    late ReportGenerator generator;
    late ScannerConfig config;

    setUp(() {
      config = ScannerConfig(
        includePaths: ['lib/'],
        excludePaths: [],
        weights: {BoundaryType.condition: 1.0, BoundaryType.null_: 0.7},
        ignorePatterns: [],
      );
      generator = ReportGenerator(config);
    });

    test('should generate markdown report', () {
      final result = ScanResult(
        boundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'lib/test.dart',
            lineNumber: 10,
            codeSnippet: 'if (x)',
            description: 'Test condition',
          ),
        ],
        coveredBoundaries: [],
        uncoveredBoundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'lib/test.dart',
            lineNumber: 10,
            codeSnippet: 'if (x)',
            description: 'Test condition',
          ),
        ],
      );

      final report = generator.generate(result);

      expect(report, contains('# 测试边界覆盖报告'));
      expect(report, contains('总边界数: 1'));
      expect(report, contains('已覆盖: 0'));
      expect(report, contains('未覆盖: 1'));
    });

    test('should prioritize boundaries correctly', () {
      final result = ScanResult(
        boundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'lib/test.dart',
            lineNumber: 1,
            codeSnippet: 'if',
          ),
          Boundary(
            type: BoundaryType.null_,
            filePath: 'lib/test.dart',
            lineNumber: 2,
            codeSnippet: 'null',
          ),
        ],
        coveredBoundaries: [],
        uncoveredBoundaries: [
          Boundary(
            type: BoundaryType.condition,
            filePath: 'lib/test.dart',
            lineNumber: 1,
            codeSnippet: 'if',
          ),
          Boundary(
            type: BoundaryType.null_,
            filePath: 'lib/test.dart',
            lineNumber: 2,
            codeSnippet: 'null',
          ),
        ],
      );

      final report = generator.generate(result);

      // condition has weight 1.0 (high priority)
      // null_ has weight 0.7 (medium priority)
      expect(report, contains('高优先级'));
      expect(report, contains('中优先级'));
    });
  });
}
