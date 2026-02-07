import 'package:cardmind/constants/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_expose_storage_key_constants', () {
    expect(StorageKeys.themeMode, 'theme_mode');
    expect(StorageKeys.syncNotificationEnabled, 'sync_notification_enabled');
  });
}
