#!/usr/bin/env dart

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
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

  Boundary({
    required this.type,
    required this.filePath,
    required this.lineNumber,
    required this.codeSnippet,
    this.description,
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

/// 主扫描器类
class TestBoundaryScanner {
  final ScannerConfig config;

  TestBoundaryScanner(this.config);

  Future<ScanResult> scan() async {
    final boundaries = <Boundary>[];

    // TODO: 实现扫描逻辑

    return ScanResult(
      boundaries: boundaries,
      coveredBoundaries: [],
      uncoveredBoundaries: boundaries,
    );
  }
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

  print('Scanning for test boundaries...');
  final result = await scanner.scan();

  print('Found ${result.boundaries.length} boundaries');
  print('Coverage: ${(result.coverageRatio * 100).toStringAsFixed(1)}%');
}
