// input: Dart 运行时调用 main() 启动应用进程。
// output: 初始化 FRB 与 app config 后，再执行 runApp(CardMindApp(...)) 挂载根组件。
// pos: Flutter 应用入口文件，负责应用启动与 Rust 运行环境初始化。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 客户端入口模块，负责应用启动与依赖接线。
import 'dart:io';

import 'package:cardmind/app/app.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Determine the correct library path based on platform
  final libPath = _getRustLibraryPath();
  final externalLib = ExternalLibrary.open(libPath);
  await RustLib.init(externalLibrary: externalLib);
  final appDataDir = (await getApplicationSupportDirectory()).path;
  await frb.initAppConfig(appDataDir: appDataDir);
  final poolNetworkId = await frb.initPoolNetwork(basePath: appDataDir);
  runApp(CardMindApp(appDataDir: appDataDir, poolNetworkId: poolNetworkId));
}

String _getRustLibraryPath() {
  if (Platform.isMacOS) {
    // For macOS, the dylib should be in the app bundle's Frameworks directory
    final dylibPath =
        '${Platform.resolvedExecutable}/../Frameworks/libcardmind_rust.dylib';

    if (File(dylibPath).existsSync()) {
      return dylibPath;
    }

    // Fallback to development path if not found in app bundle
    final devPath =
        '/Users/alexc/Projects/CardMind/rust/target/release/libcardmind_rust.dylib';
    if (File(devPath).existsSync()) {
      return devPath;
    }

    // Return dylib path anyway and let it fail with a clear error
    return dylibPath;
  }

  // For other platforms, use default FRB behavior
  throw UnsupportedError(
    'Platform ${Platform.operatingSystem} not yet supported',
  );
}
