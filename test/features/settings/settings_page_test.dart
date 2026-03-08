// input: 在设置页观察空白占位并执行底部 Tab 切换操作。
// output: 设置页不展示额外内容，且可一步切换到卡片页或池页目标分区。
// pos: 覆盖设置页跨分区导航通路，防止一跳切换退化。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/layout/adaptive_shell.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings page stays blank in current version', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('设备信息'), findsNothing);
    expect(find.text('创建或加入数据池'), findsNothing);
  });

  testWidgets('from settings, tab switches to cards in one action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _SettingsShellHarness(section: AppSection.settings),
    );

    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('卡片'));
    await tester.pumpAndSettle();

    expect(find.text('cards-marker'), findsOneWidget);
  });

  testWidgets('from settings, tab switches to pool in one action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _SettingsShellHarness(section: AppSection.settings),
    );

    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('数据池'));
    await tester.pumpAndSettle();

    expect(find.text('pool-marker'), findsOneWidget);
  });
}

class _SettingsShellHarness extends StatefulWidget {
  const _SettingsShellHarness({required this.section});

  final AppSection section;

  @override
  State<_SettingsShellHarness> createState() => _SettingsShellHarnessState();
}

class _SettingsShellHarnessState extends State<_SettingsShellHarness> {
  late AppSection _section = widget.section;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
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
            AppSection.settings => const SettingsPage(),
          },
        ),
      ),
    );
  }
}
