import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cardmind/services/qr_code_parser.dart';

/// 二维码扫描回调
typedef OnQRCodeScanned = Future<void> Function(QRCodeData qrData);

/// 相机权限状态
enum CameraPermissionStatus {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
}

/// 二维码扫描标签页
///
/// 使用相机扫描二维码进行设备配对。
class QRCodeScannerTab extends StatefulWidget {
  const QRCodeScannerTab({
    super.key,
    required this.onQRCodeScanned,
  });

  final OnQRCodeScanned onQRCodeScanned;

  @override
  State<QRCodeScannerTab> createState() => _QRCodeScannerTabState();
}

class _QRCodeScannerTabState extends State<QRCodeScannerTab>
    with AutomaticKeepAliveClientMixin {
  MobileScannerController? _controller;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.notRequested;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => false; // 不保持状态以节省资源

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 检查权限并初始化相机
  Future<void> _checkPermissionAndInitialize() async {
    final status = await _checkCameraPermission();
    setState(() {
      _permissionStatus = status;
    });

    if (status == CameraPermissionStatus.granted) {
      await _initializeCamera();
    }
  }

  /// 检查相机权限
  Future<CameraPermissionStatus> _checkCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return CameraPermissionStatus.granted;
    } else if (status.isDenied) {
      return CameraPermissionStatus.denied;
    } else if (status.isPermanentlyDenied) {
      return CameraPermissionStatus.permanentlyDenied;
    } else {
      return CameraPermissionStatus.notRequested;
    }
  }

  /// 请求相机权限
  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();

    if (mounted) {
      setState(() {
        if (status.isGranted) {
          _permissionStatus = CameraPermissionStatus.granted;
        } else if (status.isPermanentlyDenied) {
          _permissionStatus = CameraPermissionStatus.permanentlyDenied;
        } else {
          _permissionStatus = CameraPermissionStatus.denied;
        }
      });

      if (status.isGranted) {
        await _initializeCamera();
      }
    }
  }

  /// 打开应用设置
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  /// 初始化相机
  Future<void> _initializeCamera() async {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        formats: [BarcodeFormat.qrCode],
      );

      await _controller!.start();

      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '相机启动失败: $e';
        });
      }
    }
  }

  /// 处理扫描到的二维码
  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 停止扫描
      await _controller?.stop();

      // 解析二维码数据
      final qrText = barcode.rawValue!;
      final qrData = QRCodeParser.parseQRData(qrText);

      // 验证数据
      QRCodeParser.validateQRData(qrData);

      // 调用回调
      await widget.onQRCodeScanned(qrData);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = '二维码解析失败: $e';
        });

        // 重新启动扫描
        await _controller?.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);

    // 权限未授予的情况
    if (_permissionStatus != CameraPermissionStatus.granted) {
      return _buildPermissionView(theme);
    }

    // 相机初始化失败
    if (_errorMessage != null && _controller == null) {
      return _buildErrorView(theme);
    }

    // 正常扫描界面
    return Stack(
      children: [
        // 相机预览
        if (_controller != null)
          MobileScanner(
            controller: _controller!,
            onDetect: _handleBarcode,
          ),

        // 扫描框和提示
        _buildScanOverlay(theme),

        // 错误提示
        if (_errorMessage != null) _buildErrorBanner(theme),

        // 处理中遮罩
        if (_isProcessing) _buildProcessingOverlay(theme),
      ],
    );
  }

  /// 构建权限请求视图
  Widget _buildPermissionView(ThemeData theme) {
    String title;
    String message;
    String buttonText;
    VoidCallback? onPressed;

    switch (_permissionStatus) {
      case CameraPermissionStatus.notRequested:
      case CameraPermissionStatus.denied:
        title = '需要相机权限';
        message = '请授予相机权限以扫描二维码';
        buttonText = '授予权限';
        onPressed = _requestPermission;
        break;
      case CameraPermissionStatus.permanentlyDenied:
        title = '相机权限被拒绝';
        message = '请在系统设置中手动开启相机权限';
        buttonText = '打开设置';
        onPressed = _openAppSettings;
        break;
      case CameraPermissionStatus.granted:
        title = '正在初始化...';
        message = '';
        buttonText = '';
        onPressed = null;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onPressed != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.settings),
                label: Text(buttonText),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              '相机启动失败',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '未知错误',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建扫描框覆盖层
  Widget _buildScanOverlay(ThemeData theme) {
    return Column(
      children: [
        // 顶部提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.black.withOpacity(0.5),
          child: Text(
            '将二维码放入框内',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // 扫描框
        Expanded(
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // 四个角的装饰
                  _buildCornerDecoration(
                    theme,
                    Alignment.topLeft,
                    [_CornerSide.top, _CornerSide.left],
                  ),
                  _buildCornerDecoration(
                    theme,
                    Alignment.topRight,
                    [_CornerSide.top, _CornerSide.right],
                  ),
                  _buildCornerDecoration(
                    theme,
                    Alignment.bottomLeft,
                    [_CornerSide.bottom, _CornerSide.left],
                  ),
                  _buildCornerDecoration(
                    theme,
                    Alignment.bottomRight,
                    [_CornerSide.bottom, _CornerSide.right],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 底部说明
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.black.withOpacity(0.5),
          child: Text(
            '扫描对方设备显示的二维码',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 构建角落装饰
  Widget _buildCornerDecoration(
    ThemeData theme,
    Alignment alignment,
    List<_CornerSide> sides,
  ) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: sides.contains(_CornerSide.top)
                ? BorderSide(color: theme.colorScheme.primary, width: 4)
                : BorderSide.none,
            left: sides.contains(_CornerSide.left)
                ? BorderSide(color: theme.colorScheme.primary, width: 4)
                : BorderSide.none,
            right: sides.contains(_CornerSide.right)
                ? BorderSide(color: theme.colorScheme.primary, width: 4)
                : BorderSide.none,
            bottom: sides.contains(_CornerSide.bottom)
                ? BorderSide(color: theme.colorScheme.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// 构建错误横幅
  Widget _buildErrorBanner(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.errorContainer,
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onErrorContainer,
              ),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建处理中遮罩
  Widget _buildProcessingOverlay(ThemeData theme) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              '正在处理二维码...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 角落方向枚举
enum _CornerSide {
  top,
  left,
  right,
  bottom,
}
