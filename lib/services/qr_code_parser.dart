import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

/// 二维码数据模型
class QRCodeData {
  QRCodeData({
    required this.version,
    required this.type,
    required this.multiaddrs,
    required this.poolId,
  });

  factory QRCodeData.fromJson(Map<String, dynamic> json) {
    return QRCodeData(
      version: json['version'] as String,
      type: json['type'] as String,
      multiaddrs: (json['multiaddrs'] as List).cast<String>(),
      poolId: json['poolId'] as String,
    );
  }
  final String version;
  final String type;
  final List<String> multiaddrs;
  final String poolId;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'multiaddrs': multiaddrs,
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
        rgbaImage.getBytes(order: img.ChannelOrder.rgba).buffer.asInt32List(),
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
    if (data.type != 'pool_join') {
      throw Exception('无效的二维码类型: ${data.type}');
    }

    // 验证 Multiaddrs
    if (data.multiaddrs.isEmpty) {
      throw Exception('Multiaddrs 不能为空');
    }

    // 验证 PoolId
    if (data.poolId.isEmpty) {
      throw Exception('PoolId 不能为空');
    }
  }

  /// 生成二维码数据（用于测试）
  static String generateQRData({
    required List<String> multiaddrs,
    required String poolId,
  }) {
    final data = QRCodeData(
      version: '1.0',
      type: 'pool_join',
      multiaddrs: multiaddrs,
      poolId: poolId,
    );

    return jsonEncode(data.toJson());
  }
}
