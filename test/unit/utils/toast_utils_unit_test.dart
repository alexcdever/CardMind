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
    expect(ToastUtils.cancelAll, returnsNormally);
  });

  test('it_should_cancelAll_not_log_on_unsupported_platform', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.cancelAll();

    expect(logs, isEmpty);
  });

  test('it_should_log_once_for_success', () {
    final logs = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message);
    };

    ToastUtils.showSuccess('hello');

    expect(logs.length, 1);
    expect(logs.first, contains('[SUCCESS] hello'));
  });
}
