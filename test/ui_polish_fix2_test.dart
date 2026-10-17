import 'dart:io';
import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/pages/editor_page.dart';
import 'package:cardmind/pages/note_list_page.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/services/app_settings_service.dart';
import 'package:cardmind/services/update_service.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_note_repository.dart' show MemoryNoteRepository;

class _SettingsFake extends AppSettingsService {
  _SettingsFake(this.channel);

  UpdateChannel channel;

  @override
  Future<UpdateChannel> readChannel() async => channel;

  @override
  Future<void> writeChannel(UpdateChannel value) async => channel = value;

  @override
  Future<bool> readUseSystemProxy() async => true;

  @override
  Future<void> writeUseSystemProxy(bool value) async {}
}

UpdateService _offlineService() => UpdateService(
  currentBuild: 1,
  currentVersion: '0.1.0',
  fetch: (_) async => throw StateError('offline'),
);

Future<void> _pumpSettings(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  UpdateService? updates,
  Future<Directory> Function({String? baseDirectory})? logDirectoryResolver,
  Future<void> Function(String directory)? logDirectoryOpener,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    // 注入 MediaQuery：setSurfaceSize 只改 renderView，MediaQuery.sizeOf 仍返回
    // 默认 800×600，必须显式给 size 才能让 <600 分支生效。
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: CardMindTheme.light,
        home: SettingsPage(
          currentVersion: '1.0.0',
          settings: _SettingsFake(UpdateChannel.stable),
          updates: updates,
          logDirectoryResolver: logDirectoryResolver,
          logDirectoryOpener: logDirectoryOpener,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// ui-polish-fix-2 验收测试：每条 AC 一个用例（本轮新增，独立于第一轮文件）。
void main() {
  // ━━ AC1：笔记右键菜单锚定按下点（点锚定），不被屏幕边缘挤压 ━━
  testWidgets('AC1: note context menu anchors to pointer position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = MemoryNoteRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: NoteListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-work-note')),
      findsOneWidget,
      reason: '桌面布局应渲染笔记项',
    );

    final itemTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('note-work-note')),
    );
    // 在列表项左部（约 x=itemTopLeft.dx+40）右键，确保指针不在屏幕右半区，
    // 使菜单应向右侧展开、topLeft 与按下点一致。
    final tapPoint = Offset(itemTopLeft.dx + 40, itemTopLeft.dy + 40);
    await tester.tapAt(tapPoint, buttons: 2, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('note-delete-menu'));
    expect(menu, findsOneWidget, reason: '右键应弹出删除菜单');
    final menuTopLeft = tester.getTopLeft(menu);
    // right/bottom=0 的旧实现会把菜单挤压到屏幕右下角（距按下点上千 px）。
    // 正确点锚定时菜单 topLeft 与按下点的距离应远小于 200px。
    expect(
      (menuTopLeft.dx - tapPoint.dx).abs(),
      lessThan(60),
      reason: '菜单水平位置应锚定在指针触发位置附近',
    );
    expect(
      (menuTopLeft.dy - tapPoint.dy).abs(),
      lessThan(60),
      reason: '菜单垂直位置应锚定在指针触发位置附近',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC2：检查更新失败文案不重复前缀 ━━
  testWidgets('AC2: update check failure shows a single prefix', (
    tester,
  ) async {
    await _pumpSettings(tester, updates: _offlineService());
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(
      find.textContaining('检查失败：检查更新失败：'),
      findsNothing,
      reason: '不得出现「检查失败：检查更新失败：…」双重前缀',
    );
    expect(
      find.textContaining('检查更新失败：'),
      findsOneWidget,
      reason: '应只显示一遍「检查更新失败：…」',
    );
  });

  // ━━ AC3：反链行可点区域高度 ≥48dp ━━
  testWidgets('AC3: backlink row meets the 48dp touch target', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository =
        MemoryNoteRepository(
            rows: const [
              NoteRow(
                id: 'linked',
                title: 'Linked',
                contentPreview: 'Body',
                tags: '',
                updatedAt: '2026-07-22 05:00:00',
              ),
            ],
            contents: const {'linked': '# Linked\n\nBody'},
          )
          ..backlinks = const [
            LinkRow(id: 'src-1', title: 'Source Note', alias: '', exists: true),
          ];

    await tester.pumpWidget(
      MaterialApp(
        theme: CardMindTheme.light,
        home: Scaffold(
          body: EditorPage(repository: repository, noteId: 'linked'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('backlink-src-1'));
    expect(tile, findsOneWidget, reason: '反链行应渲染');
    expect(
      tester.getSize(tile).height,
      greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
      reason: '反链行可点区域高度应 ≥48dp',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC4：设置页内边距移动端 16px / 桌面 24px ━━
  testWidgets('AC4: settings page padding switches at the 600px breakpoint', (
    tester,
  ) async {
    // 移动端 <600 → 16px
    await _pumpSettings(tester, size: const Size(390, 844));
    ListView listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      listView.padding,
      const EdgeInsets.all(CardMindSpacing.lg),
      reason: '移动端页面内边距应为 16px',
    );

    // 桌面 ≥600 → 24px
    await _pumpSettings(tester, size: const Size(1200, 800));
    listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      listView.padding,
      const EdgeInsets.all(CardMindSpacing.xl),
      reason: '桌面端页面内边距应为 24px',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC5：标签 bottom sheet 顶部圆角 = radius.xl (8px) ━━
  testWidgets('AC5: tag bottom sheet uses 8px top radius', (tester) async {
    // 移动端宽度 → showModalBottomSheet 分支
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = MemoryNoteRepository(
      rows: const [
        NoteRow(
          id: 'tagged',
          title: 'Tagged',
          contentPreview: 'Body',
          tags: 'Work',
          updatedAt: '2026-07-22 05:00:00',
        ),
      ],
      contents: const {'tagged': '# Tagged\n\nBody'},
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(
            body: EditorPage(repository: repository, noteId: 'tagged'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tag = find.byKey(const ValueKey('editor-tag-work'));
    expect(tag, findsOneWidget);
    // 右键（secondary tap）走 _showTagMenu → compact 分支 showModalBottomSheet；
    // 单击改为选中态（显示删除图标），不再弹菜单。
    await tester.tapAt(
      tester.getCenter(tag),
      buttons: 2,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tag-action-edit')),
      findsOneWidget,
      reason: '移动端应弹出 bottom sheet 标签菜单',
    );
    // showModalBottomSheet(shape: …) 最终落到 _ModalBottomSheet 内部
    // BottomSheet 的 Material 上；该 Material 包住全部 sheet 内容（含
    // tag-action-edit）。未显式设置时是 null（M3 主题默认 28px 上圆角）。
    final sheetMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tag-action-edit')),
            matching: find.byType(Material),
          )
          .last,
    );
    final shape = sheetMaterial.shape;
    expect(
      shape,
      isA<RoundedRectangleBorder>(),
      reason: 'bottom sheet 必须显式设 shape',
    );
    final radius = (shape! as RoundedRectangleBorder).borderRadius.resolve(
      TextDirection.ltr,
    );
    expect(
      radius.topLeft.x,
      CardMindRadii.xl,
      reason: '顶部圆角应为 radius.xl(8px)，不是 M3 默认 28px',
    );
    expect(radius.topRight.x, CardMindRadii.xl);
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ AC6：日志目录未加载时不可点；加载成功可点且有视觉提示 ━━
  // ━━ AC6a：日志目录未加载成功时该行不可点 ━━
  testWidgets('AC6a: log directory row is disabled when unresolved', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      logDirectoryResolver: ({String? baseDirectory}) async =>
          throw const FileSystemException('cannot resolve'),
    );
    final row = tester.widget<InkWell>(
      find.byKey(const ValueKey('open-log-directory')),
    );
    expect(row.onTap, isNull, reason: '目录未加载成功时该行不得可点');
    expect(find.text('无法获取日志目录'), findsOneWidget, reason: '失败文案仍应显示');
  });

  // ━━ AC6b：日志目录加载成功后可点且有图标提示 ━━
  testWidgets('AC6b: log directory row tappable with icon once resolved', (
    tester,
  ) async {
    const resolved = '/tmp/cardmind-logs';
    var opened = 0;
    await _pumpSettings(
      tester,
      logDirectoryResolver: ({String? baseDirectory}) async =>
          Directory(resolved),
      logDirectoryOpener: (_) async => opened++,
    );
    final row = tester.widget<InkWell>(
      find.byKey(const ValueKey('open-log-directory')),
    );
    expect(row.onTap, isNotNull, reason: '目录加载成功后该行应可点');
    expect(
      find.byIcon(Icons.folder_open_outlined),
      findsOneWidget,
      reason: '可点时应有图标视觉提示',
    );
    await tester.tap(find.byKey(const ValueKey('open-log-directory')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
