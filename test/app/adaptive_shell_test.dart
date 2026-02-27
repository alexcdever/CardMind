import 'package:cardmind/app/layout/adaptive_shell.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses bottom nav on mobile width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveShellForTest(width: 390)),
    );

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses navigation rail on desktop width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveShellForTest(width: 1200)),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}

class AdaptiveShellForTest extends StatelessWidget {
  const AdaptiveShellForTest({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 844)),
      child: const AdaptiveShell(
        section: AppSection.cards,
        onSectionChanged: _noopSectionChanged,
        child: SizedBox.shrink(),
      ),
    );
  }

  static void _noopSectionChanged(AppSection _) {}
}
