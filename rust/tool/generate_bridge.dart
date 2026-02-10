// ignore_for_file: avoid_print

import 'dart:io';

/// 生成 flutter_rust_bridge 代码
///
/// 使用 flutter_rust_bridge_codegen 工具生成 Dart 和 Rust 的桥接代码
Future<void> main() async {
  print('🔧 开始生成 flutter_rust_bridge 代码...\n');

  // 检查是否安装了 flutter_rust_bridge_codegen
  final checkResult = await Process.run('flutter_rust_bridge_codegen', [
    '--version',
  ]);

  if (checkResult.exitCode != 0) {
    print('❌ 错误: flutter_rust_bridge_codegen 未安装');
    print('请运行: cargo install flutter_rust_bridge_codegen');
    exit(1);
  }

  print('✅ flutter_rust_bridge_codegen 版本: ${checkResult.stdout}');

  // 运行代码生成
  print('\n🚀 正在生成代码...\n');

  final result = await Process.run('flutter_rust_bridge_codegen', [
    'generate',
    '--config-file',
    'flutter_rust_bridge.yaml',
    '--rust-output',
    'rust/src/frb_generated.rs',
  ], runInShell: true);

  print(result.stdout);

  if (result.exitCode != 0) {
    print('❌ 代码生成失败:');
    print(result.stderr);
    exit(1);
  }

  print('\n✅ flutter_rust_bridge 代码生成完成！');
}
