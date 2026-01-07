#!/usr/bin/env dart

/// CardMind桥接代码生成脚本
///
/// 用途: 生成Flutter和Rust之间的桥接代码
/// 优势: 跨平台（Windows/macOS/Linux通用）
///
/// 运行方式:
/// ```bash
/// dart tool/generate_bridge.dart
/// ```

import 'dart:io';

void main(List<String> arguments) async {
  print('🔨 CardMind桥接代码生成器');
  print('=' * 50);

  // 1. 检查环境
  if (!await checkEnvironment()) {
    exit(1);
  }

  // 2. 生成桥接代码
  if (!await generateBridge()) {
    exit(1);
  }

  // 3. 格式化生成的代码
  if (!await formatGeneratedCode()) {
    exit(1);
  }

  print('=' * 50);
  print('✅ 桥接代码生成成功！');
  print('');
  print('下一步:');
  print('  1. 运行 flutter pub get');
  print('  2. 运行 flutter run');
}

/// 检查环境依赖
Future<bool> checkEnvironment() async {
  print('📋 检查环境依赖...');

  // 检查flutter_rust_bridge_codegen
  final codegenCheck = await Process.run(
    'flutter_rust_bridge_codegen',
    ['--version'],
  );

  if (codegenCheck.exitCode != 0) {
    print('❌ 错误: 未找到 flutter_rust_bridge_codegen');
    print('');
    print('请安装:');
    print('  cargo install flutter_rust_bridge_codegen');
    return false;
  }

  print('✓ flutter_rust_bridge_codegen: ${codegenCheck.stdout.toString().trim()}');

  // 检查Rust项目
  final rustDir = Directory('rust');
  if (!rustDir.existsSync()) {
    print('❌ 错误: rust/ 目录不存在');
    return false;
  }

  print('✓ Rust项目目录存在');

  // 检查Flutter项目
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ 错误: pubspec.yaml 不存在');
    print('  请在项目根目录运行此脚本');
    return false;
  }

  print('✓ Flutter项目配置存在');
  print('');

  return true;
}

/// 生成桥接代码
Future<bool> generateBridge() async {
  print('🔄 生成桥接代码...');

  // 配置参数
  final args = [
    'generate',
    '--rust-input', 'cardmind_rust::api',
    '--dart-output', 'lib/bridge/',
    '--c-output', 'rust/src/bridge_generated.h',
  ];

  print('运行命令: flutter_rust_bridge_codegen ${args.join(' ')}');
  print('');

  final result = await Process.run(
    'flutter_rust_bridge_codegen',
    args,
  );

  // 输出日志
  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print('❌ 生成失败');
    if (result.stderr.toString().isNotEmpty) {
      print('错误信息:');
      print(result.stderr);
    }
    return false;
  }

  print('✓ 桥接代码生成完成');
  print('');

  return true;
}

/// 格式化生成的代码
Future<bool> formatGeneratedCode() async {
  print('🎨 格式化生成的代码...');

  // 格式化Dart代码
  final dartFormatResult = await Process.run(
    'dart',
    ['format', 'lib/bridge/'],
  );

  if (dartFormatResult.exitCode != 0) {
    print('⚠️  警告: Dart代码格式化失败（非致命错误）');
  } else {
    print('✓ Dart代码格式化完成');
  }

  // 格式化Rust代码
  final rustFormatResult = await Process.run(
    'cargo',
    ['fmt'],
    workingDirectory: 'rust',
  );

  if (rustFormatResult.exitCode != 0) {
    print('⚠️  警告: Rust代码格式化失败（非致命错误）');
  } else {
    print('✓ Rust代码格式化完成');
  }

  print('');
  return true;
}
