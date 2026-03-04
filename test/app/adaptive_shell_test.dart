// input: 以移动端与桌面端宽度挂载 AdaptiveShell。
// output: 分别渲染底部导航或侧边导航轨。
// pos: 覆盖自适应导航断点行为，防止端形态切换退化。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/layout/adaptive_shell.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('desktop shell supports keyboard section switching', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopShellHarness()));

    expect(find.text('cards-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();

    expect(find.text('pool-marker'), findsOneWidget);
  });

  testWidgets('desktop shell supports arrow key switching', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopShellHarness()));

    expect(find.text('cards-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('pool-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('cards-marker'), findsOneWidget);
  });

  testWidgets('desktop shell supports enter and space activation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopShellHarness()));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(find.text('settings-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('settings-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('settings-marker'), findsOneWidget);
  });

  testWidgets('desktop rail keeps a visible interaction indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveShellForTest(width: 1200)),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.useIndicator, isTrue);
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

class _DesktopShellHarness extends StatefulWidget {
  const _DesktopShellHarness();

  @override
  State<_DesktopShellHarness> createState() => _DesktopShellHarnessState();
}

class _DesktopShellHarnessState extends State<_DesktopShellHarness> {
  AppSection _section = AppSection.cards;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1200, 900)),
      child: AdaptiveShell(
        section: _section,
        onSectionChanged: (section) {
          setState(() {
            _section = section;
          });
        },
        child: switch (_section) {
          AppSection.cards => const Center(child: Text('cards-marker')),
          AppSection.pool => const Center(child: Text('pool-marker')),
          AppSection.settings => const Center(child: Text('settings-marker')),
        },
      ),
    );
  }
}
