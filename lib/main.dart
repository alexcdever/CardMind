import 'package:cardmind/app/app.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/features/shared/runtime/rust_library_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';
import 'package:path_provider/path_provider.dart';

const bool _debugStartInPool = bool.fromEnvironment(
  'CARDMIND_DEBUG_START_IN_POOL',
);
const String _debugAutoPin = String.fromEnvironment('CARDMIND_DEBUG_PIN');
const String _debugAutoJoinCode = String.fromEnvironment(
  'CARDMIND_DEBUG_JOIN_CODE',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final libPath = resolveRustLibraryPath();
  await RustLib.init(
    externalLibrary: libPath == null ? null : ExternalLibrary.open(libPath),
  );
  final appDataDir = (await getApplicationSupportDirectory()).path;
  await frb.initAppConfig(appDataDir: appDataDir);
  runApp(
    CardMindApp(
      appDataDir: appDataDir,
      debugStartInPool: _debugStartInPool,
      debugAutoPin: _debugAutoPin.isEmpty ? null : _debugAutoPin,
      debugAutoJoinCode: _debugAutoJoinCode.isEmpty
          ? null
          : _debugAutoJoinCode,
    ),
  );
}
