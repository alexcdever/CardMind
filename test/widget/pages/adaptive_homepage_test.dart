// input: 以移动端与桌面端宽度挂载 AdaptiveHomepageScaffold。
// output: 分别渲染底部导航或侧边导航轨。
// pos: 覆盖自适应导航断点行为，防止端形态切换退化。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/layout/adaptive_homepage_scaffold.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses bottom nav on mobile width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveHomepageScaffoldForTest(width: 390)),
    );

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('卡片'), findsWidgets);
    expect(find.text('数据池'), findsWidgets);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('uses navigation rail on desktop width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveHomepageScaffoldForTest(width: 1200)),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(Row), findsOneWidget);
    expect(find.text('卡片'), findsOneWidget);
    expect(find.text('数据池'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('mobile homepage keeps top area content and bottom tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AdaptiveHomepageScaffold(
            section: AppSection.cards,
            onSectionChanged:
                AdaptiveHomepageScaffoldForTest._noopSectionChanged,
            child: Text('mobile-content'),
          ),
        ),
      ),
    );

    expect(find.text('mobile-content'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('desktop homepage uses left navigation plus work area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: AdaptiveHomepageScaffold(
            section: AppSection.cards,
            onSectionChanged:
                AdaptiveHomepageScaffoldForTest._noopSectionChanged,
            child: Text('desktop-work-area'),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('desktop-work-area'), findsOneWidget);
  });

  testWidgets('desktop homepage scaffold supports keyboard section switching', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    expect(find.text('cards-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();

    expect(find.text('pool-marker'), findsOneWidget);
  });

  testWidgets('desktop homepage scaffold supports arrow key switching', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    expect(find.text('cards-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('pool-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('cards-marker'), findsOneWidget);
  });

  testWidgets('desktop homepage scaffold supports enter and space activation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.text('pool-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('pool-marker'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('pool-marker'), findsOneWidget);
  });

  testWidgets('desktop homepage rail keeps a visible interaction indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdaptiveHomepageScaffoldForTest(width: 1200)),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.useIndicator, isTrue);
  });

  testWidgets('desktop homepage rail tap changes section through callback', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    await tester.tap(find.byKey(const ValueKey(SemanticIds.navPool)));
    await tester.pumpAndSettle();

    expect(find.text('pool-marker'), findsOneWidget);
  });

  testWidgets('desktop homepage ignores key up events', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();

    expect(find.text('pool-marker'), findsOneWidget);
  });

  testWidgets('desktop homepage ignores unsupported key input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DesktopHomepageHarness()));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();

    expect(find.text('cards-marker'), findsOneWidget);
  });

  testWidgets('mobile homepage shows only two public tab targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AdaptiveHomepageScaffold(
            section: AppSection.cards,
            onSectionChanged:
                AdaptiveHomepageScaffoldForTest._noopSectionChanged,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('卡片'), findsWidgets);
    expect(find.text('数据池'), findsWidgets);
    expect(find.text('设置'), findsNothing);
  });
}

class AdaptiveHomepageScaffoldForTest extends StatelessWidget {
  const AdaptiveHomepageScaffoldForTest({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 844)),
      child: const AdaptiveHomepageScaffold(
        section: AppSection.cards,
        onSectionChanged: _noopSectionChanged,
        child: SizedBox.shrink(),
      ),
    );
  }

  static void _noopSectionChanged(AppSection _) {}
}

class _DesktopHomepageHarness extends StatefulWidget {
  const _DesktopHomepageHarness();

  @override
  State<_DesktopHomepageHarness> createState() =>
      _DesktopHomepageHarnessState();
}

class _DesktopHomepageHarnessState extends State<_DesktopHomepageHarness> {
  AppSection _section = AppSection.cards;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1200, 900)),
      child: AdaptiveHomepageScaffold(
        section: _section,
        onSectionChanged: (section) {
          setState(() {
            _section = section;
          });
        },
        child: switch (_section) {
          AppSection.cards => const Center(child: Text('cards-marker')),
          AppSection.pool => const Center(child: Text('pool-marker')),
        },
      ),
    );
  }
}
