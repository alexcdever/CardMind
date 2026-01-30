#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// 测试-规格映射验证工具
///
/// 验证测试文件和规格文档之间的映射关系，确保：
/// 1. 每个规格文档都有对应的测试文件
/// 2. 每个测试文件都引用了正确的规格编号
/// 3. 规格文档中的 Test Implementation 章节是最新的

import 'dart:io';

void main(List<String> args) {
  print('🔍 测试-规格映射验证工具\n');

  final validator = TestSpecValidator();
  final results = validator.validate();

  // 打印结果
  _printResults(results);

  // 如果有错误，退出码为 1
  if (results.hasErrors) {
    exit(1);
  }
}

class TestSpecValidator {
  final String specsDir = 'openspec/specs';
  final String testsDir = 'test/specs';

  ValidationResults validate() {
    final results = ValidationResults();

    print('📋 扫描规格文档...');
    final specs = _scanSpecs();
    print('   找到 ${specs.length} 个规格文档\n');

    print('🧪 扫描测试文件...');
    final tests = _scanTests();
    print('   找到 ${tests.length} 个测试文件\n');

    print('🔗 验证映射关系...\n');

    // 验证每个规格是否有对应的测试
    for (final spec in specs) {
      _validateSpec(spec, tests, results);
    }

    // 验证每个测试是否引用了正确的规格
    for (final test in tests) {
      _validateTest(test, specs, results);
    }

    return results;
  }

  List<SpecDoc> _scanSpecs() {
    final specs = <SpecDoc>[];
    final specsDirectory = Directory(specsDir);

    if (!specsDirectory.existsSync()) {
      print('⚠️  规格目录不存在: $specsDir');
      return specs;
    }

    // 递归扫描所有 .md 文件
    final files = specsDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'));

    for (final file in files) {
      final content = file.readAsStringSync();
      final specId = _extractSpecId(content);

      if (specId != null) {
        specs.add(SpecDoc(path: file.path, specId: specId, content: content));
      }
    }

    return specs;
  }

  List<TestFile> _scanTests() {
    final tests = <TestFile>[];
    final testsDirectory = Directory(testsDir);

    if (!testsDirectory.existsSync()) {
      print('⚠️  测试目录不存在: $testsDir');
      return tests;
    }

    final files = testsDirectory.listSync().whereType<File>().where(
      (f) => f.path.endsWith('_test.dart'),
    );

    for (final file in files) {
      final content = file.readAsStringSync();
      final specIds = _extractSpecIdsFromTest(content);

      tests.add(TestFile(path: file.path, specIds: specIds, content: content));
    }

    return tests;
  }

  String? _extractSpecId(String content) {
    // 匹配规格编号格式：SP-XXX-XXX 或 规格编号: SP-XXX-XXX
    final patterns = [
      RegExp(r'规格编号:\s*(SP-[A-Z]+-\d+)'),
      RegExp(r'##\s*📋\s*规格编号:\s*(SP-[A-Z]+-\d+)'),
      RegExp(r'Specification:\s*(SP-[A-Z]+-\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  List<String> _extractSpecIdsFromTest(String content) {
    final specIds = <String>[];

    // 匹配测试文件中的规格编号
    final patterns = [
      RegExp(r'规格编号:\s*(SP-[A-Z]+-\d+)'),
      RegExp(r"group\('(SP-[A-Z]+-\d+)"),
      RegExp(r'//\s*(SP-[A-Z]+-\d+)'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final specId = match.group(1);
        if (specId != null && !specIds.contains(specId)) {
          specIds.add(specId);
        }
      }
    }

    return specIds;
  }

  void _validateSpec(
    SpecDoc spec,
    List<TestFile> tests,
    ValidationResults results,
  ) {
    // 查找引用此规格的测试文件
    final relatedTests = tests
        .where((t) => t.specIds.contains(spec.specId))
        .toList();

    if (relatedTests.isEmpty) {
      results.addWarning('规格 ${spec.specId} 没有对应的测试文件', spec.path);
    } else {
      // 检查规格文档是否有 Test Implementation 章节
      if (!spec.content.contains('Test Implementation') &&
          !spec.content.contains('测试实现')) {
        results.addWarning(
          '规格 ${spec.specId} 缺少 Test Implementation 章节',
          spec.path,
        );
      }

      results.addSuccess(
        '规格 ${spec.specId} 有 ${relatedTests.length} 个测试文件',
        spec.path,
      );
    }
  }

  void _validateTest(
    TestFile test,
    List<SpecDoc> specs,
    ValidationResults results,
  ) {
    if (test.specIds.isEmpty) {
      results.addWarning('测试文件没有引用任何规格编号', test.path);
      return;
    }

    for (final specId in test.specIds) {
      final relatedSpec = specs.where((s) => s.specId == specId).firstOrNull;

      if (relatedSpec == null) {
        results.addError('测试引用的规格 $specId 不存在', test.path);
      } else {
        results.addSuccess('测试正确引用规格 $specId', test.path);
      }
    }
  }
}

class SpecDoc {
  final String path;
  final String specId;
  final String content;

  SpecDoc({required this.path, required this.specId, required this.content});
}

class TestFile {
  final String path;
  final List<String> specIds;
  final String content;

  TestFile({required this.path, required this.specIds, required this.content});
}

class ValidationResults {
  final List<ValidationMessage> messages = [];

  void addSuccess(String message, String path) {
    messages.add(
      ValidationMessage(
        type: MessageType.success,
        message: message,
        path: path,
      ),
    );
  }

  void addWarning(String message, String path) {
    messages.add(
      ValidationMessage(
        type: MessageType.warning,
        message: message,
        path: path,
      ),
    );
  }

  void addError(String message, String path) {
    messages.add(
      ValidationMessage(type: MessageType.error, message: message, path: path),
    );
  }

  bool get hasErrors => messages.any((m) => m.type == MessageType.error);
  bool get hasWarnings => messages.any((m) => m.type == MessageType.warning);

  int get errorCount =>
      messages.where((m) => m.type == MessageType.error).length;
  int get warningCount =>
      messages.where((m) => m.type == MessageType.warning).length;
  int get successCount =>
      messages.where((m) => m.type == MessageType.success).length;
}

class ValidationMessage {
  final MessageType type;
  final String message;
  final String path;

  ValidationMessage({
    required this.type,
    required this.message,
    required this.path,
  });
}

enum MessageType { success, warning, error }

void _printResults(ValidationResults results) {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 验证结果\n');

  // 按类型分组打印
  final errors = results.messages.where((m) => m.type == MessageType.error);
  final warnings = results.messages.where((m) => m.type == MessageType.warning);
  final successes = results.messages.where(
    (m) => m.type == MessageType.success,
  );

  if (errors.isNotEmpty) {
    print('❌ 错误 (${errors.length}):');
    for (final msg in errors) {
      print('   ${msg.message}');
      print('   📄 ${msg.path}\n');
    }
  }

  if (warnings.isNotEmpty) {
    print('⚠️  警告 (${warnings.length}):');
    for (final msg in warnings) {
      print('   ${msg.message}');
      print('   📄 ${msg.path}\n');
    }
  }

  if (successes.isNotEmpty && errors.isEmpty && warnings.isEmpty) {
    print('✅ 所有验证通过 (${successes.length}):');
    for (final msg in successes.take(5)) {
      print('   ${msg.message}');
    }
    if (successes.length > 5) {
      print('   ... 还有 ${successes.length - 5} 个成功项');
    }
    print('');
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📈 统计:');
  print('   ✅ 成功: ${results.successCount}');
  print('   ⚠️  警告: ${results.warningCount}');
  print('   ❌ 错误: ${results.errorCount}');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  if (results.hasErrors) {
    print('❌ 验证失败！请修复上述错误。\n');
  } else if (results.hasWarnings) {
    print('⚠️  验证通过，但有警告。建议修复警告项。\n');
  } else {
    print('✅ 验证完全通过！所有测试-规格映射正确。\n');
  }
}
