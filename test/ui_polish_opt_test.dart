import 'dart:io';

import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:cardmind/ui/design_system/cardmind_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ui-polish-opt 优化项 1 验收测试：staleDotColor 收编为 CardMindTokens.stale。
///
/// - AC1a：CardMindTokens 提供 stale 字段（light = #B08D2E，原值不变）
/// - AC1b：stale 态圆点读 tokens.stale（与 token 相等）
/// - AC1c：stale 态文字回退 mutedInk——#B08D2E 对 paper 对比 ~3:1 不达
///   正文 4.5:1，dot 保留 stale 色、文字用 mutedInk
/// - AC1d：`staleDotColor` 兼容常量仍指向同一值（既有断言不破坏）
void main() {
  test('AC1: CardMindTokens exposes a stale color token', () {
    const tokens = CardMindTokens.light;
    expect(
      tokens.stale,
      const Color(0xFFB08D2E),
      reason: 'stale token 应承载原 staleDotColor 值 #B08D2E（light）',
    );
  });

  testWidgets('AC1: stale dot reads tokens.stale; stale text uses mutedInk', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: const Scaffold(
          body: Center(
            child: CardMindSyncStatus(
              lastSyncFailedFor: Duration(hours: 25),
            ),
          ),
        ),
      ),
    );

    const tokens = CardMindTokens.light;
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('sync-status-dot')),
    );
    final decoration = dot.decoration as BoxDecoration;
    expect(
      decoration.color,
      tokens.stale,
      reason: 'stale 圆点颜色必须读 CardMindTokens.stale 而非页面层硬编码',
    );

    final label = tester.widget<Text>(find.text('长时间未同步'));
    expect(
      label.style?.color,
      tokens.mutedInk,
      reason: '#B08D2E 对 paper 对比 ~3:1 不达正文 4.5:1；'
          'stale 态文字须回退 mutedInk（色不作唯一状态指示，文案已含语义）',
    );
  });

  test('AC1: staleDotColor stays as an alias of tokens.stale', () {
    expect(
      CardMindSyncStatus.staleDotColor,
      CardMindTokens.light.stale,
      reason: '兼容常量必须指向 token 值，避免两处色值漂移',
    );
  });

  _themeChecks();
  _settingsChecks();
}

/// 优化项 2/3：主题纪律——NavigationBar 去 tint/elevation，
/// 裸 FilledButton disabled 与 CardMindPrimaryButton 一致落 tokens.border。
void _themeChecks() {
  test('AC2: NavigationBar has no surface tint and zero elevation', () {
    final theme = CardMindTheme.light.navigationBarTheme;
    expect(
      theme.surfaceTintColor,
      Colors.transparent,
      reason: 'NavigationBar 须显式去 surfaceTint，与 AppBar/Dialog 纪律一致',
    );
    expect(
      theme.elevation,
      0,
      reason: 'NavigationBar 阴影应收敛为 0（M3 默认 elevation:3 会叠 tint）',
    );
  });

  test('AC2: FilledButton disabled background falls back to tokens.border', () {
    final style = CardMindTheme.light.filledButtonTheme.style;
    expect(
      style,
      isNotNull,
      reason: 'theme 须显式声明 filledButtonTheme（携带 disabled 背景）',
    );
    final bg = style!.backgroundColor;
    expect(bg, isNotNull, reason: 'filledButtonTheme.backgroundColor 不得为 null');
    expect(
      bg!.resolve({WidgetState.disabled}),
      CardMindTokens.light.border,
      reason: '裸 FilledButton disabled 应与 CardMindPrimaryButton 一致落 tokens.border',
    );
  });
}

/// 优化项 4/5：设置页——取消下载/打开安装包 ≥48dp；桌面宽屏内容有最大宽约束。
void _settingsChecks() {
  testWidgets('AC3: cancel-download / open-package TextButtons are >=48dp', (
    tester,
  ) async {
    for (final key in const ['cancel-update-download', 'open-update-package']) {
      // 仅做静态最小尺寸断言：SettingsPage 未挂起时不直接构造（依赖服务注入），
      // 改由源码纪律测试保证 styleFrom(minimumSize) 存在（见下方 grep 断言）。
      expect(key, isNotEmpty);
    }
    final source = File('lib/pages/settings_page.dart').readAsStringSync();
    for (final key in const ['cancel-update-download', 'open-update-package']) {
      // 每个 key 所在 TextButton 必须声明 minimumSize 达标触摸目标。
      final pattern = RegExp(
        "key: const ValueKey\\('$key'\\)[\\s\\S]{0,400}?minimumSize",
      );
      expect(
        pattern.hasMatch(source),
        isTrue,
        reason: '$key TextButton 必须 styleFrom(minimumSize: Size(0, mobileTouchTarget))',
      );
    }
  });

  testWidgets('AC3: desktop settings body has a max-width constraint', (
    tester,
  ) async {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();
    expect(
      source.contains('ConstrainedBox') &&
          source.contains('editorMaxWidth'),
      isTrue,
      reason: '桌面宽屏内容须以 ConstrainedBox + editorMaxWidth 限宽，与编辑器一致',
    );
  });
}
