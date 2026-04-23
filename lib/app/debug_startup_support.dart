import 'dart:io';

bool shouldEnableDefaultDebugStatusExport({
  required bool debugStartInPool,
  required bool debugAutoCreatePool,
  required String debugAutoPin,
  required String debugAutoJoinCode,
}) {
  return debugStartInPool ||
      debugAutoCreatePool ||
      debugAutoPin.isNotEmpty ||
      debugAutoJoinCode.isNotEmpty;
}

bool shouldEnableDefaultInviteExport({
  required bool debugStartInPool,
  required bool debugAutoCreatePool,
}) {
  return debugStartInPool && debugAutoCreatePool;
}

Future<void> writeStartupDebugStatus(String? path, String line) async {
  if (path == null || path.isEmpty) {
    return;
  }
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('$line\n', mode: FileMode.append);
  } catch (_) {
    // 调试状态导出失败不应影响启动流程。
  }
}
