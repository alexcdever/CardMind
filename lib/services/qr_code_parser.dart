import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

/// 二维码数据模型
class QRCodeData {
  final String version;
  final String type;
  final String peerId;
  final String deviceName;
  final String deviceType;
  final List<String> multiaddrs;
  final int timestamp;
  final String poolId;

  QRCodeData({
    required this.version,
    required this.type,
    required this.peerId,
    required this.deviceName,
    required this.deviceType,
    required this.multiaddrs,
    required this.timestamp,
    required this.poolId,
  });

  factory QRCodeData.fromJson(Map<String, dynamic> json) {
    return QRCodeData(
      version: json['version'] as String,
      type: json['type'] as String,
      peerId: json['peerId'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: json['deviceType'] as String,
      multiaddrs: (json['multiaddrs'] as List).cast<String>(),
      timestamp: json['timestamp'] as int,
      poolId: json['poolId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'peerId': peerId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'multiaddrs': multiaddrs,
      'timestamp': timestamp,
      'poolId': poolId,
    };
  }
}

/// 二维码解析服务
class QRCodeParser {
  /// 从文件解析二维码
  ///
  /// 返回解析后的二维码数据，如果解析失败则抛出异常。
  static Future<QRCodeData> parseFromFile(File file) async {
    // 读取图片
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('无法解析图片文件');
    }

    // 解析二维码
    final result = _decodeQRCode(image);

    if (result == null) {
      throw Exception('未找到有效的二维码');
    }

    // 解析 JSON 数据
    final qrData = parseQRData(result);

    // 验证数据
    validateQRData(qrData);

    return qrData;
  }

  /// 解码二维码图片
  static String? _decodeQRCode(img.Image image) {
    try {
      // 转换图片为 RGBA 格式
      final rgbaImage = image.convert(numChannels: 4);

      // 创建 LuminanceSource
      final source = RGBLuminanceSource(
        rgbaImage.width,
        rgbaImage.height,
        rgbaImage
            .getBytes(order: img.ChannelOrder.rgba)
            .buffer
            .asInt32List(),
      );

      // 创建 BinaryBitmap
      final bitmap = BinaryBitmap(HybridBinarizer(source));

      // 使用 QRCodeReader 解码
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);

      return result.text;
    } on Exception {
      // 解码失败返回 null
      return null;
    }
  }

  /// 解析二维码数据
  static QRCodeData parseQRData(String qrText) {
    try {
      final json = jsonDecode(qrText) as Map<String, dynamic>;
      return QRCodeData.fromJson(json);
    } catch (e) {
      throw Exception('二维码数据格式错误: $e');
    }
  }

  /// 验证二维码数据
  static void validateQRData(QRCodeData data) {
    // 验证版本
    if (data.version != '1.0') {
      throw Exception('不支持的二维码版本: ${data.version}');
    }

    // 验证类型
    if (data.type != 'pairing') {
      throw Exception('无效的二维码类型: ${data.type}');
    }

    // 验证 PeerId
    if (data.peerId.isEmpty) {
      throw Exception('PeerId 不能为空');
    }

    // 验证设备名称
    if (data.deviceName.isEmpty) {
      throw Exception('设备名称不能为空');
    }

    // 验证设备类型
    if (!['phone', 'laptop', 'tablet'].contains(data.deviceType)) {
      throw Exception('无效的设备类型: ${data.deviceType}');
    }

    // 验证 Multiaddrs
    if (data.multiaddrs.isEmpty) {
      throw Exception('Multiaddrs 不能为空');
    }

    // 验证时间戳（10 分钟有效期）
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = now - data.timestamp;

    if (age < 0) {
      throw Exception('二维码时间戳无效（未来时间）');
    }

    if (age > 600) {
      // 10 分钟 = 600 秒
      throw Exception('二维码已过期（超过 10 分钟）');
    }

    // 验证 PoolId
    if (data.poolId.isEmpty) {
      throw Exception('PoolId 不能为空');
    }
  }

  /// 生成二维码数据（用于测试）
  static String generateQRData({
    required String peerId,
    required String deviceName,
    required String deviceType,
    required List<String> multiaddrs,
    required String poolId,
  }) {
    final data = QRCodeData(
      version: '1.0',
      type: 'pairing',
      peerId: peerId,
      deviceName: deviceName,
      deviceType: deviceType,
      multiaddrs: multiaddrs,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      poolId: poolId,
    );

    return jsonEncode(data.toJson());
  }
}
