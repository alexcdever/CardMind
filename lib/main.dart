// input: Dart 运行时调用 main() 启动应用进程。
// output: 初始化 FRB 与 app config 后，再执行 runApp(CardMindApp(...)) 挂载根组件。
// pos: Flutter 应用入口文件，负责应用启动与 Rust 运行环境初始化。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 客户端入口模块，负责应用启动与依赖接线。
import 'package:cardmind/app/app.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final appDataDir = (await getApplicationSupportDirectory()).path;
  await frb.initAppConfig(appDataDir: appDataDir);
  final poolNetworkId = await frb.initPoolNetwork(basePath: appDataDir);
  runApp(CardMindApp(appDataDir: appDataDir, poolNetworkId: poolNetworkId));
}
