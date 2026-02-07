import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  setUp(() {
    PlatformDetector.debugOverridePlatform = PlatformType.mobile;
  });

  tearDown(() {
    PlatformDetector.debugOverridePlatform = null;
  });

  testWidgets('it_should_render_home_screen_shared_empty_state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TestApp(child: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('创建第一条笔记'), findsOneWidget);
  });
}
