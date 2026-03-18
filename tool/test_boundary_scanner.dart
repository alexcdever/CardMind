#!/usr/bin/env dart
// input: 需要自动识别代码中的边界条件并检查测试覆盖情况
// output: 扫描代码生成边界覆盖报告，识别已覆盖和未覆盖的边界
// pos: tool/test_boundary_scanner.dart - 测试边界扫描器主程序，修改本文件需同步更新文件头和所属 DIR.md
// 中文注释: 测试边界扫描器，自动识别代码边界条件并生成覆盖报告

import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:yaml/yaml.dart';

/// 边界类型枚举
enum BoundaryType {
  condition, // if/else/switch
  null_, // null check
  exception, // try/catch
  input, // TextField/onChanged
  async, // async/await
  collection, // empty check
  lifecycle, // initState/dispose
  interaction, // Focus/KeyEvent
}

/// 边界信息
class Boundary {
  final BoundaryType type;
  final String filePath;
  final int lineNumber;
  final String codeSnippet;
  final String? description;
  bool isCovered;
  int? executionCount; // 执行次数（来自 LCOV）

  Boundary({
    required this.type,
    required this.filePath,
    required this.lineNumber,
    required this.codeSnippet,
    this.description,
    this.isCovered = false,
    this.executionCount,
  });
}

/// 扫描结果
class ScanResult {
  final List<Boundary> boundaries;
  final List<Boundary> coveredBoundaries;
  final List<Boundary> uncoveredBoundaries;

  ScanResult({
    required this.boundaries,
    required this.coveredBoundaries,
    required this.uncoveredBoundaries,
  });

  double get coverageRatio =>
      boundaries.isEmpty ? 1.0 : coveredBoundaries.length / boundaries.length;
}

/// 配置类
class ScannerConfig {
  final List<String> includePaths;
  final List<String> excludePaths;
  final Map<BoundaryType, double> weights;
  final List<String> ignorePatterns;

  ScannerConfig({
    required this.includePaths,
    required this.excludePaths,
    required this.weights,
    required this.ignorePatterns,
  });

  factory ScannerConfig.fromYaml(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    final scanner = yaml['scanner'];

    return ScannerConfig(
      includePaths: List<String>.from(scanner['include'] ?? []),
      excludePaths: List<String>.from(scanner['exclude'] ?? []),
      weights: _parseWeights(scanner['weights']),
      ignorePatterns: List<String>.from(scanner['ignore_patterns'] ?? []),
    );
  }

  static Map<BoundaryType, double> _parseWeights(YamlMap? weights) {
    final map = <BoundaryType, double>{};
    if (weights == null) return map;

    for (final entry in weights.entries) {
      final key = entry.key.toString();
      final type = _parseBoundaryType(key);
      if (type != null && entry.value is num) {
        map[type] = (entry.value as num).toDouble();
      }
    }
    return map;
  }

  static BoundaryType? _parseBoundaryType(String key) {
    return switch (key) {
      'condition' => BoundaryType.condition,
      'null' => BoundaryType.null_,
      'exception' => BoundaryType.exception,
      'input' => BoundaryType.input,
      'async' => BoundaryType.async,
      'collection' => BoundaryType.collection,
      'lifecycle' => BoundaryType.lifecycle,
      'interaction' => BoundaryType.interaction,
      _ => null,
    };
  }
}

/// AST 边界访问者
class BoundaryVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Boundary> boundaries = [];
  final dynamic lineInfo; // LineInfo from analyzer

  BoundaryVisitor(this.filePath, [this.lineInfo]);

  @override
  void visitIfStatement(IfStatement node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'If statement condition',
    );
    super.visitIfStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'Ternary operator condition',
    );
    super.visitConditionalExpression(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'Switch statement',
    );
    super.visitSwitchStatement(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    _addBoundary(
      BoundaryType.exception,
      node.offset,
      node.toSource(),
      'Try-catch block',
    );
    super.visitTryStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // 检查输入相关方法
    if (methodName == 'onChanged' ||
        methodName == 'onSubmitted' ||
        methodName == 'onTap') {
      _addBoundary(
        BoundaryType.input,
        node.offset,
        node.toSource(),
        'Input field callback',
      );
    }

    // 检查异步相关方法
    if (methodName == 'then' ||
        methodName == 'catchError' ||
        methodName == 'whenComplete') {
      _addBoundary(
        BoundaryType.async,
        node.offset,
        node.toSource(),
        'Async operation callback',
      );
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // 检查 async 函数
    if (node.parameters?.toSource().contains('async') ?? false) {
      _addBoundary(
        BoundaryType.async,
        node.offset,
        node.toSource(),
        'Async function',
      );
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    // 检查 null 检查
    if (node.operator.type.toString() == 'EQ_EQ' ||
        node.operator.type.toString() == 'BANG_EQ') {
      final left = node.leftOperand.toSource();
      final right = node.rightOperand.toSource();
      if (left == 'null' || right == 'null') {
        _addBoundary(
          BoundaryType.null_,
          node.offset,
          node.toSource(),
          'Null check',
        );
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    // 检查空值传播
    if (node.operator.type.toString() == 'QUESTION_PERIOD') {
      _addBoundary(
        BoundaryType.null_,
        node.offset,
        node.toSource(),
        'Null-aware access',
      );
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // 检查生命周期方法
    final methodName = node.name.lexeme;
    if (methodName == 'initState' ||
        methodName == 'dispose' ||
        methodName == 'didUpdateWidget' ||
        methodName == 'didChangeDependencies') {
      _addBoundary(
        BoundaryType.lifecycle,
        node.offset,
        node.toSource(),
        'Widget lifecycle method: $methodName',
      );
    }
    super.visitMethodDeclaration(node);
  }

  void _addBoundary(BoundaryType type, int offset, String code, String desc) {
    // 截断代码片段
    final snippet = code.length > 50 ? '${code.substring(0, 50)}...' : code;

    // 计算准确的行号
    int lineNumber = 0;
    if (lineInfo != null) {
      try {
        lineNumber = lineInfo.getLocation(offset).lineNumber;
      } catch (e) {
        // 如果获取失败，使用 0
        lineNumber = 0;
      }
    }

    boundaries.add(
      Boundary(
        type: type,
        filePath: filePath,
        lineNumber: lineNumber,
        codeSnippet: snippet,
        description: desc,
      ),
    );
  }
}

/// LCOV 文件解析器
class LcovParser {
  final Map<String, FileCoverage> fileCoverages = {};

  void parse(String lcovContent) {
    final lines = lcovContent.split('\n');
    String? currentFile;

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        // SF:<file path>
        currentFile = line.substring(3);
        fileCoverages[currentFile] = FileCoverage(path: currentFile);
      } else if (line.startsWith('DA:') && currentFile != null) {
        // DA:<line number>,<execution count>[,<checksum>]
        final parts = line.substring(3).split(',');
        if (parts.length >= 2) {
          final lineNum = int.tryParse(parts[0]);
          final count = int.tryParse(parts[1]);
          if (lineNum != null && count != null) {
            fileCoverages[currentFile]!.lineHits[lineNum] = count;
          }
        }
      } else if (line == 'end_of_record') {
        currentFile = null;
      }
    }
  }

  /// 获取特定文件特定行的执行次数
  /// 返回 null 表示该行没有覆盖信息
  int? getLineCoverage(String filePath, int lineNumber) {
    final coverage = fileCoverages[filePath];
    if (coverage == null) return null;
    return coverage.lineHits[lineNumber];
  }

  /// 获取文件的总体覆盖率统计
  CoverageStats getFileStats(String filePath) {
    final coverage = fileCoverages[filePath];
    if (coverage == null) {
      return CoverageStats(totalLines: 0, coveredLines: 0);
    }

    final total = coverage.lineHits.length;
    final covered = coverage.lineHits.values.where((c) => c > 0).length;

    return CoverageStats(totalLines: total, coveredLines: covered);
  }
}

class FileCoverage {
  final String path;
  final Map<int, int> lineHits = {}; // 行号 -> 执行次数

  FileCoverage({required this.path});
}

class CoverageStats {
  final int totalLines;
  final int coveredLines;

  CoverageStats({required this.totalLines, required this.coveredLines});

  double get percentage =>
      totalLines == 0 ? 0.0 : (coveredLines / totalLines) * 100;
}

/// 测试覆盖分析器（保留用于兼容性，但不再使用启发式匹配）
class TestCoverageAnalyzer {
  final List<String> testPaths;

  TestCoverageAnalyzer(this.testPaths);

  Future<Set<String>> findCoveredBoundaries() async {
    final covered = <String>{};

    for (final testPath in testPaths) {
      final dir = Directory(testPath);
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('_test.dart')) continue;

        try {
          final content = await entity.readAsString();

          // 提取测试函数名 - 使用简单的字符串匹配
          final lines = content.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith("test('") || trimmed.startsWith('test("')) {
              // 手动提取测试名
              String? testName;
              if (trimmed.startsWith("test('")) {
                final start = 6;
                final endQuote = trimmed.indexOf("',", start);
                if (endQuote > start) {
                  testName = trimmed.substring(start, endQuote);
                }
              } else if (trimmed.startsWith('test("')) {
                final start = 6;
                final endQuote = trimmed.indexOf('",', start);
                if (endQuote > start) {
                  testName = trimmed.substring(start, endQuote);
                }
              }
              if (testName != null && testName.isNotEmpty) {
                covered.add(_normalizeTestName(testName));
              }
            }
          }
        } catch (e) {
          stderr.writeln('Warning: Failed to read ${entity.path}: $e');
        }
      }
    }

    return covered;
  }

  String _normalizeTestName(String name) {
    // 将测试名转换为小写并移除特殊字符
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool isBoundaryCovered(Boundary boundary, Set<String> coveredTests) {
    final normalizedCode = _normalizeTestName(boundary.codeSnippet);
    final typeKeywords = _getTypeKeywords(boundary.type);

    for (final test in coveredTests) {
      // 检查测试名是否包含边界相关的关键词
      if (typeKeywords.any((kw) => test.contains(kw))) {
        return true;
      }
      // 检查代码片段是否被引用
      if (test.contains(normalizedCode)) {
        return true;
      }
    }

    return false;
  }

  List<String> _getTypeKeywords(BoundaryType type) {
    return switch (type) {
      BoundaryType.condition => ['if', 'else', 'condition', 'branch'],
      BoundaryType.null_ => ['null', 'empty', 'none'],
      BoundaryType.exception => ['error', 'exception', 'catch', 'fail'],
      BoundaryType.input => ['input', 'field', 'enter', 'type'],
      BoundaryType.async => ['async', 'await', 'future', 'promise'],
      BoundaryType.collection => ['empty', 'list', 'array', 'collection'],
      BoundaryType.lifecycle => ['init', 'dispose', 'create', 'destroy'],
      BoundaryType.interaction => ['focus', 'key', 'click', 'tap'],
    };
  }
}

/// 主扫描器类
class TestBoundaryScanner {
  final ScannerConfig config;

  TestBoundaryScanner(this.config);

  Future<ScanResult> scan() async {
    // 步骤 1: 收集代码覆盖率（运行 flutter test --coverage）
    stderr.writeln('Step 1: Collecting code coverage...');
    await _collectCoverageData();

    // 步骤 2: 解析 LCOV 文件
    stderr.writeln('Step 2: Parsing LCOV data...');
    final lcovParser = LcovParser();
    final lcovFile = File('coverage/lcov.info');
    if (lcovFile.existsSync()) {
      lcovParser.parse(await lcovFile.readAsString());
    } else {
      stderr.writeln('Warning: coverage/lcov.info not found');
    }

    // 步骤 3: 扫描代码边界
    stderr.writeln('Step 3: Scanning code boundaries...');
    final boundaries = await _scanBoundaries();

    // 步骤 4: 精确匹配边界与覆盖率
    stderr.writeln('Step 4: Matching boundaries with coverage...');
    for (final boundary in boundaries) {
      final relativePath = boundary.filePath.startsWith(Directory.current.path)
          ? boundary.filePath.substring(Directory.current.path.length + 1)
          : boundary.filePath;

      final coverage = lcovParser.getLineCoverage(
        relativePath,
        boundary.lineNumber,
      );
      boundary.isCovered = coverage != null && coverage > 0;
      boundary.executionCount = coverage;
    }

    // 步骤 5: 分类边界
    final covered = boundaries.where((b) => b.isCovered).toList();
    final uncovered = boundaries.where((b) => !b.isCovered).toList();

    return ScanResult(
      boundaries: boundaries,
      coveredBoundaries: covered,
      uncoveredBoundaries: uncovered,
    );
  }

  Future<List<Boundary>> _scanBoundaries() async {
    final boundaries = <Boundary>[];

    // 扫描 Dart 文件
    for (final includePath in config.includePaths) {
      if (includePath.contains('rust/')) continue; // 跳过 Rust 目录

      final dir = Directory(includePath);
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        if (_shouldIgnore(entity.path)) continue;

        try {
          final content = await entity.readAsString();
          final result = parseString(content: content);

          final visitor = BoundaryVisitor(entity.path, result.lineInfo);
          result.unit.visitChildren(visitor);

          boundaries.addAll(visitor.boundaries);
        } catch (e) {
          stderr.writeln('Warning: Failed to parse ${entity.path}: $e');
        }
      }
    }

    // 扫描 Rust 文件
    final rustBoundaries = await _scanRustBoundaries();
    boundaries.addAll(rustBoundaries);

    return boundaries;
  }

  Future<List<Boundary>> _scanRustBoundaries() async {
    final rustSrc = Directory('rust/src');
    if (!rustSrc.existsSync()) {
      return [];
    }

    stderr.writeln('  Scanning Rust boundaries...');

    try {
      final result = await Process.run('cargo', [
        'run',
        '--manifest-path',
        'rust/tool/boundary_scanner/Cargo.toml',
      ], runInShell: true);

      if (result.exitCode != 0) {
        stderr.writeln('  Warning: Rust scanner failed: ${result.stderr}');
        return [];
      }

      // 解析 JSON 输出
      final jsonList = jsonDecode(result.stdout) as List;
      return jsonList
          .map(
            (json) => Boundary(
              type: _parseBoundaryType(json['boundary_type'] as String),
              filePath: json['file_path'] as String,
              lineNumber: json['line_number'] as int,
              codeSnippet: json['code_snippet'] as String,
              description: json['description'] as String,
            ),
          )
          .toList();
    } catch (e) {
      stderr.writeln('  Warning: Failed to scan Rust boundaries: $e');
      return [];
    }
  }

  BoundaryType _parseBoundaryType(String type) {
    return switch (type) {
      'condition' => BoundaryType.condition,
      'null' => BoundaryType.null_,
      'exception' => BoundaryType.exception,
      'input' => BoundaryType.input,
      'async' => BoundaryType.async,
      'collection' => BoundaryType.collection,
      'lifecycle' => BoundaryType.lifecycle,
      'interaction' => BoundaryType.interaction,
      _ => BoundaryType.condition, // 默认
    };
  }

  Future<void> _collectCoverageData() async {
    final lcovFile = File('coverage/lcov.info');

    // 检查是否已有有效的 LCOV 文件（1 小时内）
    if (lcovFile.existsSync()) {
      final lastModified = await lcovFile.lastModified();
      final age = DateTime.now().difference(lastModified);
      if (age.inHours < 1) {
        stderr.writeln(
          '  Using existing coverage data (modified ${age.inMinutes} minutes ago)',
        );
        return;
      }
    }

    // 运行 flutter test --coverage
    stderr.writeln('  Running: flutter test --coverage');
    stderr.writeln('  (This may take a few minutes...)');
    final result = await Process.run('flutter', [
      'test',
      '--coverage',
    ], runInShell: true);

    if (result.exitCode != 0) {
      stderr.writeln(
        '  Warning: Test execution failed, coverage data may be incomplete',
      );
    } else {
      stderr.writeln('  Coverage data collected successfully');
    }
  }

  bool _shouldIgnore(String path) {
    for (final pattern in config.ignorePatterns) {
      if (RegExp(pattern).hasMatch(path)) return true;
    }
    for (final exclude in config.excludePaths) {
      if (path.startsWith(exclude)) return true;
    }
    return false;
  }
}

/// 报告生成器
class ReportGenerator {
  final ScannerConfig config;

  ReportGenerator(this.config);

  String generate(ScanResult result) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    // 分离 Dart 和 Rust 边界
    final dartBoundaries = result.boundaries
        .where((b) => b.filePath.startsWith('lib/'))
        .toList();
    final rustBoundaries = result.boundaries
        .where((b) => b.filePath.startsWith('rust/'))
        .toList();

    final dartCovered = dartBoundaries.where((b) => b.isCovered).toList();
    final rustCovered = rustBoundaries.where((b) => b.isCovered).toList();

    final dartUncovered = dartBoundaries.where((b) => !b.isCovered).toList();
    final rustUncovered = rustBoundaries.where((b) => !b.isCovered).toList();

    buffer.writeln('# 测试边界覆盖报告');
    buffer.writeln('');
    buffer.writeln('生成时间: ${now.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('**范围**: Dart/Flutter + Rust 代码');
    buffer.writeln('');

    // 总体统计
    buffer.writeln('## 总体统计');
    buffer.writeln('- 总边界数: ${result.boundaries.length}');
    buffer.writeln(
      '- 已覆盖: ${result.coveredBoundaries.length} (${(result.coverageRatio * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln(
      '- 未覆盖: ${result.uncoveredBoundaries.length} (${((1 - result.coverageRatio) * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln('');

    // Flutter/Dart 统计
    final dartCoverage = dartBoundaries.isEmpty
        ? 0.0
        : dartCovered.length / dartBoundaries.length;
    buffer.writeln('## Flutter/Dart 统计');
    buffer.writeln('- 边界数: ${dartBoundaries.length}');
    buffer.writeln(
      '- 已覆盖: ${dartCovered.length} (${(dartCoverage * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln('- 未覆盖: ${dartUncovered.length}');
    buffer.writeln('');

    // Rust 统计
    final rustCoverage = rustBoundaries.isEmpty
        ? 0.0
        : rustCovered.length / rustBoundaries.length;
    buffer.writeln('## Rust 统计');
    buffer.writeln('- 边界数: ${rustBoundaries.length}');
    buffer.writeln(
      '- 已覆盖: ${rustCovered.length} (${(rustCoverage * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln('- 未覆盖: ${rustUncovered.length}');
    buffer.writeln('');

    // 按优先级分组未覆盖边界
    final prioritized = _prioritizeBoundaries(result.uncoveredBoundaries);

    if (prioritized.high.isNotEmpty) {
      buffer.writeln('## 🔴 高优先级未覆盖边界');
      buffer.writeln('');
      for (var i = 0; i < prioritized.high.length; i++) {
        _writeBoundary(buffer, i + 1, prioritized.high[i]);
      }
    }

    if (prioritized.medium.isNotEmpty) {
      buffer.writeln('## 🟡 中优先级未覆盖边界');
      buffer.writeln('');
      for (var i = 0; i < prioritized.medium.length; i++) {
        _writeBoundary(buffer, i + 1, prioritized.medium[i]);
      }
    }

    if (prioritized.low.isNotEmpty) {
      buffer.writeln('## 🟢 低优先级未覆盖边界');
      buffer.writeln('');
      for (var i = 0; i < prioritized.low.length; i++) {
        _writeBoundary(buffer, i + 1, prioritized.low[i]);
      }
    }

    if (result.coveredBoundaries.isNotEmpty) {
      buffer.writeln('## ✅ 已覆盖边界');
      buffer.writeln('');
      buffer.writeln('共 ${result.coveredBoundaries.length} 个边界已被测试覆盖。');
    }

    return buffer.toString();
  }

  void _writeBoundary(StringBuffer buffer, int index, Boundary boundary) {
    buffer.writeln(
      '$index. **${boundary.type.name}** - `${boundary.filePath}:${boundary.lineNumber}`',
    );
    buffer.writeln('   - 代码: `${boundary.codeSnippet}`');
    if (boundary.description != null) {
      buffer.writeln('   - 描述: ${boundary.description}');
    }
    if (boundary.executionCount != null) {
      buffer.writeln('   - 执行次数: ${boundary.executionCount}');
    }
    buffer.writeln('');
  }

  PrioritizedBoundaries _prioritizeBoundaries(List<Boundary> boundaries) {
    final high = <Boundary>[];
    final medium = <Boundary>[];
    final low = <Boundary>[];

    for (final boundary in boundaries) {
      final weight = config.weights[boundary.type] ?? 0.5;
      if (weight >= 1.0) {
        high.add(boundary);
      } else if (weight >= 0.7) {
        medium.add(boundary);
      } else {
        low.add(boundary);
      }
    }

    return PrioritizedBoundaries(high: high, medium: medium, low: low);
  }
}

class PrioritizedBoundaries {
  final List<Boundary> high;
  final List<Boundary> medium;
  final List<Boundary> low;

  PrioritizedBoundaries({
    required this.high,
    required this.medium,
    required this.low,
  });
}

void main(List<String> args) async {
  // 加载配置
  final configFile = File('tool/test_boundary_config.yaml');
  if (!configFile.existsSync()) {
    stderr.writeln(
      'Error: Config file not found: tool/test_boundary_config.yaml',
    );
    exit(1);
  }

  final config = ScannerConfig.fromYaml(configFile.readAsStringSync());
  final scanner = TestBoundaryScanner(config);

  stdout.writeln('Scanning for test boundaries...');
  final result = await scanner.scan();

  // 生成报告
  final generator = ReportGenerator(config);
  final report = generator.generate(result);

  // 保存到 /tmp
  final reportFile = File('/tmp/cardmind_test_boundary_report.md');
  await reportFile.writeAsString(report);

  stdout.writeln('');
  stdout.writeln('Found ${result.boundaries.length} boundaries');
  stdout.writeln('Covered: ${result.coveredBoundaries.length}');
  stdout.writeln('Uncovered: ${result.uncoveredBoundaries.length}');
  stdout.writeln(
    'Coverage: ${(result.coverageRatio * 100).toStringAsFixed(1)}%',
  );
  stdout.writeln('');
  stdout.writeln('Report saved to: ${reportFile.path}');

  // 如果有高优先级未覆盖边界，返回非零退出码
  final hasHighPriorityUncovered = result.uncoveredBoundaries.any(
    (b) => (config.weights[b.type] ?? 0.5) >= 1.0,
  );
  if (hasHighPriorityUncovered) {
    exit(1);
  }
}
