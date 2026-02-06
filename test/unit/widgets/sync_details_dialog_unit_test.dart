import 'package:cardmind/widgets/sync_details_dialog/utils/sync_dialog_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_format_sync_dialog_values', () {
    expect(SyncDialogFormatters.formatBytes(0), '0 B');
    expect(SyncDialogFormatters.formatBytes(1024), '1.0 KB');
    expect(SyncDialogFormatters.formatDuration(500), '500 ms');
    expect(SyncDialogFormatters.formatCardCount(2), '2 张卡片');
  });
}
