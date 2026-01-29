import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:cardmind/models/device.dart';
import 'package:cardmind/services/qr_code_generator.dart';
import 'package:cardmind/services/qr_code_parser.dart';
import 'package:cardmind/services/verification_code_service.dart';
import 'package:cardmind/widgets/qr_code_scanner_tab.dart';
import 'package:cardmind/widgets/qr_code_upload_tab.dart';
import 'package:cardmind/widgets/verification_code_dialog.dart';
import 'package:cardmind/widgets/verification_code_input.dart';

/// 配对设备对话框
///
/// 提供两种配对方式：
/// 1. 显示二维码：让其他设备扫描
/// 2. 扫描二维码：移动端使用相机扫描，桌面端上传文件
class PairDeviceDialog extends StatefulWidget {
  const PairDeviceDialog({
    super.key,
    required this.currentDevice,
    required this.poolId,
    required this.onPairDevice,
  });

  /// 当前设备信息
  final Device currentDevice;

  /// 数据池 ID
  final String poolId;

  /// 配对设备回调
  final Future<bool> Function(String deviceId, String verificationCode) onPairDevice;

  @override
  State<PairDeviceDialog> createState() => _PairDeviceDialogState();
}

class _PairDeviceDialogState extends State<PairDeviceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// 判断是否为移动端
  bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),

            // 标签页
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                  icon: Icon(Icons.qr_code),
                  text: '显示二维码',
                ),
                Tab(
                  icon: Icon(_isMobile ? Icons.camera_alt : Icons.upload_file),
                  text: _isMobile ? '扫描二维码' : '上传二维码',
                ),
              ],
            ),

            // 标签页内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDisplayQRTab(context),
                  _buildScanQRTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.devices, size: 28),
          const SizedBox(width: 12),
          Text(
            '配对新设备',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 构建显示二维码标签页
  Widget _buildDisplayQRTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 说明文字
          Text(
            '让其他设备扫描此二维码进行配对',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 二维码
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QRCodeGenerator.buildQRCodeWidget(
              peerId: widget.currentDevice.id,
              deviceName: widget.currentDevice.name,
              deviceType: widget.currentDevice.type.name,
              multiaddrs: widget.currentDevice.multiaddrs,
              poolId: widget.poolId,
              size: 300,
            ),
          ),
          const SizedBox(height: 24),

          // 设备信息
          _buildDeviceInfo(context),
          const SizedBox(height: 16),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '二维码有效期为 10 分钟',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建扫描二维码标签页（根据平台选择相机或文件上传）
  Widget _buildScanQRTab(BuildContext context) {
    if (_isMobile) {
      // 移动端使用相机扫描
      return QRCodeScannerTab(
        onQRCodeScanned: _handleQRCodeScanned,
      );
    } else {
      // 桌面端使用文件上传
      return Padding(
        padding: const EdgeInsets.all(24),
        child: QRCodeUploadTab(
          onQRCodeScanned: _handleQRCodeScanned,
        ),
      );
    }
  }

  /// 处理扫描到的二维码
  Future<void> _handleQRCodeScanned(QRCodeData qrData) async {
    try {
      // 创建验证码会话
      final session = VerificationCodeManager.instance.createSession(
        remotePeerId: qrData.peerId,
        remoteDeviceName: qrData.deviceName,
      );

      // 显示验证码对话框
      if (!mounted) return;

      final displayResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => VerificationCodeDialog(
          session: session,
          onVerified: () {
            _showSuccessMessage(context, '配对成功', '设备 ${qrData.deviceName} 已成功配对');
          },
          onTimeout: () {
            _showErrorMessage(context, '验证超时', '验证码已过期，请重新扫描二维码');
          },
        ),
      );

      // 如果验证成功，调用配对回调
      if (displayResult == true) {
        try {
          final pairSuccess = await widget.onPairDevice(
            qrData.peerId,
            session.code,
          );

          if (!mounted) return;

          if (pairSuccess) {
            Navigator.of(context).pop(true);
          } else {
            _showErrorMessage(context, '配对失败', '无法完成设备配对，请重试');
          }
        } catch (e) {
          if (!mounted) return;
          _showErrorMessage(context, '配对错误', '配对过程中发生错误: $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, '处理失败', '二维码处理失败: $e');
    }
  }

  /// 构建设备信息
  Widget _buildDeviceInfo(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前设备信息',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(context, '设备名称', widget.currentDevice.name),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            '设备类型',
            _getDeviceTypeText(widget.currentDevice.type),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            'PeerId',
            PeerIdValidator.format(widget.currentDevice.id),
          ),
          if (widget.currentDevice.multiaddrs.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              '地址数量',
              '${widget.currentDevice.multiaddrs.length} 个',
            ),
          ],
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  /// 获取设备类型文本
  String _getDeviceTypeText(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return '手机';
      case DeviceType.laptop:
        return '笔记本电脑';
      case DeviceType.tablet:
        return '平板电脑';
    }
  }

  /// 显示成功消息
  void _showSuccessMessage(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示错误消息
  void _showErrorMessage(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
