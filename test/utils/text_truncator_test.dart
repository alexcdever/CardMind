import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/utils/text_truncator.dart';

/// Unit tests for TextTruncator utility
/// Based on design specification section 5.2.1
void main() {
  group('TextTruncator Unit Tests', () {
    group('Platform-specific Line Limits', () {
      test('it_should_return_correct_lines_for_platform', () {
        // Given: Current platform (test environment)
        // When: Get max content lines
        final maxLines = TextTruncator.getContentMaxLines();

        // Then: Should return appropriate lines for current platform
        // In test environment, this typically defaults to desktop (4 lines)
        expect(maxLines, isIn([3, 4])); // Accept either mobile or desktop value
      });

      test('it_should_return_1_line_for_title', () {
        // When: Get max title lines
        final maxLines = TextTruncator.maxTitleLines;

        // Then: Should always return 1 line for title
        expect(maxLines, equals(1));
      });

      test('it_should_truncate_title_with_placeholder_for_empty_text', () {
        // Given: Empty title text
        const emptyTitle = '';

        // When: Truncate title
        final result = TextTruncator.truncateTitle(emptyTitle);

        // Then: Should return placeholder text
        expect(result, equals('无标题'));
      });

      test('it_should_preserve_non_empty_title_text', () {
        // Given: Non-empty title text
        const title = '测试标题';

        // When: Truncate title
        final result = TextTruncator.truncateTitle(title);

        // Then: Should return original text
        expect(result, equals(title));
      });

      test('it_should_truncate_content_with_placeholder_for_empty_text', () {
        // Given: Empty content text
        const emptyContent = '';

        // When: Truncate content
        final result = TextTruncator.truncateContent(emptyContent);

        // Then: Should return placeholder text
        expect(result, equals('点击添加内容...'));
      });

      test('it_should_preserve_non_empty_content_text', () {
        // Given: Non-empty content text
        const content = '这是一些测试内容';

        // When: Truncate content
        final result = TextTruncator.truncateContent(content);

        // Then: Should return original text
        expect(result, equals(content));
      });
    });

    group('Text Length Analysis', () {
      test('it_should_estimate_characters_per_line_correctly', () {
        // When: Get estimated characters for lines
        final charsFor2Lines = TextTruncator.getEstimatedCharsForLines(2);
        final charsFor4Lines = TextTruncator.getEstimatedCharsForLines(4);

        // Then: Should return correct estimates (35 chars per line)
        expect(charsFor2Lines, equals(70));
        expect(charsFor4Lines, equals(140));
      });

      test('it_should_detect_truncation_need_based_on_length', () {
        // Given: Text lengths that exceed typical limits
        const shortText = '短文本';
        const longText =
            '这是一段非常长的文本，包含了很多中文字符，'
            '远远超过了正常的显示长度限制，需要进行截断处理，'
            '否则在卡片中显示时会超出预定的行数限制，'
            '这段文字足够长以确保能够触发截断检测的逻辑判断条件。';

        // When: Check if truncation is needed for 2 lines (60 chars)
        final shortNeedsTruncation = TextTruncator.needsTruncation(
          shortText,
          2,
        );
        final longNeedsTruncation = TextTruncator.needsTruncation(longText, 2);

        // Then: Short text shouldn't need truncation, long text should
        expect(shortNeedsTruncation, isFalse);
        expect(longNeedsTruncation, isTrue);
      });

      test('it_should_detect_content_limit_exceeded', () {
        // Given: Short and long content
        const shortContent = '短内容';
        const longContent =
            '这是一段非常长的内容，包含了很多中文字符，'
            '远远超过了正常的显示长度限制，需要进行截断处理，'
            '否则在卡片中显示时会超出预定的行数限制，'
            '这段文字足够长以确保能够触发内容限制检测的逻辑判断条件，'
            '我们需要继续添加更多的文字内容来确保长度能够超过估计的字符数限制，'
            '这样才能够真正测试到内容限制检测的功能是否正常工作。';

        // When: Check if content limit is exceeded
        final shortExceedsLimit = TextTruncator.wouldExceedContentLimit(
          shortContent,
        );
        final longExceedsLimit = TextTruncator.wouldExceedContentLimit(
          longContent,
        );

        // Then: Results should be correct
        expect(shortExceedsLimit, isFalse);
        expect(longExceedsLimit, isTrue);
      });
    });

    group('Text Validation', () {
      test('it_should_validate_empty_text_as_valid', () {
        // Given: Empty text
        const emptyText = '';

        // When: Validate for display
        final isValid = TextTruncator.isValidForDisplay(
          emptyText,
          isTitle: true,
        );

        // Then: Should be valid (will show placeholder)
        expect(isValid, isTrue);
      });

      test('it_should_validate_reasonable_length_text_as_valid', () {
        // Given: Reasonable length text
        const reasonableText = '这是一段长度合理的文本内容，适合在卡片中显示。';

        // When: Validate for display
        final isValid = TextTruncator.isValidForDisplay(
          reasonableText,
          isTitle: false,
        );

        // Then: Should be valid
        expect(isValid, isTrue);
      });

      test('it_should_invalidate_excessively_long_text', () {
        // Given: Excessively long text (>10k characters)
        final longText = '长文本' * 5000; // 15k+ characters

        // When: Validate for display
        final isValid = TextTruncator.isValidForDisplay(
          longText,
          isTitle: false,
        );

        // Then: Should be invalid
        expect(isValid, isFalse);
      });

      test('it_should_invalidate_text_with_control_characters', () {
        // Given: Text with control characters
        const textWithControlChars = '正常文本\x00异常文本';

        // When: Validate for display
        final isValid = TextTruncator.isValidForDisplay(
          textWithControlChars,
          isTitle: false,
        );

        // Then: Should be invalid
        expect(isValid, isFalse);
      });
    });

    group('Text Processing', () {
      test('it_should_get_placeholder_text_correctly', () {
        // When: Get placeholder texts
        final titlePlaceholder = TextTruncator.getPlaceholderText(
          isTitle: true,
          isContent: false,
        );
        final contentPlaceholder = TextTruncator.getPlaceholderText(
          isTitle: false,
          isContent: true,
        );

        // Then: Should return correct placeholders
        expect(titlePlaceholder, equals('无标题'));
        expect(contentPlaceholder, equals('点击添加内容...'));
      });

      test('it_should_clean_text_by_removing_control_characters', () {
        // Given: Text with control characters
        const dirtyText = '正常文本\x00\x01\x02异常文本';

        // When: Clean text
        final cleanedText = TextUtils.cleanTextForDisplay(dirtyText);

        // Then: Should remove control characters
        expect(cleanedText, equals('正常文本异常文本'));
      });

      test('it_should_clean_text_by_normalizing_whitespace', () {
        // Given: Text with mixed whitespace
        const textWithWhitespace = '正常文本\t\n\r异常文本\f\v';

        // When: Clean text
        final cleanedText = TextUtils.cleanTextForDisplay(textWithWhitespace);

        // Then: Should normalize whitespace
        expect(cleanedText, equals('正常文本 异常文本'));
      });

      test('it_should_estimate_reading_time', () {
        // Given: Texts of different lengths
        const shortText = '短文本';
        const mediumText = '这是一段中等长度的文本内容，适合测试阅读时间估算功能。';

        // When: Estimate reading time
        final shortTime = TextUtils.estimateReadingTime(shortText);
        final mediumTime = TextUtils.estimateReadingTime(mediumText);

        // Then: Should return reasonable estimates (in seconds)
        expect(shortTime, greaterThan(0));
        expect(mediumTime, greaterThan(shortTime));
      });

      test('it_should_count_actual_lines_correctly', () {
        // Given: Texts with different line counts
        const singleLineText = '单行文本';
        const multiLineText = '第一行\n第二行\n第三行';

        // When: Count actual lines
        final singleLineCount = TextUtils.countActualLines(singleLineText);
        final multiLineCount = TextUtils.countActualLines(multiLineText);

        // Then: Should count correctly
        expect(singleLineCount, equals(1));
        expect(multiLineCount, equals(3));
      });

      test('it_should_get_first_n_lines_correctly', () {
        // Given: Multi-line text
        const multiLineText = '第一行\n第二行\n第三行\n第四行\n第五行';

        // When: Get first N lines
        final first2Lines = TextUtils.getFirstNLines(multiLineText, 2);
        final first4Lines = TextUtils.getFirstNLines(multiLineText, 4);

        // Then: Should return correct lines
        expect(first2Lines, equals('第一行\n第二行'));
        expect(first4Lines, equals('第一行\n第二行\n第三行\n第四行'));
      });
    });

    group('TextUtils Functions', () {
      test('it_should_batch_process_multiple_texts', () {
        // Given: Multiple texts
        final texts = ['标题1', '标题2', '内容1', '内容2'];

        // When: Batch process as titles
        final results = TextUtils.batchProcessTexts(texts, isTitle: true);

        // Then: Should process all texts
        expect(results.length, equals(4));
        expect(results['标题1'], equals('标题1'));
        expect(results['内容1'], equals('内容1'));
      });

      test('it_should_split_text_into_lines', () {
        // Given: Text to split
        const text = '这是一段需要被分割成多行的文本内容';

        // When: Split into lines
        final lines = TextTruncator.splitIntoLines(text, 2);

        // Then: Should split correctly
        expect(lines.length, lessThanOrEqualTo(2));
        expect(lines, isNotEmpty);
      });

      test('it_should_calculate_text_height', () {
        // Given: Text and style parameters
        const text = '测试文本';
        const style = TextStyle(fontSize: 14);
        const maxWidth = 200.0;
        const maxLines = 2;

        // When: Calculate text height
        final height = TextTruncator.calculateTextHeight(
          text,
          style,
          maxWidth,
          maxLines,
        );

        // Then: Should return reasonable height
        expect(height, greaterThan(0));
        expect(height, lessThan(100)); // Sanity check
      });
    });
  });
}
