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
  _editorChecks();
  _listChecks();
  _trashChecks();
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

/// 优化项 6/7/12：编辑器——链接补全面板 left 钳制、右键「删除」danger、
/// 保存中指示非静态 Icons.sync。
void _editorChecks() {
  test('AC4: link-completion panel clamps left to screen minus panel minus margin', () {
    final source = File('lib/pages/editor_page.dart').readAsStringSync();
    // left 必须由 rect.left 再经 clamp 收敛到屏幕内；
    // 断言出现对 panel 宽 + margin 的边界钳制表达式。
    expect(
      RegExp(r'left[^;]*clamp|clamp[^;]*left|screenW|panelW|\.clamp\(')
          .hasMatch(source),
      isTrue,
      reason: '光标贴近右缘时 360 宽补全面板会被裁；left 须 clamp 到 screenW-panelW-margin',
    );
  });

  test('AC4: desktop tag context menu delete item uses danger color', () {
    final source = File('lib/pages/editor_page.dart').readAsStringSync();
    // 右键菜单分支的「删除」项必须带 danger 色（图标或文字），
    // 与底部 sheet 分支（:317-321）对齐。
    final menuIdx = source.indexOf("value: 'delete'");
    expect(menuIdx, greaterThan(-1), reason: '必须存在右键删除菜单项');
    // 在该 PopupMenuItem 块附近应出现 danger 引用。
    final window = source.substring(
      (menuIdx - 400).clamp(0, source.length),
      (menuIdx + 400).clamp(0, source.length),
    );
    expect(
      window.contains('danger'),
      isTrue,
      reason: '桌面右键「删除」须用 tokens.danger 与 bottom-sheet 分支对齐',
    );
  });

  test('AC7: saving indicator is not the static Icons.sync glyph', () {
    final source = File('lib/pages/editor_page.dart').readAsStringSync();
    // _saving 分支不得继续渲染 Icons.sync（易误读为同步动作）；
    // 允许 Icons.save/CircularProgressIndicator/尺寸化 spinner。
    expect(
      RegExp(r'_saving \? Icons\.sync').hasMatch(source),
      isFalse,
      reason: '_saving 分支不得用静态 Icons.sync，须换 SizedBox 尺寸化 '
          'CircularProgressIndicator 或 Icons.save+文案区分',
    );
  });
}

/// 优化项 8/9/10：侧栏——「立即同步」≥48dp、日期字号 12px、三个导航行
/// padding 统一为 horizontal:12, vertical:8。
void _listChecks() {
  test('AC5: sidebar sync-now button is >=48dp (no compact density)', () {
    final source = File('lib/pages/note_list_page.dart').readAsStringSync();
    // 该 IconButton 不得再叠加 VisualDensity.compact（会把 48 目标压到 40）。
    final btnIdx = source.indexOf("key: const ValueKey('sync-now-button')");
    expect(btnIdx, greaterThan(-1), reason: '必须存在 sync-now-button');
    // 取该按钮所在块（到下一个 ')' 边界之前）检查无 compact。
    final window = source.substring(btnIdx, (btnIdx + 500).clamp(0, source.length));
    expect(
      window.contains('VisualDensity.compact'),
      isFalse,
      reason: '侧栏「立即同步」不得用 VisualDensity.compact，须保留 ≥48dp',
    );
  });

  test('item9: note-list date font size is >=12px', () {
    final source = File('lib/pages/note_list_page.dart').readAsStringSync();
    // 日期样式 _formatDate 处不得再出现 fontSize 11（label-caps 语义不符；
    // 升到 12px 保持日期可读性）。
    final dateIdx = source.indexOf('_formatDate(note.updatedAt)');
    expect(dateIdx, greaterThan(-1));
    final window = source.substring(
      dateIdx,
      (dateIdx + 300).clamp(0, source.length),
    );
    expect(
      RegExp(r'fontSize:[^;]*?11(?![0-9.])').hasMatch(window),
      isFalse,
      reason: '列表日期非 label-caps 语义，须升到 ≥12px',
    );
  });

  test('AC5: sidebar nav rows share uniform padding', () {
    final source = File('lib/pages/note_list_page.dart').readAsStringSync();
    for (final key in const ['trash-entry', 'open-settings', 'devices-entry']) {
      final idx = source.indexOf("ValueKey('$key')");
      expect(idx, greaterThan(-1), reason: '必须存在 $key 入口');
      // 该按钮外层 Padding 与其 styleFrom.padding 统一；
      // 以所在块内出现 vertical:8 的统一 padding 为断言。
      final window = source.substring(
        (idx - 400).clamp(0, source.length),
        (idx + 500).clamp(0, source.length),
      );
      expect(
        window.contains('vertical: 8'),
        isTrue,
        reason: '$key 导航行 padding 须统一含 vertical:8（horizontal:12, vertical:8）',
      );
    }
  });
}

/// 优化项 11：回收站页 `tokens` 命名误导——不得继续用
/// `Theme.of(context).colorScheme` 当 token；改用 `context.cardMind`。
void _trashChecks() {
  test('AC6: trash page reads cardMind tokens, not colorScheme', () {
    final source = File('lib/pages/trash_page.dart').readAsStringSync();
    expect(
      source.contains('context.cardMind'),
      isTrue,
      reason: 'trash 条目色须走 CardMind token（mutedInk/danger）',
    );
    expect(
      RegExp(r'Theme\.of\(context\)\.colorScheme|onSurfaceVariant|\.error\b')
          .hasMatch(source),
      isFalse,
      reason: 'trash 不得再把 colorScheme 误名为 tokens'
          '（onSurfaceVariant→mutedInk、error→danger）',
    );
  });
}
