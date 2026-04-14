import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS debug entitlements allow outbound and inbound network access', () {
    final contents = File(
      'macos/Runner/DebugProfile.entitlements',
    ).readAsStringSync();

    expect(contents, contains('com.apple.security.network.client'));
    expect(contents, contains('com.apple.security.network.server'));
  });

  test('macOS release entitlements allow outbound network access', () {
    final contents = File('macos/Runner/Release.entitlements')
        .readAsStringSync();

    expect(contents, contains('com.apple.security.network.client'));
  });
}
