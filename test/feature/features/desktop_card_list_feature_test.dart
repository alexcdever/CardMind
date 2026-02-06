import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  setUp(() {
    PlatformDetector.debugOverridePlatform = PlatformType.desktop;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_desktop_card_list_empty_state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('还没有笔记'), findsOneWidget);
  });
}
