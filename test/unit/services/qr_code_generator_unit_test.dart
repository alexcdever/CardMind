// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:cardmind/services/qr_code_generator.dart';
import 'package:cardmind/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QRCodeGenerator Tests', () {
    test('it_should_generates valid QR code bytes', () async {
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100)); // PNG 文件应该有一定大小
    });

    test('it_should_generates QR code with custom size', () async {
      final bytes300 = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 300,
      );

      final bytes500 = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 500,
      );

      expect(bytes300, isNotEmpty);
      expect(bytes500, isNotEmpty);
      // 更大的尺寸应该产生更大的文件
      expect(bytes500.length, greaterThan(bytes300.length));
    });

    test('it_should_generated QR code can be decoded', () async {
      // 生成二维码
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 300,
      );

      // 保存到临时文件
      final tempFile = File('test/fixtures/temp_qr_code.png');
      await tempFile.writeAsBytes(bytes);

      try {
        // 解码二维码
        final qrData = await QRCodeParser.parseFromFile(tempFile);

        // 验证数据
        expect(qrData.peerId, '12D3KooWTest123456789');
        expect(qrData.deviceName, 'Test Device');
        expect(qrData.deviceType, 'laptop');
        expect(qrData.multiaddrs, ['/ip4/192.168.1.100/tcp/4001']);
        expect(qrData.poolId, 'test-pool-id');
        expect(qrData.version, '1.0');
        expect(qrData.type, 'pairing');
      } finally {
        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('it_should_generates QR code with multiple multiaddrs', () async {
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: [
          '/ip4/192.168.1.100/tcp/4001',
          '/ip6/::1/tcp/4001',
          '/dns4/example.com/tcp/4001',
        ],
        poolId: 'test-pool-id',
      );

      expect(bytes, isNotEmpty);

      // 保存并解码验证
      final tempFile = File('test/fixtures/temp_qr_multi.png');
      await tempFile.writeAsBytes(bytes);

      try {
        final qrData = await QRCodeParser.parseFromFile(tempFile);
        expect(qrData.multiaddrs.length, 3);
        expect(qrData.multiaddrs[0], '/ip4/192.168.1.100/tcp/4001');
        expect(qrData.multiaddrs[1], '/ip6/::1/tcp/4001');
        expect(qrData.multiaddrs[2], '/dns4/example.com/tcp/4001');
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('it_should_generates QR code for different device types', () async {
      final deviceTypes = ['phone', 'laptop', 'tablet'];

      for (final deviceType in deviceTypes) {
        final bytes = await QRCodeGenerator.generatePairingQRCode(
          peerId: '12D3KooWTest123456789',
          deviceName: 'Test Device',
          deviceType: deviceType,
          multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
          poolId: 'test-pool-id',
        );

        expect(
          bytes,
          isNotEmpty,
          reason: 'Failed for device type: $deviceType',
        );

        // 验证可以解码
        final tempFile = File('test/fixtures/temp_qr_$deviceType.png');
        await tempFile.writeAsBytes(bytes);

        try {
          final qrData = await QRCodeParser.parseFromFile(tempFile);
          expect(qrData.deviceType, deviceType);
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    });

    test('it_should_generates QR code with timestamp', () async {
      final beforeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final bytes = await QRCodeGenerator.generatePairingQRCode(
        peerId: '12D3KooWTest123456789',
        deviceName: 'Test Device',
        deviceType: 'laptop',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      final afterTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 保存并解码验证时间戳
      final tempFile = File('test/fixtures/temp_qr_timestamp.png');
      await tempFile.writeAsBytes(bytes);

      try {
        final qrData = await QRCodeParser.parseFromFile(tempFile);

        // 时间戳应该在生成前后的时间范围内
        expect(qrData.timestamp, greaterThanOrEqualTo(beforeTime));
        expect(qrData.timestamp, lessThanOrEqualTo(afterTime));
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });
}
