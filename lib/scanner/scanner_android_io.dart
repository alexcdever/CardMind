import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_interface.dart';

/// Android 真实现：mobile_scanner 全屏扫码页。
///
/// 只在本文件 import mobile_scanner——桌面桩（scanner_stub.dart）不依赖它，
/// 桌面/Web 构建不会链接该插件。扫码结果 / 权限拒绝 / 取消统一通过
/// [ScanOutcome] 返回，UI 不感知 mobile_scanner 类型。
class AndroidScannerService implements ScannerService {
  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<ScanOutcome> scanCredential(BuildContext context) async {
    if (!Platform.isAndroid) {
      return const ScanOutcome(error: '当前平台不支持扫码，请手动输入或粘贴配对信息');
    }
    final outcome = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    return outcome ?? const ScanOutcome();
  }
}

/// 平台工厂（scanner_interface.dart 通过条件导入调用，见任务 Q）。
ScannerService createPlatformScannerImpl() => AndroidScannerService();

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 识别到文本：关闭扫码页并返回（同一结果类型，UI 走同一 submit/parser）。
  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final text = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (text == null || text.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(ScanOutcome(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描配对信息')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
