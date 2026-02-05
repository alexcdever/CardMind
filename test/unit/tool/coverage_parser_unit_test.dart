import 'package:flutter_test/flutter_test.dart';

import '../../../tool/quality/coverage.dart';

void main() {
  test('it_should_parse_rust_public_items', () {
    const source = '''
pub struct Pool {}
pub enum Mode {}
pub fn do_work() {}
impl Pool { pub fn rename(&self) {} }
''';
    final items = parseRustPublicItems(source);
    expect(
      items,
      containsAll(<String>{'Pool', 'Mode', 'do_work', 'Pool__rename'}),
    );
  });

  test('it_should_parse_dart_public_items', () {
    const source = '''
class Device { void ping() {} }
String formatId(String id) => id;
''';
    final items = parseDartPublicItems(source);
    expect(items, containsAll(<String>{'Device', 'Device__ping', 'formatId'}));
  });
}
