// 设置页 widget/服务测试。
// 「打开安装包」按钮（open-update-package）只在 macOS/Linux 渲染，
// Windows 无法挂载 → 其 minimumSize ≥48 的校验保留源码快照断言（非行为断言）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardmind/models/update_channel.dart';
import 'package:cardmind/models/update_manifest.dart';
import 'package:cardmind/pages/settings_page.dart';
import 'package:cardmind/services/app_settings_service.dart';
import 'package:cardmind/services/http_proxy_policy.dart';
import 'package:cardmind/services/platform_update_installer.dart';
import 'package:cardmind/services/update_downloader.dart';
import 'package:cardmind/services/update_download_manager.dart';
import 'package:cardmind/services/update_service.dart';
import 'package:cardmind/ui/design_system/cardmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsFake extends AppSettingsService {
  _SettingsFake(this.channel, {this.useSystemProxy = true});

  UpdateChannel channel;
  bool useSystemProxy;

  @override
  Future<UpdateChannel> readChannel() async => channel;

  @override
  Future<void> writeChannel(UpdateChannel value) async => channel = value;

  @override
  Future<bool> readUseSystemProxy() async => useSystemProxy;

  @override
  Future<void> writeUseSystemProxy(bool value) async => useSystemProxy = value;
}

class _DelayedSettings extends _SettingsFake {
  _DelayedSettings(super.channel);

  final proxyRead = Completer<bool>();

  @override
  Future<bool> readUseSystemProxy() => proxyRead.future;
}

class _DownloaderFake extends UpdateDownloader {
  _DownloaderFake(this.result, {super.proxyPolicy})
    : super(client: HttpClient());

  final DownloadResult result;

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(1);
    return result;
  }

  @override
  void dispose() {}
}

class _DeferredDownloader extends UpdateDownloader {
  _DeferredDownloader(this.result) : super(client: HttpClient());

  final DownloadResult result;
  final completer = Completer<void>();
  DownloadCancellationToken? token;

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    token = cancellation;
    onProgress?.call(0.5);
    await completer.future;
    onProgress?.call(1);
    return result;
  }

  @override
  void dispose() {}
}

class _InstallerFake extends PlatformUpdateInstaller {
  _InstallerFake(this.result) : super(platform: UpdatePlatform.windows);

  final InstallResult result;
  File? received;
  var calls = 0;

  @override
  Future<InstallResult> install(
    UpdateAsset asset, {
    required File verifiedFile,
  }) async {
    calls++;
    received = verifiedFile;
    return result;
  }
}

const _sha256 =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> _manifest({int build = 10001}) => {
  'schemaVersion': 1,
  'appId': 'com.cardmind.v2',
  'channel': 'stable',
  'version': '0.1.0',
  'build': build,
  'publishedAt': '2026-01-01T00:00:00Z',
  'minimumSupportedVersion': '0.1.0',
  'mandatory': false,
  'releaseNotes': ['修复问题'],
  'releasePage': 'https://example.com/release',
  'platforms': {
    'windows-x64': {
      'artifact': 'CardMind-Setup.exe',
      'url': 'https://example.com/windows',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
    'android': {
      'artifact': 'CardMind-Android.apk',
      'url': 'https://example.com/android',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
    'linux-x64': {
      'artifact': 'CardMind-Linux-x64.tar.gz',
      'url': 'https://example.com/linux',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
    'macos-arm64': {
      'artifact': 'CardMind-macOS-arm64.dmg',
      'url': 'https://example.com/macos',
      'sha256': _sha256,
      'size': 1,
      'channelManifestUrl':
          'https://github.com/alexcdever/CardMind/releases/download/'
          'channel-stable/stable.json',
    },
  },
};

void main() {
  testWidgets('settings page has version, stable default and check control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          currentBuild: 1,
          initialChannel: UpdateChannel.stable,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('正式版'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-for-updates')), findsOneWidget);
  });

  testWidgets(
    'beta selection can be cancelled or confirmed and persists on screen',
    (tester) async {
      final settings = _SettingsFake(UpdateChannel.stable);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentVersion: '1.0.0', settings: settings),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-channel-beta')));
      await tester.pumpAndSettle();
      expect(find.text('切换到测试版？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(settings.channel, UpdateChannel.stable);
      await tester.tap(find.byKey(const ValueKey('update-channel-beta')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(settings.channel, UpdateChannel.beta);
      expect(find.text('测试版'), findsOneWidget);
    },
  );

  testWidgets('settings echoes a persisted channel', (tester) async {
    final settings = _SettingsFake(UpdateChannel.beta);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(currentVersion: '1.0.0', settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试版'), findsOneWidget);
  });

  testWidgets('system proxy toggle defaults on and persists changes', (
    tester,
  ) async {
    final settings = _SettingsFake(UpdateChannel.beta, useSystemProxy: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(currentVersion: '1.0.0', settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('使用系统网络代理'), findsOneWidget);
    final toggle = find.byKey(const ValueKey('use-system-proxy'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.useSystemProxy, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('downloader injection shares its proxy policy with the toggle', (
    tester,
  ) async {
    final policy = HttpProxyPolicy();
    final downloader = _DownloaderFake(
      const DownloadFailure('unused'),
      proxyPolicy: policy,
    );
    final settings = _SettingsFake(UpdateChannel.stable);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          settings: settings,
          downloader: downloader,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('use-system-proxy')));
    await tester.pumpAndSettle();
    expect(policy.useSystemProxy, isFalse);
    downloader.dispose();
  });

  testWidgets('late settings read does not overwrite a newer proxy choice', (
    tester,
  ) async {
    final settings = _DelayedSettings(UpdateChannel.stable);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(currentVersion: '1.0.0', settings: settings),
      ),
    );
    await tester.pump();
    final toggle = find.byKey(const ValueKey('use-system-proxy'));
    await tester.tap(toggle);
    await tester.pump();
    settings.proxyRead.complete(true);
    await tester.pumpAndSettle();
    expect(settings.useSystemProxy, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('keeps 24px spacing before the update channel heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heading = tester.getTopLeft(find.text('更新渠道'));
    final logEntry = tester.getBottomRight(
      find.byKey(const ValueKey('open-log-directory')),
    );
    expect(heading.dy - logEntry.dy, 24);
  });

  testWidgets('download button shows progress and installer result', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/cardmind-test-update.exe');
    file.writeAsStringSync('verified');
    addTearDown(() async {
      if (file.existsSync()) await file.delete();
    });
    final downloader = _DownloaderFake(DownloadSuccess(file));
    final installer = _InstallerFake(InstallStarted(file));
    String? openedPackage;
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 10002)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          initialChannel: UpdateChannel.stable,
          settings: _SettingsFake(UpdateChannel.stable),
          updates: service,
          downloader: downloader,
          installer: installer,
          updatePackageOpener: (path) async => openedPackage = path,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    expect(find.text('发现更新'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download-update')));
    await tester.pump();
    expect(find.text('已启动安装器'), findsOneWidget);
    expect(installer.received, file);
    expect(find.text('安装包路径：${file.path}'), findsOneWidget);
    if (Platform.isMacOS || Platform.isLinux) {
      final openButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('open-update-package')),
      );
      openButton.onPressed!();
      await tester.pump();
      expect(openedPackage, file.path);
    }
  });

  testWidgets('update check renders an available update', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 10002)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('发现更新'), findsOneWidget);
  });

  testWidgets('update check renders up to date', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => jsonEncode(_manifest(build: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('已是最新版本'), findsOneWidget);
  });

  testWidgets('A3: log directory entry shows path and opens once on tap', (
    tester,
  ) async {
    const resolved = '/tmp/cardmind-logs';
    var openCount = 0;
    String? openedWith;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          settings: _SettingsFake(UpdateChannel.stable),
          logDirectoryResolver: ({String? baseDirectory}) async =>
              Directory(resolved),
          logDirectoryOpener: (directory) async {
            openCount++;
            openedWith = directory;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日志目录'), findsOneWidget, reason: '设置页必须有「日志目录」入口');
    expect(find.text(resolved), findsOneWidget, reason: '副标题必须显示解析出的路径');

    await tester.tap(find.byKey(const ValueKey('open-log-directory')));
    await tester.pumpAndSettle();

    expect(openCount, 1, reason: '点击必须触发注入的 opener 且恰好一次');
    expect(openedWith, resolved, reason: 'opener 收到的必须是解析出的真实路径');
  });

  testWidgets('A3: open failure surfaces the path via SnackBar', (
    tester,
  ) async {
    const resolved = '/tmp/cardmind-logs-failing';

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '1.0.0',
          settings: _SettingsFake(UpdateChannel.stable),
          logDirectoryResolver: ({String? baseDirectory}) async =>
              Directory(resolved),
          logDirectoryOpener: (_) async =>
              throw const ProcessException('open', <String>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-log-directory')));
    await tester.pump();

    final snackBar = find.byType(SnackBar);
    expect(snackBar, findsOneWidget, reason: '打开失败必须显示 SnackBar');
    expect(
      find.descendant(of: snackBar, matching: find.textContaining(resolved)),
      findsOneWidget,
      reason: 'SnackBar 必须包含路径，供用户手动复制',
    );
  });

  testWidgets('update check renders failure state', (tester) async {
    final service = UpdateService(
      currentBuild: 1,
      currentVersion: '0.1.0',
      fetch: (_) async => throw StateError('offline'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          currentBuild: 1,
          updates: service,
          settings: _SettingsFake(UpdateChannel.stable),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('check-for-updates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('检查更新失败：'), findsOneWidget);
  });

  testWidgets(
    'shared manager keeps download alive across settings navigation',
    (tester) async {
      final file = File(
        '${Directory.systemTemp.path}/cardmind-page-update.exe',
      );
      file.writeAsStringSync('verified');
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });
      final downloader = _DeferredDownloader(DownloadSuccess(file));
      final installer = _InstallerFake(
        const ManualInstallRequired('已下载，请手动安装'),
      );
      final manager = UpdateDownloadManager(
        downloader: downloader,
        installer: installer,
      );
      final service = UpdateService(
        currentBuild: 1,
        currentVersion: '0.1.0',
        fetch: (_) async => jsonEncode(_manifest(build: 10002)),
      );
      final settings = _SettingsFake(UpdateChannel.stable);

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (route) => MaterialPageRoute(
              builder: (_) => SettingsPage(
                currentVersion: '0.1.0',
                settings: settings,
                updates: service,
                downloadManager: manager,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('check-for-updates')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('download-update')));
      await tester.pump();
      expect(find.text('下载中…'), findsOneWidget);

      Navigator.of(
        tester.element(find.byKey(const ValueKey('settings-page'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-page')), findsNothing);
      expect(manager.downloading, isTrue);

      downloader.completer.complete();
      await tester.pump();
      await tester.pump();
      expect(installer.calls, 1);
      expect(manager.message, '已下载，请手动安装');

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            currentVersion: '0.1.0',
            settings: settings,
            downloadManager: manager,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('发现更新'), findsOneWidget);
      expect(find.text('已下载，请手动安装'), findsNWidgets(2));
      expect(find.byType(SnackBar), findsOneWidget);

      manager.dispose();
    },
  );

  testWidgets(
    'A1: log directory resolution failure shows a failure state, not loading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            currentVersion: '1.0.0',
            settings: _SettingsFake(UpdateChannel.stable),
            logDirectoryResolver: ({String? baseDirectory}) async =>
                throw const FileSystemException('cannot resolve log directory'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('日志目录'), findsOneWidget);
      expect(find.text('加载中…'), findsNothing, reason: '解析失败后副标题不得继续显示「加载中…」');
      expect(
        find.text('无法获取日志目录'),
        findsOneWidget,
        reason: '解析失败必须显示失败文案，供用户区分加载中与已失败',
      );
    },
  );
  settingsPolishChecks();
}

// ━━━ 以下用例自原 ui_polish_fix2 / ui_polish_opt 迁入 ━━━

UpdateService _offlineService() => UpdateService(
  currentBuild: 1,
  currentVersion: '0.1.0',
  fetch: (_) async => throw StateError('offline'),
);

Future<void> _pumpSettingsPolish(
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

/// 永远挂起的下载器：把 SettingsPage 的 `_downloadManager.downloading` 钉在 true。
class _HangingDownloader extends UpdateDownloader {
  _HangingDownloader();

  final Completer<void> _never = Completer<void>();

  @override
  Future<DownloadResult> download(
    UpdateAsset asset, {
    Uri? url,
    DownloadCancellationToken? cancellation,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.5);
    await _never.future;
    return const DownloadFailure('never completes');
  }

  @override
  void dispose() {}
}

/// 内存版设置服务：避免触碰真实 getApplicationSupportDirectory。
class _MemorySettings extends AppSettingsService {
  @override
  Future<UpdateChannel> readChannel() async => UpdateChannel.stable;

  @override
  Future<bool> readUseSystemProxy() async => true;

  @override
  Future<void> writeChannel(UpdateChannel value) async {}

  @override
  Future<void> writeUseSystemProxy(bool value) async {}
}

/// 日志目录解析：不触碰真实 getApplicationSupportDirectory。
Future<Directory> _fakeLogDirectory({String? baseDirectory}) async =>
    Directory.systemTemp;

/// 把 `minimumSize` 的单个维度表达式解析成数值。
///
/// 支持 `CardMindLayout.mobileTouchTarget`、`48`、`0` 等写法；无法解析一律返回 0，
/// 让断言失败——退让也不允许「看不懂就放行」。
double _resolveSizeValue(String expression) {
  final expr = expression.trim();
  if (expr == 'Size.zero') return 0;
  final literal = double.tryParse(expr);
  if (literal != null) return literal;
  final ref = RegExp(r'^CardMindLayout\.(\w+)$').firstMatch(expr);
  if (ref != null) {
    return switch (ref.group(1)) {
      'mobileTouchTarget' => CardMindLayout.mobileTouchTarget,
      'editorMaxWidth' => CardMindLayout.editorMaxWidth,
      _ => 0,
    };
  }
  return 0;
}

/// ui-polish-fix2 / ui-polish-opt 迁入用例。
void settingsPolishChecks() {
  // ━━ 原 ui_polish_fix2 AC2 ━━
  testWidgets('update check failure shows a single prefix', (tester) async {
    await _pumpSettingsPolish(tester, updates: _offlineService());
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

  // ━━ 原 ui_polish_fix2 AC4 ━━
  testWidgets('settings page padding switches at the 600px breakpoint', (
    tester,
  ) async {
    // 移动端 <600 → 16px
    await _pumpSettingsPolish(tester, size: const Size(390, 844));
    ListView listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      listView.padding,
      const EdgeInsets.all(CardMindSpacing.lg),
      reason: '移动端页面内边距应为 16px',
    );

    // 桌面 ≥600 → 24px
    await _pumpSettingsPolish(tester, size: const Size(1200, 800));
    listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      listView.padding,
      const EdgeInsets.all(CardMindSpacing.xl),
      reason: '桌面端页面内边距应为 24px',
    );
    await tester.pumpWidget(const SizedBox());
  });

  // ━━ 原 ui_polish_fix2 AC6a ━━
  testWidgets('log directory row is disabled when unresolved', (tester) async {
    await _pumpSettingsPolish(
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

  // ━━ 原 ui_polish_fix2 AC6b ━━
  testWidgets('log directory row tappable with icon once resolved', (
    tester,
  ) async {
    const resolved = '/tmp/cardmind-logs';
    var opened = 0;
    await _pumpSettingsPolish(
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

  // ━━ 原 ui_polish_opt 优化项 4/5：取消下载/打开安装包 ≥48dp；桌面限宽 ━━
  // 触摸目标断言必须验证**取值**，不能只验证「存在 minimumSize 字样」：
  // 把 `minimumSize: const Size(0, CardMindLayout.mobileTouchTarget)` 改成
  // `Size.zero`（缺陷本体：触摸目标归零）时，只查标识符的正则照样通过。
  //
  // 为什么断言「挂载后取到的 TextButton.style.minimumSize 取值」而不是渲染高度：
  // Material 3 默认 `tapTargetSize: padded` 会把手势目标撑到 48dp，
  // 把 minimumSize 改成 0 后 `tester.getSize()` 仍是 48（实测 Size(80, 48)），
  // 渲染高度对这个缺陷同样是假通过。挂载后读 style 才能拿到真实声明值。
  testWidgets('cancel-download TextButton declares >=48dp minimumSize', (
    tester,
  ) async {
    // 该按钮仅在 `_result` 是 UpdateAvailable 且 `_downloadManager.downloading`
    // 为 true 时渲染：先给 manager 塞 manifest（initState 会读进 `_result`），
    // 再用挂起中的 downloader 把 downloading 钉在 true。
    const asset = UpdateAsset(
      artifact: 'CardMind-Setup.exe',
      url: 'https://example.com/windows',
      sha256:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      size: 1,
    );
    final manager = UpdateDownloadManager(downloader: _HangingDownloader());
    addTearDown(manager.dispose);
    manager.manifest = UpdateManifest(
      schemaVersion: 1,
      appId: 'com.cardmind.v2',
      channel: 'stable',
      version: '0.1.0',
      build: 10002,
      publishedAt: '2026-01-01T00:00:00Z',
      minimumSupportedVersion: '0.1.0',
      mandatory: false,
      releaseNotes: const ['修复问题'],
      releasePage: 'https://example.com/release',
      platforms: {UpdateManifest.currentPlatform: asset},
    );
    unawaited(manager.start(asset));
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          currentVersion: '0.1.0',
          settings: _MemorySettings(),
          downloadManager: manager,
          logDirectoryResolver: _fakeLogDirectory,
        ),
      ),
    );
    await tester.pump();

    final button = find.byKey(const ValueKey('cancel-update-download'));
    expect(button, findsOneWidget, reason: '下载中应渲染「取消下载」按钮');
    final style = tester.widget<TextButton>(button).style;
    final minimumSize = style?.minimumSize?.resolve(<WidgetState>{});
    expect(
      minimumSize,
      isNotNull,
      reason: '「取消下载」必须显式声明 minimumSize（不得依赖 Material 默认 tap target）',
    );
    expect(
      minimumSize!.height,
      greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
      reason:
          '「取消下载」minimumSize 高度须 ≥${CardMindLayout.mobileTouchTarget}dp，'
          '实际 ${minimumSize.height}（改成 Size.zero / 0 时这里必须失败）',
    );
  });

  // 「打开安装包」只在 macOS/Linux 分支渲染（settings_page.dart:428），
  // Windows 上无法挂载 → 退让为「解析出 minimumSize 的**数值**」并断言 ≥48，
  // 而不是只要求 minimumSize 字样存在（那样 Size.zero 也会通过）。
  test('open-package TextButton minimumSize resolves to >=48dp', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();
    final block = RegExp(
      "key: const ValueKey\\('open-update-package'\\)[\\s\\S]{0,600}?"
      r'minimumSize: const Size\(([\s\S]{0,300}?)\),',
    ).firstMatch(source);
    expect(
      block,
      isNotNull,
      reason: 'open-update-package TextButton 必须 styleFrom(minimumSize: ...)',
    );
    final args = block!
        .group(1)!
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    expect(args, hasLength(2), reason: 'minimumSize 必须是 Size(width, height)');
    final height = _resolveSizeValue(args[1]);
    expect(
      height,
      greaterThanOrEqualTo(CardMindLayout.mobileTouchTarget),
      reason:
          'open-update-package 的 minimumSize 高度须 ≥'
          '${CardMindLayout.mobileTouchTarget}dp，实际解析值 $height',
    );
  });

  testWidgets('desktop settings body has a max-width constraint', (
    tester,
  ) async {
    await _pumpSettingsPolish(tester, size: const Size(1600, 900));

    // 桌面宽屏下 settings-page 内容容器必须被 ConstrainedBox 限宽到
    // editorMaxWidth，而不是整行拉伸。
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-page'))).width,
      lessThanOrEqualTo(CardMindLayout.editorMaxWidth),
      reason: '桌面宽屏内容须以 ConstrainedBox + editorMaxWidth 限宽，与编辑器一致',
    );
  });
}
