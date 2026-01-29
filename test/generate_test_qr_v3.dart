import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';
import 'package:cardmind/services/qr_code_parser.dart';

void main() async {
  // 生成测试用的二维码数据
  final qrDataJson = QRCodeParser.generateQRData(
    peerId: '12D3KooWTest123456789',
    deviceName: 'Test Device',
    deviceType: 'laptop',
    multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
    poolId: 'test-pool-id-123',
  );

  print('QR Data: $qrDataJson');

  // 使用 zxing_lib 生成二维码
  final writer = QRCodeWriter();
  final hints = EncodeHint(
    errorCorrectionLevel: ErrorCorrectionLevel.H,
    margin: 1,
  );

  final bitMatrix = writer.encode(
    qrDataJson,
    BarcodeFormat.qrCode,
    300,
    300,
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

  // 保存到文件
  final file = File('test/fixtures/test_qr_code.png');
  await file.writeAsBytes(img.encodePng(image));

  print('QR code saved to: ${file.path}');
  print('Image size: ${image.width}x${image.height}');

  // 立即测试解码
  print('\nTesting decode...');
  try {
    final decoded = await QRCodeParser.parseFromFile(file);
    print('Decode successful!');
    print('PeerId: ${decoded.peerId}');
    print('Device Name: ${decoded.deviceName}');
    print('Device Type: ${decoded.deviceType}');
  } catch (e) {
    print('Decode failed: $e');
  }
}
