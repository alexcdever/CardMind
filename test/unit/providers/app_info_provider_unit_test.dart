import 'package:cardmind/models/app_info.dart';
import 'package:cardmind/providers/app_info_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInfoProvider', () {
    late AppInfoProvider provider;

    setUp(() {
      provider = AppInfoProvider();
    });

    test('it_should_should initialize with default app info', () async {
      await provider.initialize();

      expect(provider.appInfo, isNotNull);
      expect(provider.appInfo.version, isNotEmpty);
    });

    test('it_should_should allow setting custom app info', () {
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

    test('it_should_should notify listeners on change', () {
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

    test('it_should_initialize_overwrites_custom_info', () async {
      const customInfo = AppInfo(
        version: '9.9.9',
        buildNumber: '999',
        description: 'Custom',
        homepage: 'https://example.com',
        issuesUrl: 'https://example.com/issues',
        contributors: ['Tester'],
        changelog: [],
      );
      provider.setAppInfo(customInfo);

      await provider.initialize();

      expect(provider.appInfo.version, '0.1.0');
    });

    test('it_should_setAppInfo_updates_instance', () {
      const customInfo = AppInfo(
        version: '3.0.0',
        buildNumber: '300',
        description: 'Another',
        homepage: 'https://example.com',
        issuesUrl: 'https://example.com/issues',
        contributors: ['Tester'],
        changelog: [],
      );

      provider.setAppInfo(customInfo);

      expect(provider.appInfo, same(customInfo));
    });
  });
}
