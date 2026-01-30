#!/usr/bin/env dart

/// Flutter 测试运行脚本
///
/// 提供便捷的测试运行命令，支持不同类型的测试和选项

import 'dart:io';

void main(List<String> args) async {
  print('🧪 Flutter Test Runner\n');

  if (args.isEmpty) {
    printUsage();
    exit(0);
  }

  final command = args[0];

  switch (command) {
    case 'all':
      await runAllTests();
      break;
    case 'specs':
      await runSpecTests();
      break;
    case 'widgets':
      await runWidgetTests();
      break;
    case 'screens':
      await runScreenTests();
      break;
    case 'integration':
      await runIntegrationTests();
      break;
    case 'coverage':
      await runTestsWithCoverage();
      break;
    case 'watch':
      await watchTests();
      break;
    case 'help':
      printUsage();
      break;
    default:
      print('❌ Unknown command: $command\n');
      printUsage();
      exit(1);
  }
}

void printUsage() {
  print('''
Usage: dart tool/run_tests.dart <command>

Commands:
  all         运行所有测试
  specs       运行规格测试 (test/specs/)
  widgets     运行组件测试 (test/widgets/)
  screens     运行屏幕测试 (test/screens/)
  integration 运行集成测试 (test/integration/)
  coverage    运行测试并生成覆盖率报告
  watch       监听模式运行测试
  help        显示此帮助信息

Examples:
  dart tool/run_tests.dart all
  dart tool/run_tests.dart specs
  dart tool/run_tests.dart coverage
''');
}

Future<void> runAllTests() async {
  print('📋 Running all tests...\n');
  await runFlutterTest(['test/']);
}

Future<void> runSpecTests() async {
  print('📋 Running spec tests...\n');
  await runFlutterTest(['test/specs/']);
}

Future<void> runWidgetTests() async {
  print('📋 Running widget tests...\n');
  await runFlutterTest(['test/widgets/']);
}

Future<void> runScreenTests() async {
  print('📋 Running screen tests...\n');
  await runFlutterTest(['test/screens/']);
}

Future<void> runIntegrationTests() async {
  print('📋 Running integration tests...\n');
  await runFlutterTest(['test/integration/']);
}

Future<void> runTestsWithCoverage() async {
  print('📋 Running tests with coverage...\n');
  await runFlutterTest(['test/', '--coverage']);

  print('\n📊 Generating coverage report...');

  // 检查是否有 lcov 工具
  final lcovResult = await Process.run('which', ['lcov']);
  if (lcovResult.exitCode == 0) {
    print('📈 Coverage report generated at: coverage/lcov.info');
    print('💡 Tip: Use lcov or genhtml to view the report');
  } else {
    print('⚠️  lcov not found. Install it to generate HTML coverage reports.');
    print('   On macOS: brew install lcov');
    print('   On Ubuntu: sudo apt-get install lcov');
  }
}

Future<void> watchTests() async {
  print('👀 Running tests in watch mode...\n');
  print('💡 Press Ctrl+C to stop\n');

  await runFlutterTest(['test/', '--watch']);
}

Future<void> runFlutterTest(List<String> args) async {
  final result = await Process.run('flutter', [
    'test',
    ...args,
  ], runInShell: true);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('\n❌ Tests failed with exit code: ${result.exitCode}');
    exit(result.exitCode);
  } else {
    print('\n✅ All tests passed!');
  }
}
