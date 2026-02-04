import 'package:cardmind/providers/app_info_provider.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/providers/settings_provider.dart';
import 'package:cardmind/providers/theme_provider.dart';
import 'package:cardmind/screens/settings_screen.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_card_service.dart';

Future<void> _pumpSettingsScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  PlatformDetector.debugOverridePlatform = PlatformType.desktop;
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CardProvider(cardService: MockCardService()),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppInfoProvider()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen', () {
    tearDown(() {
      PlatformDetector.debugOverridePlatform = null;
    });
    testWidgets(
      'it_should_not_display_mdns_toggle',
      (WidgetTester tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await _pumpSettingsScreen(tester);

        expect(find.text('mDNS Discovery'), findsNothing);
        expect(find.text('Enable 5 min'), findsNothing);
        expect(find.text('Turn Off'), findsNothing);
      },
    );
  });
}
