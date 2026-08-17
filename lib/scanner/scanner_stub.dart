import 'package:flutter/widgets.dart';

import 'scanner_interface.dart';

/// 桌面平台扫码桩：不支持扫码，返回友好提示（Windows/Linux 不显示扫码按钮）。
class DesktopScannerService implements ScannerService {
  @override
  bool get isSupported => false;

  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async =>
      const ScanOutcome(error: '当前平台不支持扫码，请手动输入或粘贴配对信息');
}

/// 平台工厂（scanner_interface.dart 通过条件导入调用，见任务 Q）。
ScannerService createPlatformScannerImpl() => DesktopScannerService();
