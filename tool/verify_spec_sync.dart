#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// 规格与代码同步验证工具
///
/// 验证 CardMind 项目中的规格文档与实际代码实现的同步性
/// 包括三层检查：覆盖率检查、结构验证、迁移验证
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'scope',
      abbr: 's',
      help: 'Scope of verification: all, domain, features',
      defaultsTo: 'all',
      allowed: ['all', 'domain', 'features'],
    )
    ..addOption(
      'module',
      abbr: 'm',
      help: 'Verify specific module only (e.g., card_store)',
    )
    ..addFlag('help', abbr: 'h', help: 'Show usage help', negatable: false)
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }

    final scope = results['scope'] as String;
    final module = results['module'] as String?;
    final verbose = results['verbose'] as bool;

    print('🔍 规格与代码同步验证工具');
    print('');
    print('范围: $scope');
    if (module != null) {
      print('模块: $module');
    }
    print('');

    // 获取项目根目录
    final projectRoot = _findProjectRoot();
    if (projectRoot == null) {
      print('❌ 错误: 无法找到项目根目录');
      exit(1);
    }

    if (verbose) {
      print('项目根目录: $projectRoot');
      print('');
    }

    // 创建验证器实例
    final verifier = SpecSyncVerifier(projectRoot, verbose: verbose);

    // 执行验证
    final report = await verifier.verify(scope: scope, module: module);

    // 生成报告
    await _generateReports(report, projectRoot);

    // 输出总结
    _printSummary(report);

    // 根据结果设置退出码
    if (report.criticalIssues > 0) {
      exit(1);
    }
  } catch (e) {
    print('❌ 错误: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('用法: dart tool/verify_spec_sync.dart [options]');
  print('');
  print('验证规格文档与代码实现的同步性');
  print('');
  print('选项:');
  print(parser.usage);
  print('');
  print('示例:');
  print('  dart tool/verify_spec_sync.dart                    # 全量验证');
  print('  dart tool/verify_spec_sync.dart --scope=domain     # 仅验证领域模块');
  print('  dart tool/verify_spec_sync.dart --module=card_store # 仅验证指定模块');
}

String? _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    // 检查是否存在 pubspec.yaml（Flutter 项目标识）
    if (File(path.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    // 到达文件系统根目录
    if (dir.parent.path == dir.path) {
      return null;
    }
    dir = dir.parent;
  }
}

Future<void> _generateReports(
  VerificationReport report,
  String projectRoot,
) async {
  // Markdown 报告
  final mdReportPath = path.join(projectRoot, 'SPEC_SYNC_REPORT.md');
  final mdContent = _generateMarkdownReport(report);
  await File(mdReportPath).writeAsString(mdContent);
  print('📄 Markdown 报告已生成: $mdReportPath');

  // JSON 报告
  final jsonReportPath = path.join(projectRoot, 'spec_sync_report.json');
  final jsonContent = jsonEncode(report.toJson());
  await File(jsonReportPath).writeAsString(jsonContent);
  print('📄 JSON 报告已生成: $jsonReportPath');
}

String _generateMarkdownReport(VerificationReport report) {
  final buffer = StringBuffer();
  buffer.writeln('# Spec-Code Sync Report');
  buffer.writeln('');
  buffer.writeln('生成时间: ${DateTime.now().toIso8601String()}');
  buffer.writeln('');
  buffer.writeln('## Summary');
  buffer.writeln('');
  buffer.writeln(
    '- 覆盖率: ${report.coveragePercentage.toStringAsFixed(1)}% (${report.modulesWithSpecs}/${report.totalModules} 模块有规格)',
  );
  buffer.writeln('- Critical 问题: ${report.criticalIssues}');
  buffer.writeln('- Warning 问题: ${report.warningIssues}');
  buffer.writeln('');

  if (report.missingSpecs.isNotEmpty) {
    buffer.writeln('## Missing Specs');
    buffer.writeln('');
    for (final issue in report.missingSpecs) {
      buffer.writeln('- [${issue.priority}] ${issue.description}');
    }
    buffer.writeln('');
  }

  if (report.orphanedSpecs.isNotEmpty) {
    buffer.writeln('## Orphaned Specs');
    buffer.writeln('');
    for (final issue in report.orphanedSpecs) {
      buffer.writeln('- [${issue.priority}] ${issue.description}');
    }
    buffer.writeln('');
  }

  if (report.structureIssues.isNotEmpty) {
    buffer.writeln('## Structure Issues');
    buffer.writeln('');
    for (final issue in report.structureIssues) {
      buffer.writeln('- [${issue.priority}] ${issue.description}');
    }
    buffer.writeln('');
  }

  if (report.migrationIssues.isNotEmpty) {
    buffer.writeln('## Migration Issues');
    buffer.writeln('');
    for (final issue in report.migrationIssues) {
      buffer.writeln('- [${issue.priority}] ${issue.description}');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}

void _printSummary(VerificationReport report) {
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 验证总结');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
  print('覆盖率: ${report.coveragePercentage.toStringAsFixed(1)}%');
  print('  有规格模块: ${report.modulesWithSpecs}');
  print('  总模块数: ${report.totalModules}');
  print('');
  print('问题统计:');
  print('  ❌ Critical: ${report.criticalIssues}');
  print('  ⚠️  Warning: ${report.warningIssues}');
  print('');

  if (report.criticalIssues == 0 && report.warningIssues == 0) {
    print('✅ 所有检查通过！');
  } else if (report.criticalIssues == 0) {
    print('⚠️  有 ${report.warningIssues} 个警告需要关注');
  } else {
    print('❌ 有 ${report.criticalIssues} 个严重问题需要修复');
  }
}

/// 配置加载器
class ConfigLoader {
  final String projectRoot;

  ConfigLoader(this.projectRoot);

  Map<String, dynamic>? loadOpenSpecConfig() {
    final configPath = path.join(
      projectRoot,
      'openspec',
      '.openspec',
      'config.json',
    );
    final configFile = File(configPath);

    if (!configFile.existsSync()) {
      return null;
    }

    try {
      final content = configFile.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️  警告: 无法解析 OpenSpec 配置: $e');
      return null;
    }
  }
}

/// 文件扫描器基类
abstract class FileScanner {
  final String projectRoot;
  final bool verbose;

  FileScanner(this.projectRoot, {this.verbose = false});

  /// 扫描文件并返回模块列表
  Future<List<CodeModule>> scan();

  /// 判断文件是否应该被排除
  bool shouldExclude(String filePath) {
    // 排除测试文件
    if (filePath.contains('/test/') || filePath.contains('\\test\\')) {
      return true;
    }
    // 排除生成的文件
    if (filePath.endsWith('.g.dart') ||
        filePath.endsWith('.freezed.dart') ||
        filePath.endsWith('.mocks.dart')) {
      return true;
    }
    return false;
  }
}

/// Rust 模块扫描器
class RustScanner extends FileScanner {
  RustScanner(String projectRoot, {bool verbose = false})
    : super(projectRoot, verbose: verbose);

  @override
  Future<List<CodeModule>> scan() async {
    final modules = <CodeModule>[];
    final srcDir = Directory(path.join(projectRoot, 'rust', 'src'));

    if (!srcDir.existsSync()) {
      if (verbose) print('  ⚠️  Rust src 目录不存在');
      return modules;
    }

    await for (final entity in srcDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.rs')) {
        if (shouldExclude(entity.path)) {
          continue;
        }

        final relativePath = path.relative(entity.path, from: projectRoot);
        final moduleName = _extractModuleName(entity.path);

        modules.add(
          CodeModule(
            name: moduleName,
            filePath: relativePath,
            language: 'rust',
            type: 'module',
          ),
        );
      }
    }

    if (verbose) print('  发现 ${modules.length} 个 Rust 模块');
    return modules;
  }

  String _extractModuleName(String filePath) {
    final basename = path.basenameWithoutExtension(filePath);
    return basename;
  }
}

/// Flutter 组件扫描器
class FlutterScanner extends FileScanner {
  FlutterScanner(String projectRoot, {bool verbose = false})
    : super(projectRoot, verbose: verbose);

  @override
  Future<List<CodeModule>> scan() async {
    final modules = <CodeModule>[];

    // 扫描 widgets 目录
    await _scanDirectory(modules, path.join(projectRoot, 'lib', 'widgets'));
    // 扫描 screens 目录
    await _scanDirectory(modules, path.join(projectRoot, 'lib', 'screens'));
    // 扫描 adaptive 目录（自适应 UI）
    await _scanDirectory(modules, path.join(projectRoot, 'lib', 'adaptive'));

    if (verbose) print('  发现 ${modules.length} 个 Flutter 组件');
    return modules;
  }

  Future<void> _scanDirectory(List<CodeModule> modules, String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        if (shouldExclude(entity.path)) {
          continue;
        }

        final relativePath = path.relative(entity.path, from: projectRoot);
        final componentName = _extractComponentName(entity.path);

        modules.add(
          CodeModule(
            name: componentName,
            filePath: relativePath,
            language: 'dart',
            type: 'widget',
          ),
        );
      }
    }
  }

  String _extractComponentName(String filePath) {
    final basename = path.basenameWithoutExtension(filePath);
    return basename;
  }
}

/// 规格同步验证器
class SpecSyncVerifier {
  final String projectRoot;
  final bool verbose;
  late final ConfigLoader configLoader;

  SpecSyncVerifier(this.projectRoot, {this.verbose = false}) {
    configLoader = ConfigLoader(projectRoot);
  }

  bool _isInfrastructureComponent(String filePath) {
    // adaptive/ 目录下的组件是技术基础设施，有综合文档覆盖
    return filePath.contains('/adaptive/') || filePath.contains('\\adaptive\\');
  }

  bool _isAbstractSpec(String basename) {
    // 抽象规格：不对应单一代码文件的概念性规格，或者尚未完全迁移的规格
    final abstractSpecs = {
      'common_types',
      'sync_protocol',
      'pool_model',
      'api_spec',
      'design_tokens',
      'shared_widgets',
      'responsive_layout',
      'adaptive_ui_components',
      'device_config', // 迁移中的规格
      'card_store', // 迁移中的规格
    };
    return abstractSpecs.contains(basename);
  }

  Future<VerificationReport> verify({
    required String scope,
    String? module,
  }) async {
    final report = VerificationReport();

    if (verbose) {
      print('开始验证...');
      print('');
    }

    // 加载配置
    final config = configLoader.loadOpenSpecConfig();
    if (config != null && verbose) {
      print('✓ 已加载 OpenSpec 配置');
    }

    // 执行覆盖率检查
    if (verbose) print('1️⃣ 覆盖率检查...');
    await _checkCoverage(report, scope, module);

    // 执行结构验证
    if (verbose) print('2️⃣ 结构验证...');
    await _checkStructure(report, scope);

    // 执行迁移验证
    if (verbose) print('3️⃣ 迁移验证...');
    await _checkMigration(report);

    return report;
  }

  Future<void> _checkCoverage(
    VerificationReport report,
    String scope,
    String? module,
  ) async {
    // 扫描代码模块
    final codeModules = <CodeModule>[];

    if (scope == 'all' || scope == 'domain') {
      final rustScanner = RustScanner(projectRoot, verbose: verbose);
      codeModules.addAll(await rustScanner.scan());
    }

    if (scope == 'all' || scope == 'features') {
      final flutterScanner = FlutterScanner(projectRoot, verbose: verbose);
      codeModules.addAll(await flutterScanner.scan());
    }

    // 如果指定了特定模块，过滤
    final modulesToCheck = module != null
        ? codeModules.where((m) => m.name == module).toList()
        : codeModules;

    report.totalModules = modulesToCheck.length;

    // 检查每个模块是否有对应的规格
    for (final codeModule in modulesToCheck) {
      // 跳过基础设施组件（有综合文档覆盖）
      if (codeModule.language == 'dart' &&
          _isInfrastructureComponent(codeModule.filePath)) {
        report.modulesWithSpecs++; // 视为已有规格（综合文档）
        continue;
      }

      final specPath = _findSpecForModule(codeModule);

      if (specPath != null && File(specPath).existsSync()) {
        report.modulesWithSpecs++;
      } else {
        // 缺失规格
        final priority = codeModule.language == 'rust' ? 'CRITICAL' : 'WARNING';
        report.missingSpecs.add(
          Issue(
            priority: priority,
            description: '${codeModule.filePath} → 缺少规格文档',
            filePath: codeModule.filePath,
            recommendation: '在 ${_getExpectedSpecLocation(codeModule)} 创建规格文档',
          ),
        );
      }
    }

    // 检查孤立的规格（有规格但无代码）
    await _checkOrphanedSpecs(report, codeModules);
  }

  String? _findSpecForModule(CodeModule module) {
    if (module.language == 'rust') {
      // Rust 模块映射到 domain/ 或 api/
      final domainPath = path.join(
        projectRoot,
        'openspec',
        'specs',
        'domain',
        '${module.name}.md',
      );
      if (File(domainPath).existsSync()) {
        return domainPath;
      }
      final apiPath = path.join(
        projectRoot,
        'openspec',
        'specs',
        'api',
        'api_spec.md',
      );
      if (File(apiPath).existsSync()) {
        return apiPath;
      }
    } else {
      // Flutter 组件需要在 features/ 和 ui_system/ 的子目录中递归查找
      // 先尝试 features 目录
      final featuresDir = Directory(
        path.join(projectRoot, 'openspec', 'specs', 'features'),
      );
      if (featuresDir.existsSync()) {
        final foundInFeatures = _findSpecInDirectory(featuresDir, module.name);
        if (foundInFeatures != null) {
          return foundInFeatures;
        }
      }

      // 再尝试 ui_system 目录
      final uiSystemDir = Directory(
        path.join(projectRoot, 'openspec', 'specs', 'ui_system'),
      );
      if (uiSystemDir.existsSync()) {
        final foundInUiSystem = _findSpecInDirectory(uiSystemDir, module.name);
        if (foundInUiSystem != null) {
          return foundInUiSystem;
        }
      }
    }

    return null;
  }

  String? _findSpecInDirectory(Directory dir, String moduleName) {
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final basename = path.basenameWithoutExtension(entity.path);
          if (basename == moduleName) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      // 忽略权限错误等
    }
    return null;
  }

  String _getExpectedSpecLocation(CodeModule module) {
    if (module.language == 'rust') {
      // Rust 模块映射到 domain/ 或 api/
      return 'domain/${module.name}.md|api/api_spec.md';
    } else {
      // Flutter 组件映射到 features/ 或 ui_system/
      return 'features/*/${module.name}.md|ui_system/${module.name}.md';
    }
  }

  Future<void> _checkOrphanedSpecs(
    VerificationReport report,
    List<CodeModule> codeModules,
  ) async {
    final specDirs = [
      path.join(projectRoot, 'openspec', 'specs', 'domain'),
      path.join(projectRoot, 'openspec', 'specs', 'api'),
      path.join(projectRoot, 'openspec', 'specs', 'features'),
      path.join(projectRoot, 'openspec', 'specs', 'ui_system'),
    ];

    final codeModuleNames = codeModules.map((m) => m.name).toSet();

    for (final specDirPath in specDirs) {
      final specDir = Directory(specDirPath);
      if (!specDir.existsSync()) continue;

      await for (final entity in specDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.md')) {
          final specName = path.basenameWithoutExtension(entity.path);

          // 跳过一些特殊文件
          if (specName == 'README' ||
              specName == 'DEPRECATED' ||
              specName.startsWith('SP-')) {
            continue;
          }

          // 跳过抽象规格（这些是概念性规格，不对应单一代码文件）
          if (_isAbstractSpec(specName)) {
            continue;
          }

          // 跳过旧平台特定规格（这些已被新的领域驱动规格取代）
          if (specName == 'desktop' ||
              specName == 'mobile' ||
              specName == 'shared') {
            continue;
          }

          // 检查是否有对应的代码模块
          if (!codeModuleNames.contains(specName)) {
            final relativePath = path.relative(entity.path, from: projectRoot);
            report.orphanedSpecs.add(
              Issue(
                priority: 'WARNING',
                description: '$relativePath → 未找到对应的代码实现',
                filePath: relativePath,
                recommendation: '确认是否需要删除或归档此规格',
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _checkStructure(VerificationReport report, String scope) async {
    // 检查规格文档结构
    final specsDir = Directory(path.join(projectRoot, 'openspec', 'specs'));
    if (!specsDir.existsSync()) {
      report.structureIssues.add(
        Issue(
          priority: 'CRITICAL',
          description: 'openspec/specs/ 目录不存在',
          recommendation: '创建规格目录结构',
        ),
      );
      return;
    }

    await for (final entity in specsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.md')) {
        await _validateSpecStructure(entity.path, report);
      }
    }
  }

  Future<void> _validateSpecStructure(
    String specPath,
    VerificationReport report,
  ) async {
    final relativePath = path.relative(specPath, from: projectRoot);

    // 跳过已废弃目录的验证（这些是旧规格，已标记 DEPRECATED）
    if (relativePath.contains('/rust/') ||
        relativePath.contains('/flutter/desktop/') ||
        relativePath.contains('/flutter/mobile/') ||
        relativePath.contains('/flutter/shared/')) {
      return; // 不验证已废弃目录中的文件
    }

    final content = await File(specPath).readAsString();
    final basename = path.basenameWithoutExtension(specPath);

    // 检查命名约定（snake_case），豁免特殊文件
    if (basename.contains(RegExp(r'[A-Z]')) &&
        basename != 'README' &&
        basename != 'DEPRECATED') {
      report.structureIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$relativePath → 文件名应使用 snake_case',
          filePath: relativePath,
          recommendation: '重命名为 ${basename.toLowerCase()}.md',
        ),
      );
    }

    // 检查技术栈前缀
    if (basename.startsWith('rust_') || basename.startsWith('flutter_')) {
      report.structureIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$relativePath → 文件名不应包含技术栈前缀',
          filePath: relativePath,
          recommendation: '移除 rust_/flutter_ 前缀',
        ),
      );
    }

    // 检查必需章节（简化版）
    final hasRequirements =
        content.contains('## ADDED Requirements') ||
        content.contains('## Requirements') ||
        content.contains('### Requirement');

    // 豁免某些文档类型的 Requirements 检查
    final isExemptFromRequirements =
        relativePath.contains('README') ||
        relativePath.contains('DEPRECATED') ||
        relativePath.contains('/engineering/') || // 工程实践文档
        basename.endsWith('_guide') || // 指南文档
        basename.endsWith('_summary') || // 总结文档
        basename.contains('GUIDE') || // 大写指南
        basename.contains('SUMMARY') || // 大写总结
        relativePath.contains('/domain/') &&
            _isAbstractSpec(basename) || // 抽象领域规格
        relativePath.contains('/api/') || // API 规范
        relativePath.contains('/ui_system/'); // UI 系统文档

    if (!hasRequirements && !isExemptFromRequirements) {
      report.structureIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$relativePath → 缺少 Requirements 章节',
          filePath: relativePath,
          recommendation: '添加 Requirements 章节定义需求',
        ),
      );
    }

    // 3.2 检查规格依赖关系（Referenced specs）
    await _checkSpecDependencies(specPath, content, relativePath, report);

    // 3.4 检查跨规格引用
    await _checkCrossSpecReferences(specPath, content, relativePath, report);
  }

  Future<void> _checkSpecDependencies(
    String specPath,
    String content,
    String relativePath,
    VerificationReport report,
  ) async {
    // 查找 "See:" 或 "参考：" 或 "Referenced specs:" 等模式
    final referencePatterns = [
      RegExp(r'See:\s+([a-z_/]+\.md)', multiLine: true),
      RegExp(r'参考：\s+([a-z_/]+\.md)', multiLine: true),
      RegExp(r'Referenced specs?:\s+([a-z_/]+\.md)', multiLine: true),
      RegExp(r'\[.*?\]\(([a-z_/]+\.md)\)', multiLine: true), // Markdown 链接
    ];

    for (final pattern in referencePatterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        final referencedSpec = match.group(1);
        if (referencedSpec == null) continue;

        // 检查引用的规格是否存在
        final referencedPath = path.join(
          path.dirname(specPath),
          referencedSpec,
        );

        if (!File(referencedPath).existsSync()) {
          // 尝试从 specs 根目录查找
          final rootPath = path.join(
            projectRoot,
            'openspec',
            'specs',
            referencedSpec,
          );
          if (!File(rootPath).existsSync()) {
            report.structureIssues.add(
              Issue(
                priority: 'WARNING',
                description: '$relativePath → 引用的规格不存在: $referencedSpec',
                filePath: relativePath,
                recommendation: '检查引用路径或创建缺失的规格文档',
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _checkCrossSpecReferences(
    String specPath,
    String content,
    String relativePath,
    VerificationReport report,
  ) async {
    // 豁免某些文档类型的旧引用检查（这些文档需要引用旧位置作为迁移映射）
    if (relativePath.contains('directory_conventions.md') ||
        relativePath.contains('DEPRECATED.md')) {
      return; // 这些文件需要引用旧位置作为迁移指南
    }

    // 豁免已标记为历史文档的文件
    if (content.contains('历史文档') ||
        content.contains('已归档') ||
        content.contains('路径更新') ||
        content.contains('路径示例基于旧的')) {
      return; // 历史文档或迁移指南保留原始引用
    }

    // 检查引用到旧位置的问题（rust/*, flutter/*）
    if (content.contains(RegExp(r'\brust/[a-z_]+\.md')) ||
        content.contains(RegExp(r'\bflutter/[a-z_]+\.md'))) {
      report.structureIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$relativePath → 引用了旧的规格位置 (rust/*, flutter/*)',
          filePath: relativePath,
          recommendation: '更新引用到新的领域驱动结构路径',
        ),
      );
    }
  }

  Future<void> _checkMigration(VerificationReport report) async {
    // 检查新领域驱动结构的目录是否存在
    final requiredDirs = [
      'openspec/specs/engineering',
      'openspec/specs/domain',
      'openspec/specs/api',
      'openspec/specs/features',
      'openspec/specs/ui_system',
    ];

    for (final dirPath in requiredDirs) {
      final dir = Directory(path.join(projectRoot, dirPath));
      if (!dir.existsSync()) {
        report.migrationIssues.add(
          Issue(
            priority: 'CRITICAL',
            description: '$dirPath 目录缺失',
            recommendation: '创建领域驱动结构目录',
          ),
        );
      }
    }

    // 检查旧规格是否标记为 DEPRECATED
    final deprecatedFiles = [
      'openspec/specs/rust/DEPRECATED.md',
      'openspec/specs/flutter/DEPRECATED.md',
    ];

    for (final filePath in deprecatedFiles) {
      final file = File(path.join(projectRoot, filePath));
      if (!file.existsSync()) {
        report.migrationIssues.add(
          Issue(
            priority: 'WARNING',
            description: '$filePath 不存在',
            recommendation: '添加 DEPRECATED 标记文件',
          ),
        );
      } else {
        // 4.3 验证迁移映射文档内容
        await _validateMigrationMapping(file, filePath, report);
      }
    }

    // 检查引用到旧位置的问题
    await _checkOldReferences(report);
  }

  Future<void> _validateMigrationMapping(
    File deprecatedFile,
    String filePath,
    VerificationReport report,
  ) async {
    final content = await deprecatedFile.readAsString();

    // 检查是否包含迁移映射信息
    // 至少应该包含以下几种模式之一：
    // 1. "迁移" 或 "Migration" 标题
    // 2. 旧规格到新规格的映射（→ 或 ->）
    // 3. 表格形式的映射

    final hasMigrationHeader = content.contains(
      RegExp(r'##\s*(迁移|Migration)', multiLine: true),
    );
    final hasMappingArrows = content.contains('→') || content.contains('->');
    final hasTableMapping =
        content.contains('|') &&
        (content.contains('旧位置') ||
            content.contains('Old Location') ||
            content.contains('新位置') ||
            content.contains('New Location'));

    if (!hasMigrationHeader && !hasMappingArrows && !hasTableMapping) {
      report.migrationIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$filePath → 缺少迁移映射说明',
          filePath: filePath,
          recommendation: '添加旧规格到新规格的迁移映射文档（使用表格或箭头标记）',
        ),
      );
      return;
    }

    // 如果有迁移信息，检查是否包含足够的映射条目
    // 简单启发式：至少应该有 3 个映射（→ 或 -> 出现次数）
    final arrowCount =
        '→'.allMatches(content).length + '->'.allMatches(content).length;
    if (arrowCount < 3 && !hasTableMapping) {
      report.migrationIssues.add(
        Issue(
          priority: 'WARNING',
          description: '$filePath → 迁移映射条目较少（发现 $arrowCount 个映射）',
          filePath: filePath,
          recommendation: '补充完整的旧规格到新规格的迁移映射',
        ),
      );
    }
  }

  Future<void> _checkOldReferences(VerificationReport report) async {
    final specsDir = Directory(path.join(projectRoot, 'openspec', 'specs'));
    if (!specsDir.existsSync()) return;

    await for (final entity in specsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.md')) {
        // 跳过旧目录本身
        if (entity.path.contains('/rust/') ||
            entity.path.contains('/flutter/')) {
          continue;
        }

        final content = await File(entity.path).readAsString();
        final relativePath = path.relative(entity.path, from: projectRoot);

        // 豁免某些文档类型的旧引用检查
        if (relativePath.contains('directory_conventions.md') ||
            relativePath.contains('DEPRECATED.md')) {
          continue; // 这些文件需要引用旧位置作为迁移指南
        }

        // 豁免已标记为历史文档的文件
        if (content.contains('历史文档') ||
            content.contains('已归档') ||
            content.contains('路径更新') ||
            content.contains('路径示例基于旧的')) {
          continue; // 历史文档或迁移指南保留原始引用
        }

        // 检查是否引用旧位置
        if (content.contains(RegExp(r'\brust/[a-z_]+\.md')) ||
            content.contains(RegExp(r'\bflutter/[a-z_]+\.md'))) {
          report.migrationIssues.add(
            Issue(
              priority: 'WARNING',
              description: '$relativePath → 引用了旧的规格位置 (rust/*, flutter/*)',
              filePath: relativePath,
              recommendation: '更新引用到新的领域驱动结构路径',
            ),
          );
        }
      }
    }
  }
}

/// 代码模块
class CodeModule {
  final String name;
  final String filePath;
  final String language; // 'rust' or 'dart'
  final String type; // 'module', 'widget', etc.

  CodeModule({
    required this.name,
    required this.filePath,
    required this.language,
    required this.type,
  });
}

/// 验证报告
class VerificationReport {
  int totalModules = 0;
  int modulesWithSpecs = 0;
  double get coveragePercentage =>
      totalModules > 0 ? (modulesWithSpecs / totalModules) * 100 : 0;

  List<Issue> missingSpecs = [];
  List<Issue> orphanedSpecs = [];
  List<Issue> structureIssues = [];
  List<Issue> migrationIssues = [];

  int get criticalIssues =>
      missingSpecs.where((i) => i.priority == 'CRITICAL').length +
      orphanedSpecs.where((i) => i.priority == 'CRITICAL').length +
      structureIssues.where((i) => i.priority == 'CRITICAL').length +
      migrationIssues.where((i) => i.priority == 'CRITICAL').length;

  int get warningIssues =>
      missingSpecs.where((i) => i.priority == 'WARNING').length +
      orphanedSpecs.where((i) => i.priority == 'WARNING').length +
      structureIssues.where((i) => i.priority == 'WARNING').length +
      migrationIssues.where((i) => i.priority == 'WARNING').length;

  Map<String, dynamic> toJson() => {
    'totalModules': totalModules,
    'modulesWithSpecs': modulesWithSpecs,
    'coveragePercentage': coveragePercentage,
    'missingSpecs': missingSpecs.map((i) => i.toJson()).toList(),
    'orphanedSpecs': orphanedSpecs.map((i) => i.toJson()).toList(),
    'structureIssues': structureIssues.map((i) => i.toJson()).toList(),
    'migrationIssues': migrationIssues.map((i) => i.toJson()).toList(),
    'criticalIssues': criticalIssues,
    'warningIssues': warningIssues,
  };
}

/// 问题记录
class Issue {
  final String priority; // CRITICAL, WARNING
  final String description;
  final String? filePath;
  final String? recommendation;

  Issue({
    required this.priority,
    required this.description,
    this.filePath,
    this.recommendation,
  });

  Map<String, dynamic> toJson() => {
    'priority': priority,
    'description': description,
    if (filePath != null) 'filePath': filePath,
    if (recommendation != null) 'recommendation': recommendation,
  };
}
