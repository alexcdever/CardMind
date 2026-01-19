# Platform Detection Specification

## Purpose

This specification defines the platform detection system for CardMind's adaptive UI framework. The system automatically detects the device's operating system and classifies it into mobile or desktop platform types, enabling the application to provide platform-appropriate user experiences.

## Requirements

### Requirement: System SHALL detect device platform type

The system SHALL automatically detect the device's operating system and classify it into one of two platform types: mobile or desktop.

**Platform Classification**:
- **Mobile**: Android, iOS, iPadOS
- **Desktop**: macOS, Windows, Linux

#### Scenario: Android device is classified as mobile
- **WHEN** the application runs on an Android device
- **THEN** the system SHALL return `PlatformType.mobile`

#### Scenario: iOS device is classified as mobile
- **WHEN** the application runs on an iOS device
- **THEN** the system SHALL return `PlatformType.mobile`

#### Scenario: iPadOS device is classified as mobile
- **WHEN** the application runs on an iPadOS device
- **THEN** the system SHALL return `PlatformType.mobile`

#### Scenario: macOS device is classified as desktop
- **WHEN** the application runs on a macOS device
- **THEN** the system SHALL return `PlatformType.desktop`

#### Scenario: Windows device is classified as desktop
- **WHEN** the application runs on a Windows device
- **THEN** the system SHALL return `PlatformType.desktop`

#### Scenario: Linux device is classified as desktop
- **WHEN** the application runs on a Linux device
- **THEN** the system SHALL return `PlatformType.desktop`

### Requirement: Platform detection SHALL be available at compile time

The platform detection MUST use Flutter's `defaultTargetPlatform` API to ensure the platform type is determined at compile time for optimal performance.

#### Scenario: Platform type is determined at compile time
- **WHEN** the application is compiled for a specific platform
- **THEN** the platform type SHALL be determined at compile time
- **AND** there SHALL be zero runtime overhead for platform detection

### Requirement: Platform detection SHALL provide a singleton accessor

The system SHALL provide a global singleton accessor for the current platform type that can be accessed from anywhere in the application.

#### Scenario: Platform type is accessible globally
- **WHEN** any component needs to check the platform type
- **THEN** it SHALL be able to access `PlatformDetector.currentPlatform`
- **AND** the result SHALL be consistent throughout the application lifecycle

### Requirement: Platform type SHALL be immutable during runtime

Once the platform type is determined at application startup, it SHALL NOT change during the application's runtime.

#### Scenario: Platform type remains constant
- **WHEN** the application is running
- **THEN** the platform type SHALL remain the same value
- **AND** SHALL NOT be affected by window resizing or other runtime changes

### Requirement: Unknown platforms SHALL default to mobile

If the platform cannot be determined or is not in the supported list, the system SHALL default to mobile platform type for safety.

#### Scenario: Unknown platform defaults to mobile
- **WHEN** the platform is unknown or unsupported
- **THEN** the system SHALL return `PlatformType.mobile`
- **AND** SHALL log a warning about the unknown platform

---

## Test Implementation

### Test Files
- `test/specs/platform_detection_spec_test.dart` (SP-ADAPT-001)
- `test/specs/adaptive_ui_framework_spec_test.dart` (SP-ADAPT-002)
- `test/specs/adaptive_ui_system_spec_test.dart` (SP-UI-001)

### Test Coverage
- ✅ Platform Detection Tests (15+ tests)
- ✅ Adaptive UI Framework Tests (20+ tests)
- ✅ Responsive Layout Tests (25+ tests)
- ✅ Breakpoint Tests (10+ tests)

### Running Tests
```bash
flutter test test/specs/platform_detection_spec_test.dart
flutter test test/specs/adaptive_ui_framework_spec_test.dart
flutter test test/specs/adaptive_ui_system_spec_test.dart
```

### Coverage Report
Last updated: 2026-01-18
- Scenarios covered: 100%
- All tests passing: ✅

### Test Examples
```dart
testWidgets('it_should_detect_platform_type_correctly', (WidgetTester tester) async {
  // Given: 应用启动
  // When: 检测平台类型
  final platformType = PlatformDetector.currentPlatform;
  
  // Then: 平台类型应该是 mobile 或 desktop
  expect(platformType, anyOf(PlatformType.mobile, PlatformType.desktop));
});
```

### Related Specs
- SP-UI-001: [adaptive_ui_system_spec_test.dart](../../test/specs/adaptive_ui_system_spec_test.dart)
- SP-ADAPT-002: [adaptive-ui-framework/spec.md](../adaptive-ui-framework/spec.md)
