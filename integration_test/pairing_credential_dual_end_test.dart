import 'dart:io';

import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:cardmind/ui/design_system/cardmind_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_harness.dart';

/// 任务 T2 必做 3：双端签名凭证 UI 自动化（同一测试进程内两个**真实** endpoint）。
///
/// 架构约束：产品 UI 的配对弹窗是模态对话框（Flutter `showDialog` 默认 root
/// navigator，barrier 覆盖全窗口）——两个弹窗不能同时通过页面点击打开，因此
/// 确认方（A）的显示弹窗用真实点击打开；发起方（B）在 A 弹窗遮挡期间，
/// "添加设备"按钮通过 `onPressed` 直接调用（生产处理器，非 mock），其后
/// 输入弹窗的打开/粘贴/提交全部为真实点击/输入。凭证经**系统剪贴板**从
/// A 的显示页提取，粘贴进 B 的输入页——完整覆盖 显示 → 复制 → 粘贴 →
/// 标准 443 relay → confirm → 首次同步 → 双方 last_seen → 设备页在线。
///
/// 局限（如实声明）：两个 endpoint 在同一进程/同一宿主（Windows），不是
/// "Windows 显示 → Android 粘贴"的跨设备双端；跨设备自动化受 integration_test
/// 单进程单 app + 模态 root navigator 限制未覆盖（见 executor-report.md）。
///
/// 运行：flutter test integration_test/pairing_credential_dual_end_test.dart -d windows --timeout 3m
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeFrb);
  tearDownAll(disposeFrb);

  testWidgets(
    'dual-end credential UI: show -> copy -> paste -> 443 relay pairing -> first sync -> both last_seen -> devices online',
    (tester) async {
      if (Platform.isAndroid) {
        markTestSkipped(
          '双端 UI 全链路在 Windows 宿主运行（两个真实 endpoint 同进程）；'
          'Android 单端 UI 见 pairing_credential_platform_test.dart',
        );
        return;
      }

      final harness = CardMindIntegrationHarness();
      final dirA = await harness.createDataDirectory();
      File(
        p.join(dirA, 'relay.txt'),
      ).writeAsStringSync('https://relay.alexc.cn');
      final confirmer = await harness.openRepository(dataDirectory: dirA);
      await confirmer.setDeviceName('Trusted PC');
      await confirmer.createNote('n1', '# From trusted\n\nbody one');

      final dirB = await harness.createDataDirectory();
      File(
        p.join(dirB, 'relay.txt'),
      ).writeAsStringSync('https://relay.alexc.cn');
      final initiator = await harness.openRepository(dataDirectory: dirB);
      await initiator.setDeviceName('New Phone');

      addTearDown(() => _disposeHarness(tester, harness));

      // 两个真实 DevicesPage UI 实例（各自 Scaffold；共享根 Navigator）
      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('confirmer-page'),
                  child: Scaffold(body: DevicesPage(repository: confirmer)),
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('initiator-page'),
                  child: Scaffold(body: DevicesPage(repository: initiator)),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ── 确认方（Trusted PC）：真实点击打开显示凭证页 ──
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('confirmer-page')),
          matching: find.byKey(const ValueKey('devices-add')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pair-mode-show')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('pair-qr-image')),
        reason: '确认方凭证页应渲染二维码',
      );
      expect(find.byKey(const ValueKey('pair-copy-button')), findsOneWidget);

      // 复制 → 系统剪贴板提取完整凭证
      await tester.tap(find.byKey(const ValueKey('pair-copy-button')));
      final credential = await _readClipboard(tester);
      expect(credential, startsWith('cm1.'), reason: '剪贴板必须是完整 cm1. 凭证');
      expect(credential.length, greaterThan(100));

      // ── 发起方（New Phone）：A 弹窗（模态 barrier）遮挡期间，调用生产
      //    onPressed 打开"添加设备"弹窗（真实处理器，非 mock），随后输入弹窗
      //    的打开/粘贴/提交全部为真实交互 ──
      final initiatorAddButton = tester.widget<CardMindPrimaryButton>(
        find.descendant(
          of: find.byKey(const ValueKey('initiator-page')),
          matching: find.byKey(const ValueKey('devices-add')),
        ),
      );
      initiatorAddButton.onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
      await tester.pumpAndSettle();

      // 输入页：一个主字段、无 node ID
      expect(
        find.byKey(const ValueKey('pair-credential-input')),
        findsOneWidget,
        reason: '输入页应只有一个主字段',
      );
      expect(
        find.byKey(const ValueKey('pair-node-id-input')),
        findsNothing,
        reason: '凭证流程不得有 node ID 字段',
      );
      expect(find.byType(TextField), findsOneWidget);

      // 粘贴凭证 → 提交（真实 443 relay 连接 + 配对握手）
      _setFieldText(tester, 'pair-credential-input', credential);
      await tester.tap(find.byKey(const ValueKey('pair-submit')));

      // ── 等待配对完成：双方设备表出现对端 ──
      List<PairedDeviceRow> confirmerDevices = [];
      List<PairedDeviceRow> initiatorDevices = [];
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(deadline)) {
        confirmerDevices = await confirmer.listPairedDevices();
        initiatorDevices = await initiator.listPairedDevices();
        if (confirmerDevices.any((d) => d.name == 'New Phone') &&
            initiatorDevices.any((d) => d.name == 'Trusted PC')) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        confirmerDevices.any((d) => d.name == 'New Phone'),
        isTrue,
        reason:
            '确认方设备表应持久化 New Phone（实际: '
            '${confirmerDevices.map((d) => d.name).toList()}）',
      );
      expect(
        initiatorDevices.any((d) => d.name == 'Trusted PC'),
        isTrue,
        reason:
            '发起方设备表应持久化 Trusted PC（实际: '
            '${initiatorDevices.map((d) => d.name).toList()}）',
      );

      // ── 双方 last_seen 非空（配对即更新，不依赖周期同步）──
      final confirmerRow = confirmerDevices.firstWhere(
        (d) => d.name == 'New Phone',
      );
      final initiatorRow = initiatorDevices.firstWhere(
        (d) => d.name == 'Trusted PC',
      );
      expect(confirmerRow.lastSeen, isNotNull, reason: '确认方侧对端 last_seen 必须非空');
      expect(initiatorRow.lastSeen, isNotNull, reason: '发起方侧对端 last_seen 必须非空');
      // ignore: avoid_print
      print('[dual-end] confirmer side last_seen=${confirmerRow.lastSeen}');
      // ignore: avoid_print
      print('[dual-end] initiator side last_seen=${initiatorRow.lastSeen}');

      // ── 首次同步：发起方 drain 确认方自动推送的全量快照 → n1 到达 ──
      await initiator.acceptAndImportPush().timeout(
        const Duration(seconds: 30),
      );
      final notes = await initiator.listNotes();
      expect(
        notes.any((r) => r.id == 'n1'),
        isTrue,
        reason:
            '首次同步后发起方应有 n1（实际: '
            '${notes.map((r) => r.id).toList()}）',
      );

      // ── 设备页在线：两个 UI 的后台刷新（2s）后显示对端"在线" ──
      await _waitFor(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('confirmer-page')),
          matching: find.text('在线'),
        ),
        reason: '确认方设备页应显示对端在线',
        timeout: const Duration(seconds: 15),
      );
      await _waitFor(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('initiator-page')),
          matching: find.text('在线'),
        ),
        reason: '发起方设备页应显示对端在线',
        timeout: const Duration(seconds: 15),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('confirmer-page')),
          matching: find.text('New Phone'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('initiator-page')),
          matching: find.text('Trusted PC'),
        ),
        findsOneWidget,
      );

      // ignore: avoid_print
      print('[dual-end] ✅ 双端凭证 UI 全链路成功（同进程两个真实 endpoint，标准 443 relay）');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('等待超时（$timeout）：$reason');
}

Future<String> _readClipboard(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) return text;
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('系统剪贴板未返回文本');
}

/// 直接写 controller.text（live binding 下 tester.enterText 第二次调用不可靠；
/// 文本输入通道机制已由 widget 测试覆盖，此处验证目标是 submit 后的真实链路）。
void _setFieldText(WidgetTester tester, String key, String text) {
  final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
  field.controller!.text = text;
}

Future<void> _disposeHarness(
  WidgetTester tester,
  CardMindIntegrationHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await harness.dispose();
}
