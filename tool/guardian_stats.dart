#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Project Guardian 统计报告生成器
///
/// 生成约束违规统计报告和趋势分析
///
/// Usage:
///   dart tool/guardian_stats.dart [--format=<format>] [--output=<path>]
///
/// Options:
///   --format=<format>  输出格式: text, json, html, markdown (默认: text)
///   --output=<path>    输出路径，默认为 stdout

import 'dart:io';
import 'dart:convert';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String bold = '\x1B[1m';

void main(List<String> arguments) async {
  // 解析参数
  String format = 'text';
  String? outputPath;

  for (final arg in arguments) {
    if (arg.startsWith('--format=')) {
      format = arg.substring('--format='.length);
    } else if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length);
    }
  }

  // 收集统计数据
  final stats = await collectStats();

  // 生成报告
  String report;
  switch (format) {
    case 'json':
      report = generateJsonReport(stats);
      break;
    case 'html':
      report = generateHtmlReport(stats);
      break;
    case 'markdown':
      report = generateMarkdownReport(stats);
      break;
    default:
      report = generateTextReport(stats);
  }

  // 输出报告
  if (outputPath != null) {
    final file = File(outputPath);
    await file.writeAsString(report);
    print('${green}✅$reset 报告已生成: $outputPath');
  } else {
    print(report);
  }
}

Future<Map<String, dynamic>> collectStats() async {
  final stats = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'config': await analyzeConfig(),
    'violations': await analyzeViolations(),
    'codebase': await analyzeCodebase(),
  };

  return stats;
}

Future<Map<String, dynamic>> analyzeConfig() async {
  final configFile = File('project-guardian.toml');
  if (!await configFile.exists()) {
    return {'exists': false};
  }

  final content = await configFile.readAsString();
  final lines = content.split('\n');

  return {
    'exists': true,
    'lines': lines.length,
    'rust_constraints': _countPattern(content, r'constraints\.code_edit\.rust'),
    'dart_constraints': _countPattern(content, r'constraints\.code_edit\.dart'),
    'forbidden_patterns': _countPattern(content, r'forbidden_patterns'),
    'required_patterns': _countPattern(content, r'required_patterns'),
    'validation_commands': _countPattern(content, r'validation_commands'),
  };
}

Future<Map<String, dynamic>> analyzeViolations() async {
  final logFile = File('.project-guardian/failures.log');
  if (!await logFile.exists()) {
    return {'total': 0, 'by_type': {}, 'by_constraint': {}};
  }

  final content = await logFile.readAsString();
  final lines = content.split('\n');

  final violations = <String, int>{};
  final constraints = <String, int>{};

  for (final line in lines) {
    if (line.contains('[ERROR]')) {
      violations['ERROR'] = (violations['ERROR'] ?? 0) + 1;
    } else if (line.contains('[WARN]')) {
      violations['WARN'] = (violations['WARN'] ?? 0) + 1;
    }

    if (line.contains('约束:')) {
      final match = RegExp(r'约束: (.+)').firstMatch(line);
      if (match != null) {
        final constraint = match.group(1)!;
        constraints[constraint] = (constraints[constraint] ?? 0) + 1;
      }
    }
  }

  return {
    'total': violations.values.fold(0, (a, b) => a + b),
    'by_type': violations,
    'by_constraint': constraints,
  };
}

Future<Map<String, dynamic>> analyzeCodebase() async {
  final rustStats = await _analyzeRustCode();
  final dartStats = await _analyzeDartCode();

  return {'rust': rustStats, 'dart': dartStats};
}

Future<Map<String, dynamic>> _analyzeRustCode() async {
  final rustDir = Directory('rust/src');
  if (!await rustDir.exists()) {
    return {'exists': false};
  }

  int fileCount = 0;
  int lineCount = 0;
  int unwrapCount = 0;
  int expectCount = 0;
  int panicCount = 0;

  await for (final entity in rustDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.rs')) {
      fileCount++;
      final content = await entity.readAsString();
      final lines = content.split('\n');
      lineCount += lines.length;

      unwrapCount += _countPattern(content, r'\.unwrap\(\)');
      expectCount += _countPattern(content, r'\.expect\(');
      panicCount += _countPattern(content, r'panic!');
    }
  }

  return {
    'exists': true,
    'files': fileCount,
    'lines': lineCount,
    'unwrap_count': unwrapCount,
    'expect_count': expectCount,
    'panic_count': panicCount,
  };
}

Future<Map<String, dynamic>> _analyzeDartCode() async {
  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    return {'exists': false};
  }

  int fileCount = 0;
  int lineCount = 0;
  int printCount = 0;
  int todoCount = 0;

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      fileCount++;
      final content = await entity.readAsString();
      final lines = content.split('\n');
      lineCount += lines.length;

      printCount += _countPattern(content, r'print\(');
      todoCount += _countPattern(content, r'// TODO:');
    }
  }

  return {
    'exists': true,
    'files': fileCount,
    'lines': lineCount,
    'print_count': printCount,
    'todo_count': todoCount,
  };
}

int _countPattern(String content, String pattern) {
  return RegExp(pattern).allMatches(content).length;
}

String generateTextReport(Map<String, dynamic> stats) {
  final buffer = StringBuffer();

  buffer.writeln('$bold$blue${"=" * 70}');
  buffer.writeln('  🛡️  Project Guardian - 统计报告');
  buffer.writeln('${"=" * 70}$reset');
  buffer.writeln();

  buffer.writeln('${bold}生成时间:$reset ${stats['timestamp']}');
  buffer.writeln();

  // 配置统计
  buffer.writeln('${bold}${blue}━━━ 配置统计 ━━━$reset');
  final config = stats['config'] as Map<String, dynamic>;
  if (config['exists'] == true) {
    buffer.writeln('配置文件: ${green}存在$reset (${config['lines']} 行)');
    buffer.writeln('Rust 约束: ${config['rust_constraints']}');
    buffer.writeln('Dart 约束: ${config['dart_constraints']}');
    buffer.writeln('禁止模式: ${config['forbidden_patterns']}');
    buffer.writeln('必须模式: ${config['required_patterns']}');
    buffer.writeln('验证命令: ${config['validation_commands']}');
  } else {
    buffer.writeln('配置文件: ${red}不存在$reset');
  }
  buffer.writeln();

  // 违规统计
  buffer.writeln('${bold}${blue}━━━ 违规统计 ━━━$reset');
  final violations = stats['violations'] as Map<String, dynamic>;
  buffer.writeln('总违规数: ${violations['total']}');

  if (violations['total'] > 0) {
    buffer.writeln();
    buffer.writeln('按类型:');
    final byType = violations['by_type'] as Map<String, dynamic>;
    for (final entry in byType.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }

    buffer.writeln();
    buffer.writeln('按约束:');
    final byConstraint = violations['by_constraint'] as Map<String, dynamic>;
    for (final entry in byConstraint.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
  }
  buffer.writeln();

  // 代码库统计
  buffer.writeln('${bold}${blue}━━━ 代码库统计 ━━━$reset');
  final codebase = stats['codebase'] as Map<String, dynamic>;

  // Rust 统计
  final rust = codebase['rust'] as Map<String, dynamic>;
  if (rust['exists'] == true) {
    buffer.writeln('${bold}Rust:$reset');
    buffer.writeln('  文件数: ${rust['files']}');
    buffer.writeln('  代码行数: ${rust['lines']}');
    buffer.writeln('  unwrap() 使用: ${rust['unwrap_count']}');
    buffer.writeln('  expect() 使用: ${rust['expect_count']}');
    buffer.writeln('  panic! 使用: ${rust['panic_count']}');
  } else {
    buffer.writeln('${bold}Rust:$reset ${yellow}未找到$reset');
  }
  buffer.writeln();

  // Dart 统计
  final dart = codebase['dart'] as Map<String, dynamic>;
  if (dart['exists'] == true) {
    buffer.writeln('${bold}Dart:$reset');
    buffer.writeln('  文件数: ${dart['files']}');
    buffer.writeln('  代码行数: ${dart['lines']}');
    buffer.writeln('  print() 使用: ${dart['print_count']}');
    buffer.writeln('  TODO 注释: ${dart['todo_count']}');
  } else {
    buffer.writeln('${bold}Dart:$reset ${yellow}未找到$reset');
  }
  buffer.writeln();

  // 健康评分
  buffer.writeln('${bold}${blue}━━━ 健康评分 ━━━$reset');
  final score = calculateHealthScore(stats);
  final scoreColor = score >= 80
      ? green
      : score >= 60
      ? yellow
      : red;
  buffer.writeln('总分: $scoreColor$score/100$reset');
  buffer.writeln();

  buffer.writeln('${"=" * 70}');

  return buffer.toString();
}

String generateJsonReport(Map<String, dynamic> stats) {
  final encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(stats);
}

String generateMarkdownReport(Map<String, dynamic> stats) {
  final buffer = StringBuffer();

  buffer.writeln('# 🛡️ Project Guardian - 统计报告');
  buffer.writeln();
  buffer.writeln('**生成时间**: ${stats['timestamp']}');
  buffer.writeln();

  // 配置统计
  buffer.writeln('## 📊 配置统计');
  buffer.writeln();
  final config = stats['config'] as Map<String, dynamic>;
  if (config['exists'] == true) {
    buffer.writeln('| 项目 | 数量 |');
    buffer.writeln('|------|------|');
    buffer.writeln('| 配置文件行数 | ${config['lines']} |');
    buffer.writeln('| Rust 约束 | ${config['rust_constraints']} |');
    buffer.writeln('| Dart 约束 | ${config['dart_constraints']} |');
    buffer.writeln('| 禁止模式 | ${config['forbidden_patterns']} |');
    buffer.writeln('| 必须模式 | ${config['required_patterns']} |');
    buffer.writeln('| 验证命令 | ${config['validation_commands']} |');
  } else {
    buffer.writeln('⚠️ 配置文件不存在');
  }
  buffer.writeln();

  // 违规统计
  buffer.writeln('## 🚨 违规统计');
  buffer.writeln();
  final violations = stats['violations'] as Map<String, dynamic>;
  buffer.writeln('**总违规数**: ${violations['total']}');
  buffer.writeln();

  if (violations['total'] > 0) {
    buffer.writeln('### 按类型');
    buffer.writeln();
    buffer.writeln('| 类型 | 数量 |');
    buffer.writeln('|------|------|');
    final byType = violations['by_type'] as Map<String, dynamic>;
    for (final entry in byType.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer.writeln();

    buffer.writeln('### 按约束');
    buffer.writeln();
    buffer.writeln('| 约束 | 数量 |');
    buffer.writeln('|------|------|');
    final byConstraint = violations['by_constraint'] as Map<String, dynamic>;
    for (final entry in byConstraint.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer.writeln();
  }

  // 代码库统计
  buffer.writeln('## 📁 代码库统计');
  buffer.writeln();
  final codebase = stats['codebase'] as Map<String, dynamic>;

  // Rust
  final rust = codebase['rust'] as Map<String, dynamic>;
  if (rust['exists'] == true) {
    buffer.writeln('### Rust');
    buffer.writeln();
    buffer.writeln('| 指标 | 数量 |');
    buffer.writeln('|------|------|');
    buffer.writeln('| 文件数 | ${rust['files']} |');
    buffer.writeln('| 代码行数 | ${rust['lines']} |');
    buffer.writeln('| unwrap() 使用 | ${rust['unwrap_count']} |');
    buffer.writeln('| expect() 使用 | ${rust['expect_count']} |');
    buffer.writeln('| panic! 使用 | ${rust['panic_count']} |');
    buffer.writeln();
  }

  // Dart
  final dart = codebase['dart'] as Map<String, dynamic>;
  if (dart['exists'] == true) {
    buffer.writeln('### Dart');
    buffer.writeln();
    buffer.writeln('| 指标 | 数量 |');
    buffer.writeln('|------|------|');
    buffer.writeln('| 文件数 | ${dart['files']} |');
    buffer.writeln('| 代码行数 | ${dart['lines']} |');
    buffer.writeln('| print() 使用 | ${dart['print_count']} |');
    buffer.writeln('| TODO 注释 | ${dart['todo_count']} |');
    buffer.writeln();
  }

  // 健康评分
  buffer.writeln('## 💯 健康评分');
  buffer.writeln();
  final score = calculateHealthScore(stats);
  buffer.writeln('**总分**: $score/100');
  buffer.writeln();

  return buffer.toString();
}

String generateHtmlReport(Map<String, dynamic> stats) {
  final score = calculateHealthScore(stats);
  final scoreColor = score >= 80
      ? '#4CAF50'
      : score >= 60
      ? '#FF9800'
      : '#F44336';

  return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Project Guardian - 统计报告</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            margin: 0;
            font-size: 2em;
        }
        .header .timestamp {
            opacity: 0.9;
            margin-top: 10px;
        }
        .section {
            background: white;
            padding: 25px;
            margin-bottom: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .stat-card .label {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 5px;
        }
        .stat-card .value {
            font-size: 1.8em;
            font-weight: bold;
            color: #333;
        }
        .score-circle {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: $scoreColor;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2.5em;
            font-weight: bold;
            margin: 20px auto;
            box-shadow: 0 4px 6px rgba(0,0,0,0.2);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #667eea;
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .badge-success { background: #4CAF50; color: white; }
        .badge-warning { background: #FF9800; color: white; }
        .badge-danger { background: #F44336; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ Project Guardian - 统计报告</h1>
        <div class="timestamp">生成时间: ${stats['timestamp']}</div>
    </div>

    <div class="section">
        <h2>💯 健康评分</h2>
        <div class="score-circle">$score</div>
        <p style="text-align: center; color: #666;">总分: $score/100</p>
    </div>

    <div class="section">
        <h2>📊 配置统计</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">配置文件行数</div>
                <div class="value">${stats['config']['lines'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">Rust 约束</div>
                <div class="value">${stats['config']['rust_constraints'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">Dart 约束</div>
                <div class="value">${stats['config']['dart_constraints'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">禁止模式</div>
                <div class="value">${stats['config']['forbidden_patterns'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">必须模式</div>
                <div class="value">${stats['config']['required_patterns'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">验证命令</div>
                <div class="value">${stats['config']['validation_commands'] ?? 0}</div>
            </div>
        </div>
    </div>

    <div class="section">
        <h2>🚨 违规统计</h2>
        <div class="stat-card">
            <div class="label">总违规数</div>
            <div class="value">${stats['violations']['total']}</div>
        </div>
    </div>

    <div class="section">
        <h2>📁 代码库统计</h2>
        <h3>Rust</h3>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">文件数</div>
                <div class="value">${stats['codebase']['rust']['files'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">代码行数</div>
                <div class="value">${stats['codebase']['rust']['lines'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">unwrap() 使用</div>
                <div class="value">${stats['codebase']['rust']['unwrap_count'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">panic! 使用</div>
                <div class="value">${stats['codebase']['rust']['panic_count'] ?? 0}</div>
            </div>
        </div>

        <h3>Dart</h3>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">文件数</div>
                <div class="value">${stats['codebase']['dart']['files'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">代码行数</div>
                <div class="value">${stats['codebase']['dart']['lines'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">print() 使用</div>
                <div class="value">${stats['codebase']['dart']['print_count'] ?? 0}</div>
            </div>
            <div class="stat-card">
                <div class="label">TODO 注释</div>
                <div class="value">${stats['codebase']['dart']['todo_count'] ?? 0}</div>
            </div>
        </div>
    </div>

    <footer style="text-align: center; color: #666; margin-top: 40px; padding: 20px;">
        <p>Generated by Project Guardian</p>
    </footer>
</body>
</html>
''';
}

int calculateHealthScore(Map<String, dynamic> stats) {
  int score = 100;

  // 违规扣分
  final violations = stats['violations'] as Map<String, dynamic>;
  final totalViolations = violations['total'] as int;
  score -= (totalViolations * 2).clamp(0, 40);

  // Rust 代码质量
  final rust = stats['codebase']['rust'] as Map<String, dynamic>;
  if (rust['exists'] == true) {
    final unwrapCount = rust['unwrap_count'] as int;
    final panicCount = rust['panic_count'] as int;
    score -= ((unwrapCount + panicCount) * 0.1).round().clamp(0, 20);
  }

  // Dart 代码质量
  final dart = stats['codebase']['dart'] as Map<String, dynamic>;
  if (dart['exists'] == true) {
    final printCount = dart['print_count'] as int;
    final todoCount = dart['todo_count'] as int;
    score -= ((printCount + todoCount) * 0.1).round().clamp(0, 20);
  }

  return score.clamp(0, 100);
}
