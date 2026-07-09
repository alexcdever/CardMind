# Flutter 单元测试覆盖率补齐 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在不改动生产逻辑的前提下补齐 Flutter 单元测试，使覆盖率达到 ≥90%。

**Architecture:** 仅新增 `test/unit/**` 单元测试；每个公开项至少对应一个 `it_should_` 测试。优先复用现有 mock/fake，避免触发 Rust FFI 或平台插件依赖。提交按三批：models+utils+constants / providers / services。

**Tech Stack:** Flutter/Dart, flutter_test, shared_preferences

---

### Task 1: models + utils + constants 单元测试补齐

**Files:**
- Create: `test/unit/models/sort_option_unit_test.dart`
- Create: `test/unit/models/sync_history_entry_unit_test.dart`
- Create: `test/unit/models/pairing_request_unit_test.dart`
- Create: `test/unit/constants/storage_keys_unit_test.dart`
- Create: `test/unit/utils/device_utils_unit_test.dart`
- Create: `test/unit/utils/responsive_utils_unit_test.dart`
- Create: `test/unit/utils/snackbar_utils_unit_test.dart`
- Create: `test/unit/utils/toast_utils_unit_test.dart`

**Step 1: 写 models + constants 失败测试**

```dart
// test/unit/models/sort_option_unit_test.dart
import 'package:cardmind/models/sort_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_return_display_name_for_each_sort_option', () {
    expect(SortOption.createdAt.displayName, '创建时间');
    expect(SortOption.updatedAt.displayName, '更新时间');
    expect(SortOption.title.displayName, '标题');
  });

  test('it_should_return_icon_for_each_sort_option', () {
    expect(SortOption.createdAt.icon, Icons.schedule);
    expect(SortOption.updatedAt.icon, Icons.update);
    expect(SortOption.title.icon, Icons.title);
  });
}
```

```dart
// test/unit/models/sync_history_entry_unit_test.dart
import 'package:cardmind/models/sync_history_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_format_data_transferred_by_thresholds', () {
    const base = SyncHistoryEntry(
      id: 'sync-1',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 500,
    );
    const kb = SyncHistoryEntry(
      id: 'sync-2',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024,
    );
    const mb = SyncHistoryEntry(
      id: 'sync-3',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024 * 1024,
    );
    const gb = SyncHistoryEntry(
      id: 'sync-4',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024 * 1024 * 1024,
    );

    expect(base.formattedDataTransferred, '500 B');
    expect(kb.formattedDataTransferred, '1.0 KB');
    expect(mb.formattedDataTransferred, '1.0 MB');
    expect(gb.formattedDataTransferred, '1.0 GB');
  });

  test('it_should_detect_success_and_failure_states', () {
    const success = SyncHistoryEntry(
      id: 'sync-1',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 0,
    );
    const failed = SyncHistoryEntry(
      id: 'sync-2',
      timestamp: 0,
      status: SyncHistoryStatus.failed,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 0,
    );

    expect(success.isSuccess, isTrue);
    expect(success.isFailed, isFalse);
    expect(failed.isSuccess, isFalse);
    expect(failed.isFailed, isTrue);
  });

  test('it_should_compare_entries_by_id', () {
    const entryA = SyncHistoryEntry(
      id: 'same-id',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 10,
    );
    const entryB = SyncHistoryEntry(
      id: 'same-id',
      timestamp: 1,
      status: SyncHistoryStatus.failed,
      deviceId: 'dev-2',
      deviceName: 'Other',
      dataTransferred: 20,
    );
    const entryC = SyncHistoryEntry(
      id: 'different-id',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 10,
    );

    expect(entryA, equals(entryB));
    expect(entryA.hashCode, equals(entryB.hashCode));
    expect(entryA, isNot(equals(entryC)));
  });

  test('it_should_return_display_attributes_for_status', () {
    expect(SyncHistoryStatus.success.displayName, '成功');
    expect(SyncHistoryStatus.failed.displayName, '失败');
    expect(SyncHistoryStatus.inProgress.displayName, '进行中');

    expect(SyncHistoryStatus.success.icon, Icons.check_circle);
    expect(SyncHistoryStatus.failed.icon, Icons.error);
    expect(SyncHistoryStatus.inProgress.icon, Icons.sync);

    expect(SyncHistoryStatus.success.color, Colors.green);
    expect(SyncHistoryStatus.failed.color, Colors.red);
    expect(SyncHistoryStatus.inProgress.color, Colors.orange);
  });
}
```

```dart
// test/unit/models/pairing_request_unit_test.dart
import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_serialize_and_deserialize_pairing_request', () {
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.laptop,
      verificationCode: '123456',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    final json = request.toJson();
    final restored = PairingRequest.fromJson(json);

    expect(restored, equals(request));
  });

  test('it_should_calculate_expiration_and_remaining_time', () {
    final now = DateTime.now();
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '654321',
      timestamp: now,
    );

    expect(request.expiresAt, equals(now.add(const Duration(minutes: 5))));
    expect(request.isExpired, isFalse);
    expect(request.timeRemaining, greaterThan(Duration.zero));
  });

  test('it_should_mark_expired_request', () {
    final past = DateTime.now().subtract(const Duration(minutes: 6));
    final request = PairingRequest(
      requestId: 'req-2',
      deviceId: 'peer-2',
      deviceName: 'Device',
      deviceType: DeviceType.tablet,
      verificationCode: '000000',
      timestamp: past,
    );

    expect(request.isExpired, isTrue);
    expect(request.timeRemaining, Duration.zero);
  });

  test('it_should_copy_with_updated_fields', () {
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.laptop,
      verificationCode: '123456',
      timestamp: DateTime(2026, 2, 1, 12, 0, 0),
    );

    final updated = request.copyWith(deviceName: 'Updated');

    expect(updated.deviceName, 'Updated');
    expect(updated.requestId, request.requestId);
  });
}
```

```dart
// test/unit/constants/storage_keys_unit_test.dart
import 'package:cardmind/constants/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_expose_storage_key_constants', () {
    expect(StorageKeys.themeMode, 'theme_mode');
    expect(StorageKeys.syncNotificationEnabled, 'sync_notification_enabled');
  });
}
```

**Step 2: 写 utils 失败测试**

```dart
// test/unit/utils/device_utils_unit_test.dart
import 'package:cardmind/models/device.dart';
import 'package:cardmind/utils/device_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Device buildDevice({
    required String id,
    required DeviceStatus status,
    required DateTime lastSeen,
  }) {
    return Device(
      id: id,
      name: 'Device $id',
      type: DeviceType.laptop,
      status: status,
      lastSeen: lastSeen,
      multiaddrs: const [],
    );
  }

  test('it_should_sort_devices_with_online_first_and_recent_first', () {
    final now = DateTime(2026, 2, 1, 12, 0, 0);
    final devices = <Device>[
      buildDevice(
        id: 'offline-old',
        status: DeviceStatus.offline,
        lastSeen: now.subtract(const Duration(days: 1)),
      ),
      buildDevice(
        id: 'online-old',
        status: DeviceStatus.online,
        lastSeen: now.subtract(const Duration(hours: 1)),
      ),
      buildDevice(
        id: 'online-new',
        status: DeviceStatus.online,
        lastSeen: now,
      ),
    ];

    final sorted = DeviceUtils.sortDevices(devices);

    expect(sorted.first.id, 'online-new');
    expect(sorted[1].id, 'online-old');
    expect(sorted.last.id, 'offline-old');
  });

  test('it_should_format_last_seen_time', () {
    final now = DateTime.now();

    expect(DeviceUtils.formatLastSeen(now.subtract(const Duration(seconds: 30))), '刚刚');
    expect(DeviceUtils.formatLastSeen(now.subtract(const Duration(minutes: 5))), '5 分钟前');
    expect(DeviceUtils.formatLastSeen(now.subtract(const Duration(hours: 3))), '3 小时前');
    expect(DeviceUtils.formatLastSeen(now.subtract(const Duration(days: 2))), '2 天前');

    final older = now.subtract(const Duration(days: 8, hours: 2, minutes: 3));
    final expected =
        '${older.year}-${older.month.toString().padLeft(2, '0')}-${older.day.toString().padLeft(2, '0')} '
        '${older.hour.toString().padLeft(2, '0')}:${older.minute.toString().padLeft(2, '0')}';
    expect(DeviceUtils.formatLastSeen(older), expected);
  });

  test('it_should_return_device_type_and_status_names', () {
    expect(DeviceUtils.getDeviceTypeName(DeviceType.phone), '手机');
    expect(DeviceUtils.getDeviceTypeName(DeviceType.laptop), '笔记本电脑');
    expect(DeviceUtils.getDeviceTypeName(DeviceType.tablet), '平板电脑');

    expect(DeviceUtils.getDeviceStatusName(DeviceStatus.online), '在线');
    expect(DeviceUtils.getDeviceStatusName(DeviceStatus.offline), '离线');
  });

  test('it_should_validate_device_name', () {
    expect(DeviceUtils.isValidDeviceName(''), isFalse);
    expect(DeviceUtils.isValidDeviceName('   '), isFalse);
    expect(DeviceUtils.isValidDeviceName('a' * 33), isFalse);
    expect(DeviceUtils.isValidDeviceName('Valid Name'), isTrue);
  });

  test('it_should_return_device_name_error_messages', () {
    expect(DeviceUtils.getDeviceNameError(''), '设备名称不能为空');
    expect(DeviceUtils.getDeviceNameError('   '), '设备名称不能为空');
    expect(DeviceUtils.getDeviceNameError('a' * 33), '设备名称不能超过 32 个字符');
    expect(DeviceUtils.getDeviceNameError('Valid Name'), isNull);
  });
}
```

```dart
// test/unit/utils/responsive_utils_unit_test.dart
import 'package:cardmind/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _buildWithSize(WidgetTester tester, Size size) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('it_should_classify_breakpoints_and_layout_values', (tester) async {
    final mobile = await _buildWithSize(tester, const Size(500, 800));
    expect(ResponsiveUtils.isMobile(mobile), isTrue);
    expect(ResponsiveUtils.getGridColumns(mobile), 1);
    expect(ResponsiveUtils.getHorizontalPadding(mobile), 16);
    expect(ResponsiveUtils.getVerticalPadding(mobile), 16);
    expect(ResponsiveUtils.getMaxContentWidth(mobile), isNull);
    expect(ResponsiveUtils.getAppBarHeight(mobile), kToolbarHeight);

    final tablet = await _buildWithSize(tester, const Size(800, 800));
    expect(ResponsiveUtils.isTablet(tablet), isTrue);
    expect(ResponsiveUtils.getGridColumns(tablet), 2);
    expect(ResponsiveUtils.getHorizontalPadding(tablet), 32);
    expect(ResponsiveUtils.getVerticalPadding(tablet), 24);
    expect(ResponsiveUtils.getMaxContentWidth(tablet), 900);

    final desktop = await _buildWithSize(tester, const Size(1300, 800));
    expect(ResponsiveUtils.isDesktop(desktop), isTrue);
    expect(ResponsiveUtils.getGridColumns(desktop), 3);
    expect(ResponsiveUtils.getHorizontalPadding(desktop), 48);
    expect(ResponsiveUtils.getVerticalPadding(desktop), 32);
    expect(ResponsiveUtils.getMaxContentWidth(desktop), 1200);
    expect(ResponsiveUtils.getAppBarHeight(desktop), kToolbarHeight + 8);
  });

  testWidgets('it_should_detect_landscape_orientation', (tester) async {
    final landscape = await _buildWithSize(tester, const Size(1200, 600));
    expect(ResponsiveUtils.isLandscape(landscape), isTrue);
  });
}
```

```dart
// test/unit/utils/snackbar_utils_unit_test.dart
import 'package:cardmind/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSnackBar(
  WidgetTester tester,
  void Function(BuildContext) trigger,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            trigger(context);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('it_should_show_success_snackbar', (tester) async {
    await _pumpSnackBar(tester, (context) {
      SnackBarUtils.showSuccess(context, 'ok');
    });

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.green.shade600);
    expect(find.text('ok'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('it_should_show_error_snackbar', (tester) async {
    await _pumpSnackBar(tester, (context) {
      SnackBarUtils.showError(context, 'error');
    });

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.red.shade600);
    expect(find.text('error'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('it_should_show_info_snackbar', (tester) async {
    await _pumpSnackBar(tester, (context) {
      SnackBarUtils.showInfo(context, 'info');
    });

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.blue.shade600);
    expect(find.text('info'), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });

  testWidgets('it_should_show_warning_snackbar', (tester) async {
    await _pumpSnackBar(tester, (context) {
      SnackBarUtils.showWarning(context, 'warn');
    });

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.orange.shade600);
    expect(find.text('warn'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });
}
```

```dart
// test/unit/utils/toast_utils_unit_test.dart
import 'package:cardmind/utils/toast_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DebugPrintCallback original;

  setUp(() {
    original = debugPrint;
  });

  tearDown(() {
    debugPrint = original;
  });

  test('it_should_log_success_on_unsupported_platform', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.showSuccess('ok');

    expect(logs.last, contains('[SUCCESS] ok'));
  });

  test('it_should_log_error_on_unsupported_platform', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.showError('oops');

    expect(logs.last, contains('[ERROR] oops'));
  });

  test('it_should_log_info_on_unsupported_platform', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.showInfo('info');

    expect(logs.last, contains('[INFO] info'));
  });

  test('it_should_log_warning_on_unsupported_platform', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.showWarning('warn');

    expect(logs.last, contains('[WARNING] warn'));
  });

  test('it_should_cancel_toast_without_throwing', () {
    expect(() => ToastUtils.cancelAll(), returnsNormally);
  });
}
```

**Step 3: 运行测试确认失败**

Run:
- `flutter test test/unit/models`
- `flutter test test/unit/constants/storage_keys_unit_test.dart`
- `flutter test test/unit/utils`

Expected: FAIL（若全部 PASS，说明覆盖行为已实现，继续下一步即可）

**Step 4: 最小修复（如有失败）**

仅在测试暴露现有行为缺陷时最小化修复；若无失败则跳过。

**Step 5: 重新运行测试确认通过**

Run:
- `flutter test test/unit/models`
- `flutter test test/unit/constants/storage_keys_unit_test.dart`
- `flutter test test/unit/utils`

Expected: PASS

**Step 6: Commit**

```bash
git add test/unit/models test/unit/constants test/unit/utils
git commit -m "test(unit): add models utils constants coverage"
```

---

### Task 2: providers 单元测试补齐

**Files:**
- Create: `test/unit/providers/theme_provider_unit_test.dart`
- Create: `test/unit/providers/device_manager_provider_unit_test.dart`
- Create: `test/unit/providers/card_editor_state_unit_test.dart`
- Create: `test/unit/providers/card_provider_unit_test.dart`

**Step 1: 写 theme/device_manager 失败测试**

```dart
// test/unit/providers/theme_provider_unit_test.dart
import 'package:cardmind/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('it_should_initialize_theme_from_preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.toString(),
    });

    final provider = ThemeProvider();
    await provider.initialize();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('it_should_toggle_theme_mode', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.light);
    await provider.toggleTheme();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('it_should_report_is_dark_mode', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.dark);

    expect(provider.isDarkMode, isTrue);
  });
}
```

```dart
// test/unit/providers/device_manager_provider_unit_test.dart
import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';
import 'package:cardmind/providers/device_manager_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_update_page_state', () {
    final provider = DeviceManagerProvider();

    provider.setLoading();
    expect(provider.pageState, PageState.loading);

    provider.setLoaded();
    expect(provider.pageState, PageState.loaded);

    provider.setNotInPool();
    expect(provider.pageState, PageState.notInPool);

    provider.setError('error');
    expect(provider.pageState, PageState.error);
    expect(provider.errorMessage, 'error');
  });

  test('it_should_update_pairing_state_flow', () {
    final provider = PairingProvider();

    provider.startScanning();
    expect(provider.state, PairingState.scanning);

    provider.qrCodeScanned('peer-1', 'Device');
    expect(provider.state, PairingState.waitingVerify);
    expect(provider.deviceId, 'peer-1');

    provider.startVerifying();
    expect(provider.state, PairingState.verifying);

    provider.verificationSuccess();
    expect(provider.state, PairingState.success);

    provider.verificationFailed('fail');
    expect(provider.state, PairingState.failed);
    expect(provider.errorMessage, 'fail');

    provider.reset();
    expect(provider.state, PairingState.idle);
  });

  test('it_should_manage_pairing_requests', () {
    final provider = PairingRequestsProvider();
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '123456',
      timestamp: DateTime.now(),
    );

    provider.addRequest(request);
    expect(provider.requests.length, 1);
    expect(provider.getRequest('req-1'), isNotNull);

    provider.removeRequest('req-1');
    expect(provider.requests, isEmpty);

    final expired = PairingRequest(
      requestId: 'req-2',
      deviceId: 'peer-2',
      deviceName: 'Device',
      deviceType: DeviceType.tablet,
      verificationCode: '654321',
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
    );
    provider.addRequest(expired);
    provider.cleanupExpired();
    expect(provider.requests, isEmpty);
  });
}
```

**Step 2: 写 card_editor_state/card_provider 失败测试**

```dart
// test/unit/providers/card_editor_state_unit_test.dart
import 'package:cardmind/providers/card_editor_state.dart';
import 'package:cardmind/services/mock_card_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_update_title_and_clear_error', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    expect(await state.manualSave(), isFalse);
    expect(state.errorMessage, isNotNull);

    state.updateTitle('Title');
    expect(state.title, 'Title');
    expect(state.errorMessage, isNull);
  });

  testWidgets('it_should_validate_title_rules', (tester) async {
    final state = CardEditorState(cardApi: MockCardApi());

    state.updateTitle('');
    expect(state.validate(), '标题不能为空');

    state.updateTitle('a' * 201);
    expect(state.validate(), '标题不能超过 200 字符');

    state.updateTitle('Valid');
    expect(state.validate(), isNull);
  });

  testWidgets('it_should_manual_save_create_and_update', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    state.updateTitle('Title');
    state.updateContent('Content');

    final created = await state.manualSave();
    expect(created, isTrue);
    expect(mockApi.createCardCallCount, 1);

    state.updateContent('Updated');
    final updated = await state.manualSave();
    expect(updated, isTrue);
    expect(mockApi.updateCardCallCount, 1);
  });

  testWidgets('it_should_auto_save_with_debounce', (tester) async {
    final mockApi = MockCardApi();
    final state = CardEditorState(cardApi: mockApi);

    state.updateTitle('Title');
    state.updateContent('Content');

    await tester.pump(const Duration(milliseconds: 600));

    expect(mockApi.createCardCallCount, 1);
    expect(state.showSuccessIndicator, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(state.showSuccessIndicator, isFalse);
  });

  testWidgets('it_should_retry_save_after_error', (tester) async {
    final mockApi = MockCardApi()..shouldThrowError = true;
    final state = CardEditorState(cardApi: mockApi);

    state.updateTitle('Title');
    final created = await state.manualSave();
    expect(created, isFalse);
    expect(state.errorMessage, isNotNull);

    mockApi.shouldThrowError = false;
    await state.retrySave();

    expect(mockApi.createCardCallCount, 1);
    expect(state.errorMessage, isNull);
  });
}
```

```dart
// test/unit/providers/card_provider_unit_test.dart
import 'package:cardmind/bridge/models/card.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/services/card_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCardService extends CardService {
  FakeCardService({List<Card>? initialCards}) : _cards = initialCards ?? [];

  final List<Card> _cards;
  bool shouldThrow = false;
  bool initializeCalled = false;

  Card _buildCard(String id, {bool deleted = false}) {
    return Card(
      id: id,
      title: 'Title $id',
      content: 'Content',
      createdAt: 0,
      updatedAt: 0,
      deleted: deleted,
      tags: const [],
      lastEditDevice: null,
    );
  }

  @override
  Future<void> initialize(String storagePath) async {
    if (shouldThrow) throw Exception('init failed');
    initializeCalled = true;
  }

  @override
  Future<List<Card>> getActiveCards() async {
    if (shouldThrow) throw Exception('load failed');
    return _cards.where((c) => !c.deleted).toList();
  }

  @override
  Future<Card> createCard(String title, String content) async {
    if (shouldThrow) throw Exception('create failed');
    final card = _buildCard('card-${_cards.length + 1}');
    _cards.add(card);
    return card;
  }

  @override
  Future<Card> getCardById(String id) async {
    if (shouldThrow) throw Exception('get failed');
    return _cards.firstWhere((c) => c.id == id);
  }

  @override
  Future<void> updateCard(String id, {String? title, String? content}) async {
    if (shouldThrow) throw Exception('update failed');
  }

  @override
  Future<void> deleteCard(String id) async {
    if (shouldThrow) throw Exception('delete failed');
    final index = _cards.indexWhere((c) => c.id == id);
    if (index != -1) {
      _cards[index] = _buildCard(id, deleted: true);
    }
  }

  @override
  Future<(int, int, int)> getCardCount() async {
    return (0, _cards.length, _cards.where((c) => !c.deleted).length);
  }
}

void main() {
  test('it_should_initialize_and_load_cards', () async {
    final service = FakeCardService(initialCards: <Card>[
      Card(
        id: 'card-1',
        title: 'Title',
        content: 'Content',
        createdAt: 0,
        updatedAt: 0,
        deleted: false,
        tags: const [],
        lastEditDevice: null,
      ),
    ]);
    final provider = CardProvider(cardService: service);

    await provider.initialize('/tmp');

    expect(service.initializeCalled, isTrue);
    expect(provider.cards.length, 1);
    expect(provider.hasError, isFalse);
  });

  test('it_should_create_update_and_delete_cards', () async {
    final service = FakeCardService();
    final provider = CardProvider(cardService: service);

    final created = await provider.createCard('Title', 'Content');
    expect(created, isNotNull);
    expect(provider.cards.length, 1);

    final updated = await provider.updateCard('card-1', title: 'New');
    expect(updated, isTrue);

    final deleted = await provider.deleteCard('card-1');
    expect(deleted, isTrue);
    expect(provider.cards, isEmpty);
  });

  test('it_should_set_error_on_failure', () async {
    final service = FakeCardService()..shouldThrow = true;
    final provider = CardProvider(cardService: service);

    await provider.loadCards();

    expect(provider.hasError, isTrue);
  });
}
```

**Step 3: 运行测试确认失败**

Run: `flutter test test/unit/providers`
Expected: FAIL（若全部 PASS，继续下一步即可）

**Step 4: 最小修复（如有失败）**

仅在测试暴露现有行为缺陷时最小化修复；若无失败则跳过。

**Step 5: 重新运行测试确认通过**

Run: `flutter test test/unit/providers`
Expected: PASS

**Step 6: Commit**

```bash
git add test/unit/providers
git commit -m "test(unit): add provider coverage"
```

---

### Task 3: services 单元测试补齐

**Files:**
- Create: `test/unit/services/mock_card_api_unit_test.dart`
- Create: `test/unit/services/device_discovery_service_unit_test.dart`

**Step 1: 写失败测试**

```dart
// test/unit/services/mock_card_api_unit_test.dart
import 'package:cardmind/services/mock_card_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_create_update_delete_and_query_cards', () async {
    final api = MockCardApi();

    final card = await api.createCard(title: 'Title', content: 'Content');
    expect(api.createCardCallCount, 1);
    expect(card.title, 'Title');

    await api.updateCard(id: card.id, title: 'Updated');
    expect(api.updateCardCallCount, 1);

    final fetched = await api.getCardById(id: card.id);
    expect(fetched.title, 'Updated');

    await api.deleteCard(id: card.id);
    expect(api.deleteCardCallCount, 1);

    final active = await api.getActiveCards();
    expect(active, isEmpty);
  });

  test('it_should_throw_on_error_flags', () async {
    final api = MockCardApi()..shouldThrowError = true;

    expect(
      () => api.createCard(title: 'Title', content: 'Content'),
      throwsException,
    );
  });
}
```

```dart
// test/unit/services/device_discovery_service_unit_test.dart
import 'package:cardmind/models/device.dart';
import 'package:cardmind/services/device_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_emit_events_on_device_online_offline', () async {
    final service = DeviceDiscoveryService();
    final events = <DeviceDiscoveryEvent>[];
    final sub = service.stateChanges.listen(events.add);

    service.handleDeviceOnline('peer-1', const ['addr']);
    await Future<void>.delayed(Duration.zero);

    service.handleDeviceOffline('peer-1');
    await Future<void>.delayed(Duration.zero);

    expect(events.length, 2);
    expect(events.first.isOnline, isTrue);
    expect(events.last.isOnline, isFalse);

    await sub.cancel();
    service.dispose();
  });

  test('it_should_update_device_states_and_online_list', () {
    final service = DeviceDiscoveryService();

    service.handleDeviceOnline('peer-1', const ['addr']);
    final devices = <Device>[
      Device(
        id: 'peer-1',
        name: 'Device',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime(2026, 1, 1),
        multiaddrs: const [],
      ),
    ];

    final updated = service.updateDeviceStates(devices);
    expect(updated.first.status, DeviceStatus.online);
    expect(updated.first.multiaddrs, ['addr']);

    final online = service.getOnlineDevices();
    expect(online, ['peer-1']);
  });

  test('it_should_reset_device_discovery_manager_singleton', () {
    final first = DeviceDiscoveryManager.instance;
    DeviceDiscoveryManager.reset();
    final second = DeviceDiscoveryManager.instance;

    expect(first, isNot(same(second)));
  });
}
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/unit/services/mock_card_api_unit_test.dart test/unit/services/device_discovery_service_unit_test.dart`
Expected: FAIL（若全部 PASS，继续下一步即可）

**Step 3: 最小修复（如有失败）**

仅在测试暴露现有行为缺陷时最小化修复；若无失败则跳过。

**Step 4: 重新运行测试确认通过**

Run: `flutter test test/unit/services/mock_card_api_unit_test.dart test/unit/services/device_discovery_service_unit_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add test/unit/services
git commit -m "test(unit): add service coverage"
```

---

### Task 4: 全量质量检查

**Step 1: 运行质量检查**

Run: `dart tool/quality.dart`
Expected: PASS（Flutter 单元覆盖率 ≥90%）

**Step 2: 如 Rust 构建因代理失败**

- 记录失败原因（crates.io 连接失败）
- 与用户确认是否临时跳过或调整代理后重试

