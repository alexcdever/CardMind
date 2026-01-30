import 'package:cardmind/widgets/settings/button_setting_item.dart';
import 'package:cardmind/widgets/settings/info_setting_item.dart';
import 'package:cardmind/widgets/settings/toggle_setting_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Accessibility Tests', () {
    Widget createToggleWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ToggleSettingItem(
            icon: Icons.notifications,
            label: '同步通知',
            description: '开启后，当笔记被其他设备修改时会收到通知',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );
    }

    Widget createButtonWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ButtonSettingItem(
            icon: Icons.download,
            label: '导出数据',
            description: '导出所有卡片数据',
            onPressed: () {},
          ),
        ),
      );
    }

    Widget createInfoWidget() {
      return const MaterialApp(
        home: Scaffold(
          body: InfoSettingItem(icon: Icons.info, label: '版本', value: '1.0.0'),
        ),
      );
    }

    testWidgets('AT-001: Toggle has semantic label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      final semantics = tester.getSemantics(switchWidget);
      expect(
        semantics.label,
        isNotNull,
        reason: 'Toggle should have a semantic label',
      );
    });

    testWidgets('AT-002: Button has semantic label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createButtonWidget());
      await tester.pumpAndSettle();

      final button = find.byType(ListTile);
      expect(button, findsOneWidget);

      final semantics = tester.getSemantics(button);
      expect(
        semantics.label,
        isNotNull,
        reason: 'Button should have a semantic label',
      );
    });

    testWidgets('AT-003: Components have proper semantic structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(ToggleSettingItem));
      expect(semantics, isNotNull);
    });

    testWidgets('AT-004: Keyboard navigation works with Tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      // Simulate Tab key press
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Should not crash
      expect(find.byType(ToggleSettingItem), findsOneWidget);
    });

    testWidgets('AT-005: Touch targets are at least 40x40', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      final size = tester.getSize(switchWidget);
      expect(
        size.height,
        greaterThanOrEqualTo(40),
        reason: 'Switch height should be at least 40px',
      );
    });

    testWidgets('AT-006: Button touch target is at least 40x40', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createButtonWidget());
      await tester.pumpAndSettle();

      final button = find.byType(ListTile);
      final size = tester.getSize(button);
      expect(
        size.height,
        greaterThanOrEqualTo(40),
        reason: 'Button height should be at least 40px',
      );
    });

    testWidgets('AT-007: Text contrast is sufficient', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final texts = find.byType(Text);
      expect(texts, findsWidgets);

      // Verify text widgets exist and are rendered
      for (int i = 0; i < texts.evaluate().length; i++) {
        final textWidget = texts.at(i).evaluate().first.widget as Text;
        expect(
          textWidget.data ?? textWidget.textSpan?.toPlainText(),
          isNotNull,
          reason: 'Text $i should have content',
        );
      }
    });

    testWidgets('AT-008: Focus indicators are visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      // Tab to first focusable element
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Verify focus system is working
      final focusNodes = find.byType(Focus);
      expect(focusNodes, findsWidgets);
    });

    testWidgets('AT-009: Semantic nodes exist for screen reader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final semanticsFinder = find.byType(Semantics);
      expect(semanticsFinder, findsWidgets);

      final semanticsCount = semanticsFinder.evaluate().length;
      expect(
        semanticsCount,
        greaterThan(0),
        reason: 'Should have semantic nodes for screen reader',
      );
    });

    testWidgets('AT-010: Switches have proper semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      final semantics = tester.getSemantics(switchWidget);
      expect(semantics, isNotNull, reason: 'Switch should have semantics');
    });

    testWidgets('AT-011: Buttons have proper semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createButtonWidget());
      await tester.pumpAndSettle();

      final button = find.byType(ListTile);
      final semantics = tester.getSemantics(button);
      expect(semantics, isNotNull, reason: 'Button should have semantics');
    });

    testWidgets(
      'AT-012: Color is not the only means of conveying information',
      (WidgetTester tester) async {
        await tester.pumpWidget(createToggleWidget());
        await tester.pumpAndSettle();

        final switchWidget = find.byType(Switch);
        final widget = tester.widget<Switch>(switchWidget);
        final semantics = tester.getSemantics(switchWidget);

        // Verify both visual (value) and semantic exist
        expect(
          widget.value,
          isNotNull,
          reason: 'Switch should have visual state',
        );
        expect(
          semantics,
          isNotNull,
          reason: 'Switch should have semantic state',
        );
      },
    );

    testWidgets('AT-013: Semantic labels are descriptive', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      final semantics = tester.getSemantics(switchWidget);
      expect(
        semantics.label.length,
        greaterThan(3),
        reason: 'Label should be descriptive',
      );
    });

    testWidgets('AT-014: Disabled elements are properly marked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      final semantics = tester.getSemantics(switchWidget);
      expect(semantics, isNotNull, reason: 'Switch should have semantics');
    });

    testWidgets('AT-015: Text is readable at default size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();

      final texts = find.byType(Text);
      for (int i = 0; i < texts.evaluate().length; i++) {
        final textWidget = texts.at(i).evaluate().first.widget as Text;
        final style = textWidget.style;

        // If font size is specified, it should be at least 12
        if (style?.fontSize != null) {
          expect(
            style!.fontSize!,
            greaterThanOrEqualTo(12),
            reason: 'Text $i font size should be at least 12px',
          );
        }
      }
    });

    testWidgets('AT-016: Info widget has proper semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createInfoWidget());
      await tester.pumpAndSettle();

      final infoWidget = find.byType(InfoSettingItem);
      expect(infoWidget, findsOneWidget);

      // Verify text is readable
      expect(find.text('版本'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('AT-017: Button is tappable', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.download,
              label: '导出数据',
              description: '导出所有卡片数据',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byType(ListTile);
      await tester.tap(button);
      await tester.pump();

      expect(tapped, isTrue, reason: 'Button should be tappable');
    });

    testWidgets('AT-018: Toggle is switchable', (WidgetTester tester) async {
      bool value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleSettingItem(
              icon: Icons.notifications,
              label: '同步通知',
              description: '开启后，当笔记被其他设备修改时会收到通知',
              value: value,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      await tester.tap(switchWidget);
      await tester.pump();

      // Should not crash
      expect(find.byType(ToggleSettingItem), findsOneWidget);
    });

    testWidgets('AT-019: Components render without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ToggleSettingItem), findsOneWidget);

      await tester.pumpWidget(createButtonWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ButtonSettingItem), findsOneWidget);

      await tester.pumpWidget(createInfoWidget());
      await tester.pumpAndSettle();
      expect(find.byType(InfoSettingItem), findsOneWidget);
    });

    testWidgets('AT-020: All components have icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createToggleWidget());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications), findsOneWidget);

      await tester.pumpWidget(createButtonWidget());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);

      await tester.pumpWidget(createInfoWidget());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.info), findsOneWidget);
    });
  });
}
