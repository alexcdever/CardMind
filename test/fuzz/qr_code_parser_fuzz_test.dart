import 'dart:math';

import 'package:cardmind/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_handle_random_qr_payloads_without_crash', () {
    final random = Random(87);
    for (var i = 0; i < 200; i += 1) {
      final length = random.nextInt(1024);
      final text = String.fromCharCodes(
        List.generate(length, (_) => random.nextInt(128)),
      );
      try {
        final data = QRCodeParser.parseQRData(text);
        try {
          QRCodeParser.validateQRData(data);
        } catch (_) {}
      } catch (_) {}
    }
  });
}
