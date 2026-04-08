import 'package:cardmind/app/app.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/features/shared/runtime/rust_library_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libPath = resolveRustLibraryPath();
  final externalLib = ExternalLibrary.open(libPath);
  await RustLib.init(externalLibrary: externalLib);
  final appDataDir = (await getApplicationSupportDirectory()).path;
  await frb.initAppConfig(appDataDir: appDataDir);
  final poolNetworkId = await frb.initPoolNetwork(basePath: appDataDir);
  runApp(CardMindApp(appDataDir: appDataDir, poolNetworkId: poolNetworkId));
}
