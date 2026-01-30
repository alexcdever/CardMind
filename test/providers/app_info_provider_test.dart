import 'package:cardmind/models/app_info.dart';
import 'package:cardmind/providers/app_info_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInfoProvider', () {
    late AppInfoProvider provider;

    setUp(() {
      provider = AppInfoProvider();
    });

    test('should initialize with default app info', () async {
      await provider.initialize();

      expect(provider.appInfo, isNotNull);
      expect(provider.appInfo.version, isNotEmpty);
    });

    test('should allow setting custom app info', () {
      const customInfo = AppInfo(
        version: '2.0.0',
        buildNumber: '100',
        description: 'Custom description',
        homepage: 'https://example.com',
        issuesUrl: 'https://example.com/issues',
        contributors: ['Test User'],
        changelog: [],
      );

      provider.setAppInfo(customInfo);

      expect(provider.appInfo.version, '2.0.0');
      expect(provider.appInfo.buildNumber, '100');
    });

    test('should notify listeners on change', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      const customInfo = AppInfo(
        version: '2.0.0',
        buildNumber: '100',
        description: 'Custom description',
        homepage: 'https://example.com',
        issuesUrl: 'https://example.com/issues',
        contributors: ['Test User'],
        changelog: [],
      );

      provider.setAppInfo(customInfo);

      expect(notified, true);
    });
  });
}
