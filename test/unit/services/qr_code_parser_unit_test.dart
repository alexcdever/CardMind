// ignore_for_file: avoid_print, avoid_slow_async_io

import 'dart:io';

import 'package:cardmind/services/qr_code_generator.dart';
import 'package:cardmind/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QRCodeData Model Tests', () {
    test('it_should_fromJson creates valid QRCodeData', () {
      final json = {
        'version': '1.0',
        'type': 'pool_join',
        'multiaddrs': ['/ip4/192.168.1.100/tcp/4001'],
        'poolId': 'test-pool-id',
      };

      final qrData = QRCodeData.fromJson(json);

      expect(qrData.version, '1.0');
      expect(qrData.type, 'pool_join');
      expect(qrData.multiaddrs.length, 1);
      expect(qrData.poolId, 'test-pool-id');
    });

    test('it_should_toJson creates valid JSON', () {
      final qrData = QRCodeData(
        version: '1.0',
        type: 'pool_join',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      final json = qrData.toJson();

      expect(json['version'], '1.0');
      expect(json['type'], 'pool_join');
      expect(json['multiaddrs'], isA<List<dynamic>>());
      expect(json['poolId'], 'test-pool-id');
    });
  });

  group('QRCodeParser Validation Tests', () {
    test('it_should_generateQRData creates valid JSON string', () {
      final qrDataJson = QRCodeParser.generateQRData(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      expect(qrDataJson, isNotEmpty);
      expect(qrDataJson, contains('pool_join'));
      expect(qrDataJson, contains('test-pool-id'));
    });

    test('it_should_reject_invalid_version', () {
      final data = QRCodeData(
        version: '2.0',
        type: 'pool_join',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      expect(() => QRCodeParser.validateQRData(data), throwsA(isA<Exception>()));
    });

    test('it_should_reject_invalid_type', () {
      final data = QRCodeData(
        version: '1.0',
        type: 'pairing',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id',
      );

      expect(() => QRCodeParser.validateQRData(data), throwsA(isA<Exception>()));
    });

    test('it_should_reject_empty_multiaddrs', () {
      final data = QRCodeData(
        version: '1.0',
        type: 'pool_join',
        multiaddrs: <String>[],
        poolId: 'test-pool-id',
      );

      expect(() => QRCodeParser.validateQRData(data), throwsA(isA<Exception>()));
    });

    test('it_should_reject_empty_pool_id', () {
      final data = QRCodeData(
        version: '1.0',
        type: 'pool_join',
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: '',
      );

      expect(() => QRCodeParser.validateQRData(data), throwsA(isA<Exception>()));
    });
  });

  group('QRCodeParser Decoding Tests', () {
    test('it_should_parseFromFile decodes valid QR code image', () async {
      final file = File('test/fixtures/tmp_qr_code.png');
      final bytes = await QRCodeGenerator.generatePairingQRCode(
        multiaddrs: ['/ip4/192.168.1.100/tcp/4001'],
        poolId: 'test-pool-id-123',
      );

      await file.writeAsBytes(bytes);

      try {
        final qrData = await QRCodeParser.parseFromFile(file);

        expect(qrData.version, '1.0');
        expect(qrData.type, 'pool_join');
        expect(qrData.multiaddrs, ['/ip4/192.168.1.100/tcp/4001']);
        expect(qrData.poolId, 'test-pool-id-123');
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('it_should_parseFromFile throws on invalid image', () async {
      final file = File('test/fixtures/invalid_image.txt');
      await file.writeAsString('not an image');

      expect(() => QRCodeParser.parseFromFile(file), throwsA(isA<Exception>()));

      await file.delete();
    });

    test('it_should_parseFromFile throws on image without QR code', () async {
      // 创建一个空白图片
      final file = File('test/fixtures/blank_image.png');
      // 这个测试需要一个真实的空白图片，暂时跳过
      if (!await file.exists()) {
        print('Skipping test: blank image not available');
        return;
      }

      expect(() => QRCodeParser.parseFromFile(file), throwsA(isA<Exception>()));
    });
  });
}
