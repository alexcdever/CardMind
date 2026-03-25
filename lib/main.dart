/// # 应用入口模块
///
/// Flutter 客户端入口模块，负责应用启动与 Rust 运行环境初始化。
///
/// ## 外部依赖
/// - 依赖 [flutter_rust_bridge] 提供与 Rust 层的 FFI 桥接。
/// - 依赖 [path_provider] 获取应用数据目录。
library main;

import 'dart:io';

import 'package:cardmind/app/app.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';
import 'package:path_provider/path_provider.dart';

/// 应用主入口函数。
///
/// Dart 运行时调用 main() 启动应用进程。本函数完成以下初始化：
/// 1. 初始化 Flutter 框架绑定
/// 2. 加载 Rust 动态库并初始化 FRB
/// 3. 获取应用数据目录
/// 4. 初始化应用配置和 Pool 网络
/// 5. 挂载根组件
///
/// [appDataDir] 和 [poolNetworkId] 将通过 [CardMindApp] 传递给子组件。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libPath = _getRustLibraryPath();
  final externalLib = ExternalLibrary.open(libPath);
  await RustLib.init(externalLibrary: externalLib);
  final appDataDir = (await getApplicationSupportDirectory()).path;
  await frb.initAppConfig(appDataDir: appDataDir);
  final poolNetworkId = await frb.initPoolNetwork(basePath: appDataDir);
  runApp(CardMindApp(appDataDir: appDataDir, poolNetworkId: poolNetworkId));
}

/// 获取 Rust 动态库路径。
///
/// 根据当前平台返回对应的动态库文件路径。
///
/// 目前支持：
/// - macOS: 优先查找应用包中的 dylib，回退到开发路径
///
/// 如果未找到库文件，将抛出 [UnsupportedError] 异常。
///
/// 返回 Rust 动态库的完整文件路径。
String _getRustLibraryPath() {
  if (Platform.isMacOS) {
    final dylibPath =
        '${Platform.resolvedExecutable}/../Frameworks/libcardmind_rust.dylib';

    if (File(dylibPath).existsSync()) {
      return dylibPath;
    }

    final devPath =
        '/Users/alexc/Projects/CardMind/rust/target/release/libcardmind_rust.dylib';
    if (File(devPath).existsSync()) {
      return devPath;
    }

    return dylibPath;
  }

  throw UnsupportedError(
    'Platform ${Platform.operatingSystem} not yet supported',
  );
}
