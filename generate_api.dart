import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== CardMind API 生成脚本 ===\n');

  // 步骤1: 生成Dart API
  print('步骤1: 生成Dart API...');
  try {
    final result = await Process.run(
      'flutter_rust_bridge_codegen',
      [
        'generate',
        '-r',
        'crate::api',
        '-d',
        'lib/api',
        '-c',
        'bridge_generated.h',
        '--rust-root',
        'rust',
      ],
      runInShell: true,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode == 0) {
      print('✓ Dart API 生成成功');
    } else {
      print('✗ Dart API 生成失败: ${result.stderr}');
      return;
    }
  } catch (e) {
    print('✗ 执行Dart API生成时出错: $e');
    return;
  }

  // 步骤2: 编译Rust动态库
  print('\n步骤2: 编译Rust动态库...');
  try {
    final result = await Process.run(
      'cargo',
      ['build', '--release'],
      workingDirectory: 'rust',
      runInShell: true,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode == 0) {
      print('✓ Rust动态库编译成功');
    } else {
      print('✗ Rust动态库编译失败: ${result.stderr}');
      return;
    }
  } catch (e) {
    print('✗ 执行Rust编译时出错: $e');
    return;
  }

  // 步骤3: 复制文件
  print('\n步骤3: 复制动态库到目标位置...');
  try {
    final sourcePath = 'rust/target/release/cardmind_rust.dll';
    final targetDir = 'windows/runner/Release';
    final targetPath = '$targetDir/cardmind_rust.dll';

    // 创建目标目录
    final targetDirectory = Directory(targetDir);
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
    }

    // 复制文件
    final sourceFile = File(sourcePath);
    if (sourceFile.existsSync()) {
      sourceFile.copySync(targetPath);
      print('✓ 动态库已复制到: $targetPath');
    } else {
      print('✗ 源文件不存在: $sourcePath');
      return;
    }
  } catch (e) {
    print('✗ 复制文件时出错: $e');
    return;
  }

  print('\n=== 所有操作完成 ===');
  print('✓ Dart API: ./lib/api/');
  print('✓ Rust动态库: ./rust/target/release/cardmind_rust.dll');
  print('✓ 复制位置: ./windows/runner/Release/cardmind_rust.dll');
}
