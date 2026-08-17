import 'dart:io';

import 'package:cardmind/pages/devices_page.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_harness.dart';

/// 任务 T2 必做 3：真实平台（Windows / Android）签名凭证 UI 页面实机验证。
///
/// 每个平台分别真实启动 DevicesPage（真实 FRB + Rust 后端 + 标准 443 relay.txt）：
/// 1. 显示凭证页：真实 Rust 生成 cm1. 凭证 → 二维码 / 复制按钮 / 重新生成 / 倒计时；
///    复制按钮写入系统剪贴板的必须是完整凭证（cm1. 前缀 + 长文本，而非 6 位码）。
/// 2. 输入页：只有一个主字段（pair-credential-input），无 node ID 字段；
///    粘贴/扫描统一解析——cm1 前缀一律走凭证解析入口（非法负载 → 友好格式错误）。
///
/// 运行：
///   Windows：flutter test integration_test/pairing_credential_platform_test.dart -d windows --timeout 3m
///   Android：flutter test integration_test/pairing_credential_platform_test.dart -d emulator-5554 --timeout 3m
///            （Android 需先 cargo ndk 构建 + 清代理）
///
/// 说明：本文件只验证单端 UI 真实启动；跨设备"Windows 显示 → Android 粘贴"的双端
/// UI 全链路见 pairing_credential_dual_end_test.dart（同进程两个真实 endpoint）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeFrb);
  tearDownAll(disposeFrb);

  testWidgets(
    'real platform: show credential page renders real cm1 credential with qr copy regenerate countdown',
    (tester) async {
      final harness = CardMindIntegrationHarness();
      final dir = await harness.createDataDirectory();
      // 标准 443 relay 配置（连接行为由 Rust 侧读取；本测试不发起真实对端连接）
      File(p.join(dir, 'relay.txt')).writeAsStringSync('https://relay.alexc.cn');
      final repo = await harness.openRepository(dataDirectory: dir);
      addTearDown(() => _disposeHarness(tester, harness));

      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(body: DevicesPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('devices-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pair-mode-show')));

      // 等待真实凭证生成完成（Rust 真实签名；FRB 往返）
      await _waitFor(
        tester,
        find.byKey(const ValueKey('pair-qr-image')),
        reason: '真实平台显示凭证页应渲染二维码',
      );

      // 用户旅程：显示二维码/复制凭证/倒计时/6 位码
      expect(
        find.byKey(const ValueKey('pair-code-display')),
        findsOneWidget,
        reason: '应显示 6 位配对码',
      );
      expect(
        find.byKey(const ValueKey('pair-qr-image')),
        findsOneWidget,
        reason: '应显示二维码',
      );
      expect(
        find.byKey(const ValueKey('pair-copy-button')),
        findsOneWidget,
        reason: '应有复制凭证按钮',
      );
      expect(
        find.byKey(const ValueKey('pair-regenerate-button')),
        findsOneWidget,
        reason: '应有重新生成按钮',
      );
      expect(
        find.byKey(const ValueKey('pair-code-countdown')),
        findsOneWidget,
        reason: '应有倒计时（凭证过期时间）',
      );

      // 复制 → 系统剪贴板必须是完整 cm1. 凭证（不是 6 位码）
      await tester.tap(find.byKey(const ValueKey('pair-copy-button')));
      final credential = await _readClipboard(tester);
      expect(credential, startsWith('cm1.'),
          reason: '剪贴板必须是完整签名凭证（cm1. 前缀）');
      expect(credential.length, greaterThan(100),
          reason: '完整凭证应远超 6 位码长度（真实凭证 ~184 字符）');
      expect(credential, isNot(RegExp(r'^\d{6}$')),
          reason: '剪贴板不得只是 6 位码');

      // 关闭弹窗（accept 等待由 Rust 侧有界超时兜底；不阻塞测试）
      await tester.tap(find.byKey(const ValueKey('pair-dialog-close')));
      await tester.pump(const Duration(milliseconds: 300));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'real platform: enter page has one primary field no node id and unified paste parsing',
    (tester) async {
      final harness = CardMindIntegrationHarness();
      final dir = await harness.createDataDirectory();
      File(p.join(dir, 'relay.txt')).writeAsStringSync('https://relay.alexc.cn');
      final repo = await harness.openRepository(dataDirectory: dir);
      addTearDown(() => _disposeHarness(tester, harness));

      await tester.pumpWidget(
        MaterialApp(
          theme: CardMindTheme.light,
          home: Scaffold(body: DevicesPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('devices-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pair-mode-enter')));
      await tester.pumpAndSettle();

      // 输入页只有一个主字段；无 node ID 字段
      expect(
        find.byKey(const ValueKey('pair-credential-input')),
        findsOneWidget,
        reason: '输入页应只有一个主字段（粘贴/输入配对信息）',
      );
      expect(
        find.byKey(const ValueKey('pair-node-id-input')),
        findsNothing,
        reason: '凭证流程不得有 node ID 输入字段',
      );
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: '输入页全局只允许一个 TextField（无第二字段）',
      );

      // 粘贴 cm1 前缀 → 统一走凭证解析入口（真实 FRB/Rust parse）：
      // 非法负载 → InvalidFormat 友好文案（证明粘贴解析不是 6 位码分支）
      _setFieldText(tester, 'pair-credential-input', 'cm1.not-a-valid-credential');
      await tester.tap(find.byKey(const ValueKey('pair-submit')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('pair-submit-error')),
        reason: '粘贴非法凭证应显示友好格式错误',
      );
      expect(
        find.textContaining('配对信息格式无效'),
        findsOneWidget,
        reason: 'InvalidFormat 应映射为中文友好文案（不得显示裸异常）',
      );

      // 既非 cm1 也非 6 位 → 统一格式提示
      _setFieldText(tester, 'pair-credential-input', 'abc');
      await tester.tap(find.byKey(const ValueKey('pair-submit')));
      await _waitFor(
        tester,
        find.textContaining('请输入 6 位配对码，或粘贴完整的配对信息'),
        reason: '非法输入应显示统一格式提示',
      );

      // 取消关闭
      await tester.tap(find.byKey(const ValueKey('pair-cancel')));
      await tester.pump(const Duration(milliseconds: 300));
    },
    timeout: const Timeout(Duration(minutes: 2)),
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

/// 直接写 controller.text（live binding 下 tester.enterText 第二次调用不可靠——
/// 实机验证目标是 submit 后的真实 FRB/Rust 解析，而非文本输入通道本身；
/// 文本输入通道机制已由 widget 测试覆盖）。
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
