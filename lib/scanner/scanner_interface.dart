import 'package:flutter/widgets.dart';

import 'scanner_android_io.dart'
    if (dart.library.js_interop) 'scanner_stub.dart' as platform;

/// 扫码结果：text 为识别文本；error 为用户可读错误（权限被拒/相机不可用）；
/// 两者皆 null 表示用户取消。
class ScanOutcome {
  final String? text;
  final String? error;

  const ScanOutcome({this.text, this.error});

  bool get cancelled => text == null && error == null;
}

/// 扫码服务抽象（任务 Q 发起方输入）：Android 用 mobile_scanner 真实现，
/// 其余平台桌面桩。UI 通过 [createPlatformScanner] 使用，不直接依赖
/// mobile_scanner（条件导入隔离）。
abstract class ScannerService {
  /// 当前平台是否支持扫码（Android true；桌面 false）。
  bool get isSupported;

  /// 弹出扫码页并返回识别结果。UI 只消费 [ScanOutcome] 的 text / error。
  Future<ScanOutcome> scanCredential(BuildContext context);
}

/// 平台选择：Android 用真实现，其余平台桌面桩。
///
/// 通过条件导入隔离 mobile_scanner：只有 Android 编译目标实际导入
/// `scanner_android_io.dart`（依赖 mobile_scanner），桌面/Web/测试环境
/// 导入 `scanner_stub.dart`，保证 Windows 构建不链接 mobile_scanner 插件。
ScannerService createPlatformScanner() => platform.createPlatformScannerImpl();