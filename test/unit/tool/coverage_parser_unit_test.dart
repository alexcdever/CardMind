import 'dart:io';

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

  test('it_should_parse_rust_unit_test_items', () {
    const source = '''
#[test]
fn it_should_create_pool() {}

#[test]
fn it_should_pool__rename() {}
''';
    final items = parseRustUnitTestItems(source);
    expect(items, containsAll(<String>{'create_pool', 'pool__rename'}));
  });

  test('it_should_parse_dart_unit_test_items', () {
    const source = '''
test('it_should_format_id', () {});
testWidgets("it_should_device__ping", (tester) async {});
''';
    final items = parseDartUnitTestItems(source);
    expect(items, containsAll(<String>{'format_id', 'device__ping'}));
  });

  test('it_should_calculate_coverage_summary', () {
    final summary = calculateCoverageSummary(
      publicItems: <String>{'Pool', 'Mode', 'formatId'},
      unitTestItems: <String>{'pool', 'format_id'},
    );
    expect(summary.expectedCount, 3);
    expect(summary.actualCount, 2);
    expect(summary.coverageRate, closeTo(2 / 3, 0.0001));
    expect(summary.missingItems, contains('Mode'));
  });

  test('it_should_analyze_coverage_from_directories', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('coverage_analyze_');
    try {
      final Directory sourceDir =
          Directory('${tempDir.path}/lib/models')..createSync(recursive: true);
      final Directory testDir =
          Directory('${tempDir.path}/test/unit/models')
            ..createSync(recursive: true);

      final File sourceFile = File('${sourceDir.path}/device.dart');
      await sourceFile.writeAsString('class Device { void ping() {} }');

      final File testFile = File('${testDir.path}/device_test.dart');
      await testFile.writeAsString(
        "test('it_should_device', () {});\n"
        "test('it_should_device__ping', () {});\n",
      );

      final summary = await analyzeCoverageFromPaths(
        sourceDirectories: <String>[sourceDir.path],
        testDirectories: <String>[testDir.path],
        sourceExtension: '.dart',
        testExtension: '.dart',
        publicParser: parseDartPublicItems,
        unitTestParser: parseDartUnitTestItems,
        excludedPathFragments: const <String>{},
      );

      expect(summary.expectedCount, 2);
      expect(summary.actualCount, 2);
      expect(summary.coverageRate, 1.0);
      expect(summary.missingItems, isEmpty);
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
