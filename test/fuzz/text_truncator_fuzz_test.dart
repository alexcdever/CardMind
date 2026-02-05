import 'dart:math';

import 'package:cardmind/utils/text_truncator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_handle_random_text_without_crash', () {
    final random = Random(42);
    for (var i = 0; i < 200; i += 1) {
      final length = random.nextInt(512);
      final text = String.fromCharCodes(
        List.generate(length, (_) => random.nextInt(128)),
      );
      final cleaned = TextUtils.cleanTextForDisplay(text);
      expect(
        cleaned.contains(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]')),
        isFalse,
      );
      TextTruncator.truncateTitle(text);
      TextTruncator.truncateContent(text);
      TextTruncator.needsTruncation(text, 3);
      TextTruncator.getEstimatedCharsForLines(3);
      TextTruncator.wouldExceedContentLimit(text);
    }
  });
}
