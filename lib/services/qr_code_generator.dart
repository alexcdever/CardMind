import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

import 'package:cardmind/services/qr_code_parser.dart';

/// 二维码生成服务
class QRCodeGenerator {
  /// 生成设备配对二维码
  ///
  /// 参数:
  /// - [peerId]: 设备的 libp2p PeerId
  /// - [deviceName]: 设备名称
  /// - [deviceType]: 设备类型 (phone/laptop/tablet)
  /// - [multiaddrs]: 设备的 Multiaddr 地址列表
  /// - [poolId]: 数据池 ID
  /// - [size]: 二维码尺寸（默认 240x240）
  ///
  /// 返回: PNG 格式的二维码图片字节数据
  static Future<Uint8List> generatePairingQRCode({
    required String peerId,
    required String deviceName,
    required String deviceType,
    required List<String> multiaddrs,
    required String poolId,
    int size = 240,
  }) async {
    // 生成 JSON 数据
    final qrDataJson = QRCodeParser.generateQRData(
      peerId: peerId,
      deviceName: deviceName,
      deviceType: deviceType,
      multiaddrs: multiaddrs,
      poolId: poolId,
    );

    // 使用 zxing_lib 生成二维码
    final writer = QRCodeWriter();
    final hints = EncodeHint(
      errorCorrectionLevel: ErrorCorrectionLevel.H,
      margin: 1,
    );

    final bitMatrix = writer.encode(
      qrDataJson,
      BarcodeFormat.qrCode,
      size,
      size,
      hints,
    );

    // 创建图片
    final image = img.Image(width: bitMatrix.width, height: bitMatrix.height);

    // 填充图片
    for (var y = 0; y < bitMatrix.height; y++) {
      for (var x = 0; x < bitMatrix.width; x++) {
        final color = bitMatrix.get(x, y)
            ? img.ColorRgb8(0, 0, 0)
            : img.ColorRgb8(255, 255, 255);
        image.setPixel(x, y, color);
      }
    }

    // 编码为 PNG
    return Uint8List.fromList(img.encodePng(image));
  }

  /// 生成二维码 Widget
  ///
  /// 参数同 [generatePairingQRCode]
  ///
  /// 返回: 显示二维码的 Widget
  static Widget buildQRCodeWidget({
    required String peerId,
    required String deviceName,
    required String deviceType,
    required List<String> multiaddrs,
    required String poolId,
    int size = 240,
  }) {
    return FutureBuilder<Uint8List>(
      future: generatePairingQRCode(
        peerId: peerId,
        deviceName: deviceName,
        deviceType: deviceType,
        multiaddrs: multiaddrs,
        poolId: poolId,
        size: size,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size.toDouble(),
            height: size.toDouble(),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            width: size.toDouble(),
            height: size.toDouble(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    '生成失败',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return SizedBox(
            width: size.toDouble(),
            height: size.toDouble(),
          );
        }

        return Image.memory(
          snapshot.data!,
          width: size.toDouble(),
          height: size.toDouble(),
          fit: BoxFit.contain,
        );
      },
    );
  }

  /// 生成二维码并保存为 Image 对象（用于分享等场景）
  static Future<ui.Image> generateQRCodeImage({
    required String peerId,
    required String deviceName,
    required String deviceType,
    required List<String> multiaddrs,
    required String poolId,
    int size = 240,
  }) async {
    final bytes = await generatePairingQRCode(
      peerId: peerId,
      deviceName: deviceName,
      deviceType: deviceType,
      multiaddrs: multiaddrs,
      poolId: poolId,
      size: size,
    );

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
