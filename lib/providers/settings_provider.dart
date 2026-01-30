import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

/// Provider for managing app settings
class SettingsProvider extends ChangeNotifier {
  bool _syncNotificationEnabled = true;

  bool get syncNotificationEnabled => _syncNotificationEnabled;

  /// Initialize settings from saved preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _syncNotificationEnabled =
          prefs.getBool(StorageKeys.syncNotificationEnabled) ?? true;
    } on Exception {
      // Handle corrupted settings data by falling back to default
      _syncNotificationEnabled = true;
    }
    notifyListeners();
  }

  /// Set sync notification enabled state and persist to preferences
  Future<void> setSyncNotificationEnabled(bool enabled) async {
    if (_syncNotificationEnabled == enabled) return;

    _syncNotificationEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.syncNotificationEnabled, enabled);
  }

  /// Toggle sync notification enabled state
  Future<void> toggleSyncNotification() async {
    await setSyncNotificationEnabled(!_syncNotificationEnabled);
  }
}
