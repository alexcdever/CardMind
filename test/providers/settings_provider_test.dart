import 'package:cardmind/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsProvider', () {
    late SettingsProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = SettingsProvider();
      await provider.initialize();
    });

    test('should initialize with default values', () {
      expect(provider.syncNotificationEnabled, true);
    });

    test('should toggle sync notification', () async {
      expect(provider.syncNotificationEnabled, true);

      await provider.toggleSyncNotification();
      expect(provider.syncNotificationEnabled, false);

      await provider.toggleSyncNotification();
      expect(provider.syncNotificationEnabled, true);
    });

    test('should persist sync notification setting', () async {
      await provider.setSyncNotificationEnabled(false);

      // Create new provider to test persistence
      final newProvider = SettingsProvider();
      await newProvider.initialize();

      expect(newProvider.syncNotificationEnabled, false);
    });

    test('should notify listeners on change', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setSyncNotificationEnabled(false);

      expect(notified, true);
    });
  });
}
