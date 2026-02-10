// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:cardmind/services/qr_code_generator.dart';
import 'package:cardmind/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QRCodeGenerator Tests', () {
    test('it_should_generates valid QR code bytes', () async {
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('it_should_generates QR code with custom size', () async {
      final bytes300 = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 300,
      );

      final bytes500 = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 500,
      );

      expect(bytes300, isNotEmpty);
      expect(bytes500, isNotEmpty);
      expect(bytes500.length, greaterThan(bytes300.length));
    });

    test('it_should_generated QR code can be decoded', () async {
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
        size: 300,
      );

      final tempFile = File('test/fixtures/temp_qr_code.png');
      await tempFile.writeAsBytes(bytes);

      try {
        final qrData = await QRCodeParser.parseFromFile(tempFile);

        expect(qrData.multiaddrs, ['/ip4/192.168.1.100/tcp/4001']);
        expect(qrData.poolId, 'test-pool-id');
        expect(qrData.version, '1.0');
        expect(qrData.type, 'pool_join');
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('it_should_generates QR code with multiple multiaddrs', () async {
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: [
          '/ip4/192.168.1.100/tcp/4001',
          '/ip6/::1/tcp/4001',
          '/dns4/example.com/tcp/4001',
        ],
        poolId: 'test-pool-id',
      );

      expect(bytes, isNotEmpty);

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
  });
}
