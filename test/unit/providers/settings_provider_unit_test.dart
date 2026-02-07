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

    test('it_should_should initialize with default values', () {
      expect(provider.syncNotificationEnabled, true);
    });

    test('it_should_should toggle sync notification', () async {
      expect(provider.syncNotificationEnabled, true);

      await provider.toggleSyncNotification();
      expect(provider.syncNotificationEnabled, false);

      await provider.toggleSyncNotification();
      expect(provider.syncNotificationEnabled, true);
    });

    test('it_should_should persist sync notification setting', () async {
      await provider.setSyncNotificationEnabled(false);

      // Create new provider to test persistence
      final newProvider = SettingsProvider();
      await newProvider.initialize();

      expect(newProvider.syncNotificationEnabled, false);
    });

    test('it_should_should notify listeners on change', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setSyncNotificationEnabled(false);

      expect(notified, true);
    });

    test('it_should_initialize_with_corrupted_storage_defaults_true', () async {
      SharedPreferences.setMockInitialValues({
        'sync_notification_enabled': 'invalid',
      });
      final newProvider = SettingsProvider();

      await newProvider.initialize();

      expect(newProvider.syncNotificationEnabled, true);
    });

    test('it_should_not_notify_when_setting_same_value', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setSyncNotificationEnabled(true);

      expect(notified, false);
    });

    test('it_should_setSyncNotificationEnabled_updates_value', () async {
      await provider.setSyncNotificationEnabled(false);

      expect(provider.syncNotificationEnabled, false);
    });
  });
}
