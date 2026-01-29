import 'package:flutter/material.dart';
import '../models/app_info.dart';

/// Provider for managing app information
class AppInfoProvider extends ChangeNotifier {
  AppInfo _appInfo = AppInfo.defaultInfo();

  AppInfo get appInfo => _appInfo;

  /// Initialize app info
  /// In a real app, this might load from package_info_plus or a config file
  Future<void> initialize() async {
    // For now, use default info
    // In production, you might load from:
    // - package_info_plus for version/build number
    // - assets/app_info.json for contributors/changelog
    _appInfo = AppInfo.defaultInfo();
    notifyListeners();
  }

  /// Update app info (for testing or dynamic updates)
  void setAppInfo(AppInfo info) {
    _appInfo = info;
    notifyListeners();
  }
}
