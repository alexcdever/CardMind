import 'package:cardmind/app/app.dart';
import 'package:cardmind/app/debug_startup_support.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/features/shared/runtime/rust_library_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';
import 'package:path_provider/path_provider.dart';

const bool _debugStartInPool = bool.fromEnvironment(
  'CARDMIND_DEBUG_START_IN_POOL',
);
const bool _debugAutoCreatePool = bool.fromEnvironment(
  'CARDMIND_DEBUG_AUTO_CREATE_POOL',
);
const String _debugAutoPin = String.fromEnvironment('CARDMIND_DEBUG_PIN');
const String _debugAutoJoinCode = String.fromEnvironment(
  'CARDMIND_DEBUG_JOIN_CODE',
);
const String _debugExportInvitePath = String.fromEnvironment(
  'CARDMIND_DEBUG_EXPORT_INVITE_PATH',
);
const String _debugStatusExportPath = String.fromEnvironment(
  'CARDMIND_DEBUG_STATUS_EXPORT_PATH',
);
const bool _debugPrintInvite = bool.fromEnvironment(
  'CARDMIND_DEBUG_PRINT_INVITE',
);
const bool _debugJoinTrace = bool.fromEnvironment('CARDMIND_DEBUG_JOIN_TRACE');

String? _resolvedDebugInvitePath = _debugExportInvitePath.isEmpty
    ? null
    : _debugExportInvitePath;

String? _resolvedDebugStatusPath = _debugStatusExportPath.isEmpty
    ? null
    : _debugStatusExportPath;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await writeStartupDebugStatus(_resolvedDebugStatusPath, 'main_started');

  final libPath = resolveRustLibraryPath();
  await writeStartupDebugStatus(
    _resolvedDebugStatusPath,
    'lib_path:${libPath ?? 'default'}',
  );
  await RustLib.init(
    externalLibrary: libPath == null ? null : ExternalLibrary.open(libPath),
  );
  final appDataDir = (await getApplicationSupportDirectory()).path;
  _resolvedDebugInvitePath ??=
      shouldEnableDefaultInviteExport(
        debugStartInPool: _debugStartInPool,
        debugAutoCreatePool: _debugAutoCreatePool,
      )
      ? '$appDataDir/debug_invite.txt'
      : null;
  _resolvedDebugStatusPath ??=
      shouldEnableDefaultDebugStatusExport(
        debugStartInPool: _debugStartInPool,
        debugAutoCreatePool: _debugAutoCreatePool,
        debugAutoPin: _debugAutoPin,
        debugAutoJoinCode: _debugAutoJoinCode,
      )
      ? '$appDataDir/debug_status.log'
      : null;
  await writeStartupDebugStatus(
    _resolvedDebugStatusPath,
    'app_data_dir:$appDataDir',
  );
  await frb.initAppConfig(appDataDir: appDataDir);
  runApp(
    CardMindApp(
      appDataDir: appDataDir,
      debugStartInPool: _debugStartInPool,
      debugAutoCreatePool: _debugAutoCreatePool,
      debugAutoPin: _debugAutoPin.isEmpty ? null : _debugAutoPin,
      debugAutoJoinCode: _debugAutoJoinCode.isEmpty ? null : _debugAutoJoinCode,
      debugExportInvitePath: _resolvedDebugInvitePath,
      debugStatusExportPath: _resolvedDebugStatusPath,
      debugPrintInvite: _debugPrintInvite,
      debugJoinTrace: _debugJoinTrace,
    ),
  );
}
