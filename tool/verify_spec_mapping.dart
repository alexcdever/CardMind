#!/usr/bin/env dart
// Spec-Code-Test Mapping Verification Tool
// 规格-代码-测试映射验证工具

import 'dart:io';
import 'dart:convert';

void main(List<String> args) {
  print('🔍 Spec-Code-Test Mapping Verification');
  print('🔍 规格-代码-测试映射验证');
  print('=' * 60);
  print('');

  final verifier = SpecMappingVerifier();
  verifier.run();
}

class SpecMappingVerifier {
  final List<SpecMapping> rustMappings = [];
  final List<SpecMapping> flutterMappings = [];
  final List<String> missingTests = [];
  final List<String> missingSpecs = [];
  final List<String> warnings = [];

  void run() {
    print('📊 Step 1: Scanning Rust specifications...');
    print('📊 步骤 1: 扫描 Rust 规格...');
    scanRustSpecs();
    print('');

    print('📊 Step 2: Scanning Flutter specifications...');
    print('📊 步骤 2: 扫描 Flutter 规格...');
    scanFlutterSpecs();
    print('');

    print('📊 Step 3: Verifying mappings...');
    print('📊 步骤 3: 验证映射...');
    verifyMappings();
    print('');

    print('📊 Step 4: Generating report...');
    print('📊 步骤 4: 生成报告...');
    generateReport();
  }

  void scanRustSpecs() {
    // Scan openspec/specs for Rust-related specs
    final specDirs = [
      'openspec/specs/domain',
      'openspec/specs/architecture',
    ];

    for (final dir in specDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'));

      for (final file in files) {
        final content = file.readAsStringSync();
        final testFile = extractRelatedTests(content);

        if (testFile != null && testFile.startsWith('rust/')) {
          final mapping = SpecMapping(
            specNumber: null, // No longer using spec numbers
            specFile: file.path,
            testFile: testFile,
            codeFile: inferRustCodeFile(file.path),
          );
          rustMappings.add(mapping);
        }
      }
    }

    print('   Found ${rustMappings.length} Rust spec mappings');
    print('   找到 ${rustMappings.length} 个 Rust 规格映射');
  }

  void scanFlutterSpecs() {
    // Scan openspec/specs/ui and openspec/specs/features
    final specDirs = [
      'openspec/specs/ui',
      'openspec/specs/features',
    ];

    for (final dir in specDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'));

      for (final file in files) {
        final mapping = SpecMapping(
          specNumber: null,
          specFile: file.path,
          testFile: inferFlutterTestFile(file.path),
          codeFile: inferFlutterCodeFile(file.path),
        );
        flutterMappings.add(mapping);
      }
    }

    print('   Found ${flutterMappings.length} Flutter spec mappings');
    print('   找到 ${flutterMappings.length} 个 Flutter 规格映射');
  }

  void verifyMappings() {
    // Verify Rust mappings
    print('   Verifying Rust mappings...');
    print('   验证 Rust 映射...');
    for (final mapping in rustMappings) {
      if (mapping.testFile != null) {
        final testFile = File(mapping.testFile!);
        if (!testFile.existsSync()) {
          missingTests.add(
              '${mapping.specFile}: ${mapping.testFile}');
        }
      }
    }

    // Verify Flutter mappings
    print('   Verifying Flutter mappings...');
    print('   验证 Flutter 映射...');
    for (final mapping in flutterMappings) {
      if (mapping.testFile != null) {
        final testFile = File(mapping.testFile!);
        if (!testFile.existsSync()) {
          missingTests.add(
              'Flutter: ${mapping.testFile} (spec: ${mapping.specFile})');
        }
      }
    }

    // Check for tests without specs
    print('   Checking for orphaned tests...');
    print('   检查孤立的测试...');
    checkOrphanedTests();
  }

  void checkOrphanedTests() {
    // Check Rust tests
    final rustTestDir = Directory('rust/tests');
    if (rustTestDir.existsSync()) {
      final testFiles = rustTestDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.rs'));

      for (final testFile in testFiles) {
        final testPath = testFile.path;
        final hasMapping = rustMappings.any((m) => m.testFile == testPath);
        if (!hasMapping) {
          warnings.add('Orphaned Rust test: $testPath (no spec found)');
        }
      }
    }

    // Check Flutter tests
    final flutterTestDir = Directory('test/specs');
    if (flutterTestDir.existsSync()) {
      final testFiles = flutterTestDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_spec_test.dart'));

      for (final testFile in testFiles) {
        final testPath = testFile.path;
        final hasMapping = flutterMappings.any((m) => m.testFile == testPath);
        if (!hasMapping) {
          warnings.add('Orphaned Flutter test: $testPath (no spec found)');
        }
      }
    }
  }

  void generateReport() {
    print('');
    print('=' * 60);
    print('📋 VERIFICATION REPORT');
    print('📋 验证报告');
    print('=' * 60);
    print('');

    // Summary
    print('📊 Summary / 总结:');
    print('   Rust specs: ${rustMappings.length}');
    print('   Rust 规格: ${rustMappings.length}');
    print('   Flutter specs: ${flutterMappings.length}');
    print('   Flutter 规格: ${flutterMappings.length}');
    print('   Missing tests: ${missingTests.length}');
    print('   缺失测试: ${missingTests.length}');
    print('   Warnings: ${warnings.length}');
    print('   警告: ${warnings.length}');
    print('');

    // Rust coverage
    final rustWithTests =
        rustMappings.where((m) => m.testFile != null && File(m.testFile!).existsSync()).length;
    final rustCoverage = rustMappings.isEmpty
        ? 0.0
        : (rustWithTests / rustMappings.length * 100);
    print('📈 Rust Test Coverage / Rust 测试覆盖率:');
    print('   ${rustWithTests}/${rustMappings.length} (${rustCoverage.toStringAsFixed(1)}%)');
    print('');

    // Flutter coverage
    final flutterWithTests = flutterMappings
        .where((m) => m.testFile != null && File(m.testFile!).existsSync())
        .length;
    final flutterCoverage = flutterMappings.isEmpty
        ? 0.0
        : (flutterWithTests / flutterMappings.length * 100);
    print('📈 Flutter Test Coverage / Flutter 测试覆盖率:');
    print(
        '   ${flutterWithTests}/${flutterMappings.length} (${flutterCoverage.toStringAsFixed(1)}%)');
    print('');

    // Missing tests
    if (missingTests.isNotEmpty) {
      print('❌ Missing Tests / 缺失测试:');
      for (final missing in missingTests.take(10)) {
        print('   - $missing');
      }
      if (missingTests.length > 10) {
        print('   ... and ${missingTests.length - 10} more');
        print('   ... 还有 ${missingTests.length - 10} 个');
      }
      print('');
    }

    // Warnings
    if (warnings.isNotEmpty) {
      print('⚠️  Warnings / 警告:');
      for (final warning in warnings.take(10)) {
        print('   - $warning');
      }
      if (warnings.length > 10) {
        print('   ... and ${warnings.length - 10} more');
        print('   ... 还有 ${warnings.length - 10} 个');
      }
      print('');
    }

    // Status
    print('=' * 60);
    if (missingTests.isEmpty && warnings.isEmpty) {
      print('✅ All mappings verified successfully!');
      print('✅ 所有映射验证成功！');
    } else {
      print('⚠️  Issues found. See details above.');
      print('⚠️  发现问题。请查看上方详情。');
    }
    print('=' * 60);
  }

  String? extractRelatedTests(String content) {
    // Extract test file from "Related Tests" metadata
    // **Related Tests**: `rust/tests/pool_model_test.rs`
    final regex = RegExp(r'\*\*Related Tests\*\*:\s*`([^`]+)`');
    final match = regex.firstMatch(content);
    return match?.group(1);
  }

  String? inferRustCodeFile(String specPath) {
    // Infer code file from spec path
    if (specPath.contains('domain/pool')) {
      return 'rust/src/models/pool.rs';
    } else if (specPath.contains('domain/card')) {
      return 'rust/src/models/card.rs';
    } else if (specPath.contains('architecture/sync')) {
      return 'rust/src/services/sync_service.rs';
    } else if (specPath.contains('architecture/storage')) {
      return 'rust/src/store/';
    }
    return null;
  }

  String? inferFlutterTestFile(String specPath) {
    // openspec/specs/ui/screens/mobile/home_screen.md
    // -> test/specs/home_screen_spec_test.dart

    final fileName = specPath.split('/').last.replaceAll('.md', '');

    // Special cases
    if (fileName == 'card_editor_screen') {
      return 'test/specs/card_editor_spec_test.dart';
    } else if (fileName == 'home_screen') {
      return 'test/specs/home_screen_spec_test.dart';
    } else if (fileName == 'note_card') {
      return 'test/specs/note_card_component_spec_test.dart';
    } else if (fileName == 'mobile_nav') {
      return 'test/specs/mobile_navigation_spec_test.dart';
    }

    // General pattern
    return 'test/specs/${fileName}_spec_test.dart';
  }

  String? inferFlutterCodeFile(String specPath) {
    // Infer widget file from spec path
    if (specPath.contains('ui/screens')) {
      return 'lib/screens/';
    } else if (specPath.contains('ui/components')) {
      return 'lib/widgets/components/';
    } else if (specPath.contains('ui/adaptive')) {
      return 'lib/adaptive/';
    }
    return null;
  }
}

class SpecMapping {
  final String? specNumber;
  final String specFile;
  final String? testFile;
  final String? codeFile;

  SpecMapping({
    this.specNumber,
    required this.specFile,
    this.testFile,
    this.codeFile,
  });

  @override
  String toString() {
    return 'SpecMapping(spec: $specNumber, file: $specFile, test: $testFile)';
  }
}
