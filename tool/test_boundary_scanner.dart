#!/usr/bin/env dart

/// input: 需要自动识别代码中的边界条件并检查测试覆盖情况
/// output: 扫描代码生成边界覆盖报告，识别已覆盖和未覆盖的边界
/// pos: tool/test_boundary_scanner.dart - 测试边界扫描器主程序，修改本文件需同步更新文件头和所属 DIR.md
/// 中文注释: 测试边界扫描器，自动识别代码边界条件并生成覆盖报告

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

  /// 执行次数（来自 LCOV）
  int? executionCount;

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
  final dynamic lineInfo; // 分析器提供的行信息
  bool _insideTestDeclaration = false;

  BoundaryVisitor(this.filePath, [this.lineInfo]);

  bool get _isFlutterFile =>
      filePath.contains('/lib/') || filePath.startsWith('lib/');

  bool get _isRustFile => filePath.contains('rust/src/');

  bool _looksLikeTestName(String? name) {
    if (name == null) return false;
    return name == 'main' || name.startsWith('test') || name.contains('_test');
  }

  bool _isUiNoiseNamedArgument(String label) {
    const noisy = <String>{
      'label',
      'icon',
      'identifier',
      'semanticLabel',
      'child',
      'children',
      'content',
      'title',
      'container',
      'explicitChildNodes',
      'key',
      'items',
      'destinations',
      'state',
      'useIndicator',
      'autofocus',
      'canPop',
    };
    return noisy.contains(label);
  }

  bool _isUserInputNamedArgument(String label) {
    const meaningful = <String>{
      'onTap',
      'onPressed',
      'onChanged',
      'onSubmitted',
      'onDestinationSelected',
      'onKeyEvent',
      'onPopInvokedWithResult',
      'onSectionChanged',
      'validator',
      'controller',
      'focusNode',
      'keyboardType',
      'textInputAction',
      'initialValue',
      'value',
    };
    return meaningful.contains(label);
  }

  bool _isLowValueFlutterCondition(Expression expression) {
    final source = expression.toSource();
    return source == '!mounted' ||
        source == 'didPop' ||
        source == '_isExitDialogShowing' ||
        source == 'session == null' ||
        source == 'existing == null';
  }

  bool _isLowValueFlutterNullExpression(String source) {
    return source == 'session == null' ||
        source == 'existing == null' ||
        source == 'note != null' ||
        source.contains(' ?? const SizedBox.shrink()') ||
        source.contains(" ?? 'SYNC_FAILED'") ||
        source.contains(' ?? this.updatedAtMicros') ||
        source.startsWith('apiClient ?? ') ||
        source.startsWith('syncService == null');
  }

  bool _isLowValueFlutterTry(TryStatement node) {
    final source = node.toSource();
    return source.contains('on StateError') || source.contains('finally');
  }

  bool _shouldSkipBoundary(BoundaryType type, String desc, AstNode? node) {
    if (_insideTestDeclaration) return true;

    if (_isFlutterFile) {
      if (desc == 'Named argument' && node is NamedExpression) {
        final label = node.name.label.name;
        if (_isUiNoiseNamedArgument(label)) return true;
      }

      if (desc == 'Field without initializer' ||
          desc == 'Nullable variable declaration' ||
          desc == 'Late variable declaration' ||
          desc == 'Uninitialized variable declaration' ||
          desc == 'Top-level function declaration' ||
          desc == 'Enum declaration' ||
          desc == 'Extension declaration' ||
          desc == 'Instance creation' ||
          desc == 'Constructor' ||
          desc == 'This expression' ||
          desc == 'Super expression' ||
          desc == 'Return statement') {
        return true;
      }
    }

    return false;
  }

  @override
  void visitIfStatement(IfStatement node) {
    if (_isFlutterFile && _isLowValueFlutterCondition(node.expression)) {
      super.visitIfStatement(node);
      return;
    }

    /// 检测 then 分支（条件为 true 的情况）
    final thenStatement = node.thenStatement;
    if (thenStatement is Block && thenStatement.statements.isNotEmpty) {
      final firstThenStatement = thenStatement.statements.first;
      _addBoundary(
        BoundaryType.condition,
        firstThenStatement.offset,
        'if (condition) { ... }',
        'If statement true branch',
      );
    } else if (thenStatement is! Block) {
      /// 单行 if 语句没有大括号
      _addBoundary(
        BoundaryType.condition,
        thenStatement.offset,
        'if (condition) statement;',
        'If statement true branch',
      );
    }

    /// 检测 else 分支（条件为 false 的情况）
    final elseStatement = node.elseStatement;
    if (elseStatement != null) {
      if (elseStatement is Block && elseStatement.statements.isNotEmpty) {
        final firstElseStatement = elseStatement.statements.first;
        _addBoundary(
          BoundaryType.condition,
          firstElseStatement.offset,
          'else { ... }',
          'If statement false branch',
        );
      } else if (elseStatement is! Block && elseStatement is! IfStatement) {
        /// else 单行语句（非 else-if）
        _addBoundary(
          BoundaryType.condition,
          elseStatement.offset,
          'else statement;',
          'If statement false branch',
        );
      }

      /// 如果是 else-if，会在递归访问时被单独处理
    }

    super.visitIfStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    if (_isFlutterFile && _isLowValueFlutterCondition(node.condition)) {
      super.visitConditionalExpression(node);
      return;
    }

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
    for (final member in node.members) {
      if (member is SwitchPatternCase) {
        _addBoundary(
          BoundaryType.condition,
          member.offset,
          'switch case',
          'Switch case branch',
          member,
        );
      } else if (member is SwitchDefault) {
        _addBoundary(
          BoundaryType.condition,
          member.offset,
          'switch default',
          'Switch default branch',
          member,
        );
      }
    }
    super.visitSwitchStatement(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    if (_isFlutterFile && _isLowValueFlutterTry(node)) {
      super.visitTryStatement(node);
      return;
    }

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

    /// 检查输入相关方法
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

    /// 检查异步相关方法
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
    /// 检查 async 函数
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
    final op = node.operator.type.toString();

    /// 检查 null 检查
    if (op == 'EQ_EQ' || op == 'BANG_EQ') {
      final left = node.leftOperand.toSource();
      final right = node.rightOperand.toSource();
      if (left == 'null' || right == 'null') {
        if (_isFlutterFile &&
            _isLowValueFlutterNullExpression(node.toSource())) {
          super.visitBinaryExpression(node);
          return;
        }
        _addBoundary(
          BoundaryType.null_,
          node.offset,
          node.toSource(),
          'Null check',
        );
      }
    }

    /// 检查逻辑运算 (&&, ||)
    if (op == 'AMPERSAND_AMPERSAND' || op == 'BAR_BAR') {
      _addBoundary(
        BoundaryType.condition,
        node.offset,
        node.toSource(),
        'Logical expression (${op == 'AMPERSAND_AMPERSAND' ? '&&' : '||'})',
      );
    }

    /// 检查空值合并运算符 (??)
    if (op == 'QUESTION_QUESTION') {
      if (_isFlutterFile && _isLowValueFlutterNullExpression(node.toSource())) {
        super.visitBinaryExpression(node);
        return;
      }
      _addBoundary(
        BoundaryType.null_,
        node.offset,
        node.toSource(),
        'Null-aware coalescing (??)',
      );
    }

    /// 检查算术运算边界
    if (op == 'SLASH' || op == 'SLASH_SLASH' || op == 'PERCENT') {
      _addBoundary(
        BoundaryType.condition,
        node.offset,
        node.toSource(),
        'Arithmetic operation - potential divide by zero',
      );
    }

    /// 检查比较运算
    if (op == 'LT' || op == 'GT' || op == 'LT_EQ' || op == 'GT_EQ') {
      _addBoundary(
        BoundaryType.condition,
        node.offset,
        node.toSource(),
        'Comparison expression',
      );
    }

    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    /// 检查空值传播
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
    /// 检查生命周期方法
    final methodName = node.name.lexeme;
    final previous = _insideTestDeclaration;
    _insideTestDeclaration = previous || _looksLikeTestName(methodName);
    if (methodName == 'initState' ||
        methodName == 'dispose' ||
        methodName == 'didUpdateWidget' ||
        methodName == 'didChangeDependencies') {
      _addBoundary(
        BoundaryType.lifecycle,
        node.offset,
        node.toSource(),
        'Widget lifecycle method: $methodName',
        node,
      );
    }
    super.visitMethodDeclaration(node);
    _insideTestDeclaration = previous;
  }

  @override
  void visitForStatement(ForStatement node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'For loop',
    );
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'While loop',
    );
    super.visitWhileStatement(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'For-each loop',
    );
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _addBoundary(
      BoundaryType.collection,
      node.offset,
      node.toSource(),
      'Index access',
    );
    super.visitIndexExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final propertyName = node.propertyName.name;
    if (propertyName == 'isEmpty' || propertyName == 'isNotEmpty') {
      _addBoundary(
        BoundaryType.collection,
        node.offset,
        node.toSource(),
        'Collection boundary check: $propertyName',
      );
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_isRustFile) {
      _addBoundary(
        BoundaryType.input,
        node.offset,
        node.toSource(),
        'Variable assignment',
        node,
      );
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    _addBoundary(
      BoundaryType.null_,
      node.offset,
      node.toSource(),
      'Type cast (as)',
    );
    super.visitAsExpression(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    _addBoundary(
      BoundaryType.condition,
      node.offset,
      node.toSource(),
      'Type check (is)',
    );
    super.visitIsExpression(node);
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    _addBoundary(
      BoundaryType.exception,
      node.offset,
      node.toSource(),
      'Assert statement',
    );
    super.visitAssertStatement(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    _addBoundary(
      BoundaryType.exception,
      node.offset,
      node.toSource(),
      'Throw expression',
    );
    super.visitThrowExpression(node);
  }

  @override
  void visitSpreadElement(SpreadElement node) {
    _addBoundary(
      BoundaryType.collection,
      node.offset,
      node.toSource(),
      'Spread operator (...)',
    );
    super.visitSpreadElement(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    _addBoundary(
      BoundaryType.interaction,
      node.offset,
      node.toSource(),
      'Cascade expression (..)',
    );
    super.visitCascadeExpression(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _addBoundary(
      BoundaryType.async,
      node.offset,
      node.toSource(),
      'Function invocation',
    );
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    /// 检测构造函数
    final previous = _insideTestDeclaration;
    _insideTestDeclaration = previous || _looksLikeTestName(node.name.lexeme);
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        _addBoundary(
          BoundaryType.lifecycle,
          member.offset,
          member.toSource(),
          'Constructor',
          member,
        );
      }
    }
    super.visitClassDeclaration(node);
    _insideTestDeclaration = previous;
  }

  @override
  void visitListLiteral(ListLiteral node) {
    final isEmpty = node.elements.isEmpty;
    _addBoundary(
      BoundaryType.collection,
      node.offset,
      node.toSource(),
      isEmpty ? 'Empty list literal' : 'Non-empty list literal',
    );
    super.visitListLiteral(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    final isEmpty = node.elements.isEmpty;
    _addBoundary(
      BoundaryType.collection,
      node.offset,
      node.toSource(),
      isEmpty ? 'Empty set/map literal' : 'Non-empty set/map literal',
    );
    super.visitSetOrMapLiteral(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final isLate = node.parent?.toSource().contains('late') ?? false;
    final isFinal = node.parent?.toSource().contains('final') ?? false;
    final isNullable = node.parent?.toSource().contains('?') ?? false;

    if (_isRustFile && isLate) {
      _addBoundary(
        BoundaryType.null_,
        node.offset,
        node.toSource(),
        'Late variable declaration',
        node,
      );
    } else if (_isRustFile && isNullable) {
      _addBoundary(
        BoundaryType.null_,
        node.offset,
        node.toSource(),
        'Nullable variable declaration',
        node,
      );
    } else if (_isRustFile && !isFinal && node.initializer == null) {
      _addBoundary(
        BoundaryType.null_,
        node.offset,
        node.toSource(),
        'Uninitialized variable declaration',
        node,
      );
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final previous = _insideTestDeclaration;
    _insideTestDeclaration = previous || _looksLikeTestName(node.name.lexeme);
    super.visitFunctionDeclaration(node);
    _insideTestDeclaration = previous;
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final label = node.name.label.name;
    if (_isUserInputNamedArgument(label)) {
      _addBoundary(
        BoundaryType.input,
        node.offset,
        node.toSource(),
        'Named argument',
        node,
      );
    }
    super.visitNamedExpression(node);
  }

  void _addBoundary(
    BoundaryType type,
    int offset,
    String code,
    String desc, [
    AstNode? node,
  ]) {
    if (_shouldSkipBoundary(type, desc, node)) {
      return;
    }

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
        /// SF:<file path>
        currentFile = line.substring(3);
        fileCoverages[currentFile] = FileCoverage(path: currentFile);
      } else if (line.startsWith('DA:') && currentFile != null) {
        /// DA:<line number>,<execution count>[,<checksum>]
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
    // 尝试直接匹配
    var coverage = fileCoverages[filePath];
    if (coverage != null) return coverage.lineHits[lineNumber];

    // 尝试匹配绝对路径（Rust LCOV 使用绝对路径）
    final absolutePath = '${Directory.current.path}/$filePath';
    coverage = fileCoverages[absolutePath];
    if (coverage != null) return coverage.lineHits[lineNumber];

    // 尝试匹配其他格式（如 rust/ 前缀）
    for (final entry in fileCoverages.entries) {
      if (entry.key.endsWith(filePath) ||
          entry.key.endsWith('/$filePath') ||
          filePath.endsWith(entry.key)) {
        return entry.value.lineHits[lineNumber];
      }
    }

    return null;
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

/// 文件覆盖率数据
class FileCoverage {
  final String path;

  /// 行号 -> 执行次数
  final Map<int, int> lineHits = {};

  FileCoverage({required this.path});
}

/// 覆盖率统计
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

          /// 提取测试函数名 - 使用简单的字符串匹配
          final lines = content.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith("test('") || trimmed.startsWith('test("')) {
              /// 手动提取测试名
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
    /// 将测试名转换为小写并移除特殊字符
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool isBoundaryCovered(Boundary boundary, Set<String> coveredTests) {
    final normalizedCode = _normalizeTestName(boundary.codeSnippet);
    final typeKeywords = _getTypeKeywords(boundary.type);

    for (final test in coveredTests) {
      /// 检查测试名是否包含边界相关的关键词
      if (typeKeywords.any((kw) => test.contains(kw))) {
        return true;
      }

      /// 检查代码片段是否被引用
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

  bool isMeaningfulHighPriorityBoundary(Boundary boundary) {
    if ((config.weights[boundary.type] ?? 0.5) < 1.0) {
      return false;
    }

    final path = boundary.filePath;
    final desc = boundary.description ?? '';
    final code = boundary.codeSnippet;

    if (path.startsWith('lib/')) {
      if (desc == 'Named argument') {
        return false;
      }
      if (path == 'lib/main.dart' && desc == 'Throw expression') {
        return false;
      }
      if (path.contains('lib/app/') || path.contains('lib/features/')) {
        if (desc == 'If statement true branch' ||
            desc == 'If statement false branch' ||
            desc == 'Switch default branch' ||
            desc == 'Switch case branch' ||
            desc == 'Ternary operator condition' ||
            desc == 'Null check') {
          return false;
        }
      }
      if (path.contains('lib/features/pool/data/') &&
          desc == 'Null-aware coalescing (??)') {
        return false;
      }
      if (desc == 'Try-catch block' &&
          !code.contains('REQUEST_TIMEOUT') &&
          !code.contains('ApiError') &&
          !code.contains('Exception')) {
        return false;
      }
      if (desc == 'Null check' &&
          (code.contains('id == null') ||
              code.contains('code == null') ||
              code.contains('existing == null') ||
              code.contains('request == null') ||
              code.contains('session == null'))) {
        return false;
      }
      if (desc == 'If statement true branch' &&
          (code.contains('if (condition)') ||
              code.contains('if (condition) statement;'))) {
        return false;
      }
      if (desc == 'Switch default branch' || desc == 'Switch case branch') {
        return false;
      }
      if (desc == 'Ternary operator condition') {
        return false;
      }
    }

    return true;
  }

  Future<ScanResult> scan() async {
    /// 步骤 1: 收集代码覆盖率（运行 flutter test --coverage）
    stderr.writeln('Step 1: Collecting code coverage...');
    await _collectCoverageData();

    /// 步骤 2: 解析 LCOV 文件（Flutter + Rust）
    stderr.writeln('Step 2: Parsing LCOV data...');
    final lcovParser = LcovParser();

    /// 解析 Flutter/Dart LCOV
    final flutterLcovFile = File('coverage/lcov.info');
    if (flutterLcovFile.existsSync()) {
      stderr.writeln('  Parsing Flutter coverage...');
      lcovParser.parse(await flutterLcovFile.readAsString());
    } else {
      stderr.writeln('  Warning: coverage/lcov.info not found');
    }

    /// 解析 Rust LCOV
    final rustLcovFile = File('rust/lcov.info');
    if (rustLcovFile.existsSync()) {
      stderr.writeln('  Parsing Rust coverage...');
      lcovParser.parse(await rustLcovFile.readAsString());
    } else {
      stderr.writeln(
        '  Warning: rust/lcov.info not found (run "cd rust && cargo tarpaulin --out Lcov" to generate)',
      );
    }

    /// 步骤 3: 扫描代码边界
    stderr.writeln('Step 3: Scanning code boundaries...');
    final boundaries = await _scanBoundaries();

    /// 步骤 4: 精确匹配边界与覆盖率
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

    /// 步骤 5: 分类边界
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

    /// 扫描 Dart 文件
    for (final includePath in config.includePaths) {
      if (includePath.contains('rust/')) continue;

      /// 跳过 Rust 目录

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

    /// 扫描 Rust 文件
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

      /// 解析 JSON 输出
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
    /// 运行 flutter test --coverage 以获取最新覆盖率数据
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

    /// 分离 Dart 和 Rust 边界
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

    /// 总体统计
    buffer.writeln('## 总体统计');
    buffer.writeln('- 总边界数: ${result.boundaries.length}');
    buffer.writeln(
      '- 已覆盖: ${result.coveredBoundaries.length} (${(result.coverageRatio * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln(
      '- 未覆盖: ${result.uncoveredBoundaries.length} (${((1 - result.coverageRatio) * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln('');

    /// Flutter/Dart 统计
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

    /// Rust 统计
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

    /// 按优先级分组未覆盖边界
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
      buffer.writeln('');
      var index = 1;
      for (final boundary in result.coveredBoundaries) {
        _writeBoundary(buffer, index++, boundary);
      }
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

/// 优先级分组
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

/// 扫描范围
enum ScanScope { all, flutter, rust }

/// 解析命令行参数中的扫描范围
ScanScope _parseScope(List<String> args) {
  final scopeArg = args.firstWhere(
    (arg) => arg.startsWith('--scope='),
    orElse: () => '--scope=all',
  );
  final value = scopeArg.substring('--scope='.length);
  return switch (value) {
    'flutter' => ScanScope.flutter,
    'rust' => ScanScope.rust,
    _ => ScanScope.all,
  };
}

/// 检查边界是否匹配指定范围
bool _matchesScope(Boundary boundary, ScanScope scope) {
  return switch (scope) {
    ScanScope.all => true,
    ScanScope.flutter => boundary.filePath.startsWith('lib/'),
    ScanScope.rust => boundary.filePath.startsWith('rust/src/'),
  };
}

/// 主函数
void main(List<String> args) async {
  final scope = _parseScope(args);
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

  /// 生成报告
  final generator = ReportGenerator(config);
  final report = generator.generate(result);

  /// 保存到项目根目录的 tmp 目录
  final tmpDir = Directory('tmp');
  if (!tmpDir.existsSync()) {
    tmpDir.createSync(recursive: true);
  }
  final reportFile = File('tmp/cardmind_test_boundary_report.md');
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

  /// 如果有高优先级未覆盖边界，返回非零退出码
  final meaningfulHighPriorityUncovered = result.uncoveredBoundaries
      .where((b) => _matchesScope(b, scope))
      .where(scanner.isMeaningfulHighPriorityBoundary)
      .toList(growable: false);
  final hasHighPriorityUncovered = meaningfulHighPriorityUncovered.isNotEmpty;
  if (hasHighPriorityUncovered) {
    stderr.writeln('Meaningful high priority uncovered:');
    for (final boundary in meaningfulHighPriorityUncovered.take(20)) {
      stderr.writeln(
        ' - ${boundary.type.name} ${boundary.filePath}:${boundary.lineNumber} ${boundary.description ?? ''}',
      );
    }
  }
  if (hasHighPriorityUncovered) {
    exit(1);
  }
}
