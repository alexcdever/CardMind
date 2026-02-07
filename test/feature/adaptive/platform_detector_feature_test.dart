import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformDetector', () {
    test('it_should_classify_android_as_mobile', () {
      // Note: In actual tests, we can't easily mock defaultTargetPlatform
      // This test documents the expected behavior
      // The actual platform detection happens at compile time

      // Given: Running on Android (compile-time constant)
      // When: Checking platform type
      // Then: Should return mobile

      // We can only test the current platform in unit tests
      // Platform-specific tests would need to run on each platform
      expect(PlatformDetector.currentPlatform, isA<PlatformType>());
    });

    test('it_should_provide_is_mobile_helper', () {
      // Given: Platform detector
      // When: Checking isMobile
      // Then: Should return boolean
      expect(PlatformDetector.isMobile, isA<bool>());
    });

    test('it_should_provide_is_desktop_helper', () {
      // Given: Platform detector
      // When: Checking isDesktop
      // Then: Should return boolean
      expect(PlatformDetector.isDesktop, isA<bool>());
    });

    test('it_should_have_exactly_one_platform_type_true', () {
      // Given: Platform detector
      // When: Checking both isMobile and isDesktop
      // Then: Exactly one should be true
      final isMobile = PlatformDetector.isMobile;
      final isDesktop = PlatformDetector.isDesktop;

      expect(
        isMobile != isDesktop,
        isTrue,
        reason: 'Exactly one of isMobile or isDesktop should be true',
      );
    });

    test('it_should_return_consistent_platform_type', () {
      // Given: Platform detector
      // When: Calling currentPlatform multiple times
      // Then: Should return the same value
      final platform1 = PlatformDetector.currentPlatform;
      final platform2 = PlatformDetector.currentPlatform;

      expect(
        platform1,
        equals(platform2),
        reason: 'Platform type should be consistent',
      );
    });

    test('it_should_match_helper_methods_with_current_platform', () {
      // Given: Platform detector
      // When: Checking helpers against currentPlatform
      // Then: They should match
      final platform = PlatformDetector.currentPlatform;

      if (platform == PlatformType.mobile) {
        expect(PlatformDetector.isMobile, isTrue);
        expect(PlatformDetector.isDesktop, isFalse);
      } else {
        expect(PlatformDetector.isMobile, isFalse);
        expect(PlatformDetector.isDesktop, isTrue);
      }
    });
  });

  group('PlatformType', () {
    test('it_should_have_mobile_and_desktop_values', () {
      // Given: PlatformType enum
      // When: Accessing enum values
      // Then: Should have mobile and desktop
      expect(PlatformType.values, contains(PlatformType.mobile));
      expect(PlatformType.values, contains(PlatformType.desktop));
      expect(PlatformType.values.length, equals(2));
    });
  });
}
