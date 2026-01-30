#!/usr/bin/env dart

/// CardMind Flutter 运行脚本
///
/// 用途: 自动设置环境变量并运行 Flutter 应用
///
/// 运行方式:
/// ```bash
/// dart tool/run.dart
/// dart tool/run.dart --release   # 发布模式
/// ```

import 'dart:io';

void main(List<String> arguments) async {
  print('🚀 启动 CardMind...');

  // 构建环境变量
  final env = Map<String, String>.from(Platform.environment);

  // 添加 cargo bin 到 PATH
  final cargoPath = '${Platform.environment['HOME']}/.cargo/bin';
  if (env.containsKey('PATH')) {
    env['PATH'] = '$cargoPath:${env['PATH']}';
  } else {
    env['PATH'] = cargoPath;
  }

  // 设置 PKG_CONFIG_PATH
  final pkgConfigPaths = [
    '/usr/lib/x86_64-linux-gnu/pkgconfig',
    '/usr/share/pkgconfig',
  ];

  if (env.containsKey('PKG_CONFIG_PATH')) {
    env['PKG_CONFIG_PATH'] =
        '${pkgConfigPaths.join(':')}:${env['PKG_CONFIG_PATH']}';
  } else {
    env['PKG_CONFIG_PATH'] = pkgConfigPaths.join(':');
  }

  // 运行 flutter
  final args = ['run', ...arguments];
  print('执行命令: flutter ${args.join(' ')}');
  print('');

  final process = await Process.start(
    'flutter',
    args,
    environment: env,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  exit(exitCode);
}
