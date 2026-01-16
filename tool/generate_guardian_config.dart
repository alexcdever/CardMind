#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Project Guardian 配置模板生成器
///
/// 用于为新项目快速生成 project-guardian.toml 配置文件
///
/// Usage:
///   dart tool/generate_guardian_config.dart [--project-type=<type>] [--output=<path>]
///
/// Options:
///   --project-type=<type>  项目类型: rust, dart, flutter, flutter-rust, python, nodejs
///   --output=<path>        输出路径，默认为 project-guardian.toml

import 'dart:io';

const String reset = '\x1B[0m';
const String red = '\x1B[31m';
const String green = '\x1B[32m';
const String yellow = '\x1B[33m';
const String blue = '\x1B[34m';
const String bold = '\x1B[1m';

void main(List<String> arguments) {
  printHeader('🛡️  Project Guardian - 配置生成器');

  // 解析参数
  String? projectType;
  String outputPath = 'project-guardian.toml';

  for (final arg in arguments) {
    if (arg.startsWith('--project-type=')) {
      projectType = arg.substring('--project-type='.length);
    } else if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length);
    }
  }

  // 如果没有指定项目类型，交互式询问
  if (projectType == null) {
    projectType = promptProjectType();
  }

  // 验证项目类型
  if (!isValidProjectType(projectType)) {
    printError('无效的项目类型: $projectType');
    printInfo('支持的类型: rust, dart, flutter, flutter-rust, python, nodejs');
    exit(1);
  }

  // 生成配置
  printInfo('生成配置文件...');
  printInfo('项目类型: $projectType');
  printInfo('输出路径: $outputPath');
  print('');

  final config = generateConfig(projectType);

  // 写入文件
  final file = File(outputPath);
  file.writeAsStringSync(config);

  printSuccess('配置文件已生成: $outputPath');
  print('');
  printInfo('下一步:');
  print('1. 查看并编辑配置文件');
  print('2. 创建经验库目录: mkdir -p .project-guardian');
  print('3. 运行验证: dart tool/validate_constraints.dart');
}

String promptProjectType() {
  print('');
  print('请选择项目类型:');
  print('  1. Rust');
  print('  2. Dart');
  print('  3. Flutter');
  print('  4. Flutter + Rust (混合项目)');
  print('  5. Python');
  print('  6. Node.js');
  print('');
  stdout.write('请输入选项 (1-6): ');

  final input = stdin.readLineSync();
  switch (input) {
    case '1':
      return 'rust';
    case '2':
      return 'dart';
    case '3':
      return 'flutter';
    case '4':
      return 'flutter-rust';
    case '5':
      return 'python';
    case '6':
      return 'nodejs';
    default:
      printError('无效的选项');
      exit(1);
  }
}

bool isValidProjectType(String type) {
  return ['rust', 'dart', 'flutter', 'flutter-rust', 'python', 'nodejs']
      .contains(type);
}

String generateConfig(String projectType) {
  final projectName = promptProjectName();

  switch (projectType) {
    case 'rust':
      return generateRustConfig(projectName);
    case 'dart':
      return generateDartConfig(projectName);
    case 'flutter':
      return generateFlutterConfig(projectName);
    case 'flutter-rust':
      return generateFlutterRustConfig(projectName);
    case 'python':
      return generatePythonConfig(projectName);
    case 'nodejs':
      return generateNodeJsConfig(projectName);
    default:
      return generateGenericConfig(projectName);
  }
}

String promptProjectName() {
  stdout.write('请输入项目名称: ');
  final name = stdin.readLineSync();
  return name?.trim() ?? 'MyProject';
}

String generateRustConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Rust 项目配置

[project]
name = "$projectName"
type = "rust"
description = "Rust project with Project Guardian"

[constraints.code_edit.rust]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = [
  { pattern = "unwrap\\\\(\\\\)", message = "❌ 禁止使用 unwrap()，使用 ? 或 match 处理错误" },
  { pattern = "expect\\\\(", message = "❌ 禁止使用 expect()，使用 ? 或 match 处理错误" },
  { pattern = "panic!", message = "❌ 禁止在生产代码中使用 panic!，使用 Result 返回错误" },
  { pattern = "todo!", message = "❌ 禁止提交包含 todo!() 的代码" },
  { pattern = "unimplemented!", message = "❌ 禁止提交包含 unimplemented!() 的代码" },
]

# 必须包含的模式
required_patterns = [
  { pattern = "Result<.*,.*Error>", message = "✅ API 函数必须返回 Result 类型" },
  { pattern = "#\\\\[derive\\\\(.*Debug", message = "✅ 数据模型必须实现 Debug trait" },
]

# 验证命令
validation_commands = [
  "cargo check",
  "cargo clippy --all-targets --all-features -- -D warnings",
  "cargo test --all-features",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ 没有使用 unwrap()、expect()、panic!()",
  "✅ 所有 API 函数返回 Result 类型",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generateDartConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Dart 项目配置

[project]
name = "$projectName"
type = "dart"
description = "Dart project with Project Guardian"

[constraints.code_edit.dart]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = [
  { pattern = "print\\\\(", message = "❌ 使用 debugPrint() 或 logger，不要使用 print()" },
  { pattern = "// TODO:", message = "❌ 禁止提交包含 TODO 注释的代码" },
  { pattern = "// FIXME:", message = "❌ 禁止提交包含 FIXME 注释的代码" },
]

# 必须包含的模式
required_patterns = []

# 验证命令
validation_commands = [
  "dart analyze",
  "dart test",
  "dart format --set-exit-if-changed .",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ 没有提交 TODO/FIXME 注释",
  "✅ 代码格式正确",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generateFlutterConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Flutter 项目配置

[project]
name = "$projectName"
type = "flutter"
description = "Flutter project with Project Guardian"

[constraints.code_edit.dart]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = [
  { pattern = "print\\\\(", message = "❌ 使用 debugPrint()，不要使用 print()" },
  { pattern = "// TODO:", message = "❌ 禁止提交包含 TODO 注释的代码" },
  { pattern = "// FIXME:", message = "❌ 禁止提交包含 FIXME 注释的代码" },
]

# 必须包含的模式
required_patterns = [
  { pattern = "const.*\\\\{Key\\\\? key\\\\}", message = "✅ Widget 构造函数必须有 key 参数" },
  { pattern = "if \\\\(!mounted\\\\) return", message = "✅ 异步操作后必须检查 mounted 状态" },
]

# 验证命令
validation_commands = [
  "flutter analyze",
  "flutter test",
  "dart format --set-exit-if-changed .",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ Widget 有 key 参数",
  "✅ 异步操作检查 mounted",
  "✅ 没有提交 TODO/FIXME 注释",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generateFlutterRustConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Flutter + Rust 混合项目配置

[project]
name = "$projectName"
type = "flutter-rust"
description = "Flutter + Rust hybrid project with Project Guardian"

# Rust 代码约束
[constraints.code_edit.rust]
architecture_doc = "docs/architecture.md"

forbidden_patterns = [
  { pattern = "unwrap\\\\(\\\\)", message = "❌ 禁止使用 unwrap()，使用 ? 或 match 处理错误" },
  { pattern = "expect\\\\(", message = "❌ 禁止使用 expect()，使用 ? 或 match 处理错误" },
  { pattern = "panic!", message = "❌ 禁止在生产代码中使用 panic!，使用 Result 返回错误" },
  { pattern = "todo!", message = "❌ 禁止提交包含 todo!() 的代码" },
]

required_patterns = [
  { pattern = "Result<.*,.*Error>", message = "✅ API 函数必须返回 Result 类型" },
  { pattern = "#\\\\[derive\\\\(.*Debug", message = "✅ 数据模型必须实现 Debug trait" },
]

validation_commands = [
  "cd rust && cargo check",
  "cd rust && cargo clippy --all-targets --all-features -- -D warnings",
  "cd rust && cargo test --all-features",
]

# Dart/Flutter 代码约束
[constraints.code_edit.dart]
architecture_doc = "docs/architecture.md"

forbidden_patterns = [
  { pattern = "print\\\\(", message = "❌ 使用 debugPrint()，不要使用 print()" },
  { pattern = "// TODO:", message = "❌ 禁止提交包含 TODO 注释的代码" },
]

required_patterns = [
  { pattern = "const.*\\\\{Key\\\\? key\\\\}", message = "✅ Widget 构造函数必须有 key 参数" },
  { pattern = "if \\\\(!mounted\\\\) return", message = "✅ 异步操作后必须检查 mounted 状态" },
]

validation_commands = [
  "flutter analyze",
  "flutter test",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ Rust: 没有使用 unwrap()、expect()、panic!()",
  "✅ Rust: 所有 API 函数返回 Result 类型",
  "✅ Dart: Widget 有 key 参数",
  "✅ Dart: 异步操作检查 mounted",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generatePythonConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Python 项目配置

[project]
name = "$projectName"
type = "python"
description = "Python project with Project Guardian"

[constraints.code_edit.python]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = [
  { pattern = "print\\\\(", message = "❌ 使用 logger，不要使用 print()" },
  { pattern = "# TODO:", message = "❌ 禁止提交包含 TODO 注释的代码" },
  { pattern = "# FIXME:", message = "❌ 禁止提交包含 FIXME 注释的代码" },
  { pattern = "except:", message = "❌ 禁止使用裸 except，指定异常类型" },
]

# 必须包含的模式
required_patterns = []

# 验证命令
validation_commands = [
  "pytest",
  "black --check .",
  "flake8",
  "mypy .",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ 使用 logger 而非 print",
  "✅ 异常处理指定类型",
  "✅ 类型注解完整",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generateNodeJsConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# Node.js 项目配置

[project]
name = "$projectName"
type = "nodejs"
description = "Node.js project with Project Guardian"

[constraints.code_edit.javascript]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = [
  { pattern = "console\\\\.log\\\\(", message = "❌ 使用 logger，不要使用 console.log()" },
  { pattern = "// TODO:", message = "❌ 禁止提交包含 TODO 注释的代码" },
  { pattern = "// FIXME:", message = "❌ 禁止提交包含 FIXME 注释的代码" },
  { pattern = "var ", message = "❌ 使用 const 或 let，不要使用 var" },
]

# 必须包含的模式
required_patterns = []

# 验证命令
validation_commands = [
  "npm run lint",
  "npm test",
  "npm run type-check",
]

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过（0 错误，0 警告）",
  "✅ 测试覆盖率 >80%（新代码）",
  "✅ 使用 logger 而非 console.log",
  "✅ 使用 const/let 而非 var",
  "✅ TypeScript 类型完整",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

String generateGenericConfig(String projectName) {
  return '''
# Project Guardian Configuration for $projectName
# 通用项目配置

[project]
name = "$projectName"
type = "generic"
description = "Generic project with Project Guardian"

[constraints.code_edit]
architecture_doc = "docs/architecture.md"

# 禁止模式
forbidden_patterns = []

# 必须包含的模式
required_patterns = []

# 验证命令
validation_commands = []

[constraints.submission]
required_checklist = [
  "✅ 所有验证命令通过",
  "✅ 测试覆盖率 >80%（新代码）",
]

require_human_review = false

[experience]
anti_patterns_file = ".project-guardian/anti-patterns.md"
best_practices_file = ".project-guardian/best-practices.md"
failure_log = ".project-guardian/failures.log"
''';
}

// 打印辅助函数
void printHeader(String message) {
  print('\n$bold$blue${"=" * 60}');
  print('  $message');
  print('${"=" * 60}$reset\n');
}

void printInfo(String message) {
  print('$blue ℹ $reset$message');
}

void printSuccess(String message) {
  print('$green✅ $reset$message');
}

void printError(String message) {
  print('$red❌ $reset$message');
}
