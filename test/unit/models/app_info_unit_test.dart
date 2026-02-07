import 'package:cardmind/models/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInfo', () {
    test('it_should_should create default info', () {
      final info = AppInfo.defaultInfo();

      expect(info.version, '0.1.0');
      expect(info.buildNumber, '1');
      expect(info.contributors, isNotEmpty);
      expect(info.changelog, isNotEmpty);
    });

    test('it_should_should serialize to JSON', () {
      final info = AppInfo.defaultInfo();
      final json = info.toJson();

      expect(json['version'], info.version);
      expect(json['buildNumber'], info.buildNumber);
      expect(json['contributors'], info.contributors);
    });

    test('it_should_should deserialize from JSON', () {
      final original = AppInfo.defaultInfo();
      final json = original.toJson();
      final deserialized = AppInfo.fromJson(json);

      expect(deserialized.version, original.version);
      expect(deserialized.buildNumber, original.buildNumber);
      expect(deserialized.contributors, original.contributors);
    });

    test('it_should_should handle equality correctly', () {
      final info1 = AppInfo.defaultInfo();
      final info2 = AppInfo.defaultInfo();

      expect(info1, equals(info2));
      expect(info1.hashCode, equals(info2.hashCode));
    });

    test('it_should_default_info_contains_links', () {
      final info = AppInfo.defaultInfo();

      expect(info.homepage, isNotEmpty);
      expect(info.issuesUrl, isNotEmpty);
    });

    test('it_should_fromJson_apply_defaults_when_missing', () {
      final info = AppInfo.fromJson(const {});

      expect(info.version, '0.0.0');
      expect(info.buildNumber, '0');
      expect(info.description, '');
      expect(info.homepage, '');
      expect(info.issuesUrl, '');
      expect(info.contributors, isEmpty);
      expect(info.changelog, isEmpty);
    });

    test('it_should_app_info_not_equal_when_version_differs', () {
      final info = AppInfo.defaultInfo();
      final other = AppInfo(
        version: '0.1.1',
        buildNumber: info.buildNumber,
        description: info.description,
        homepage: info.homepage,
        issuesUrl: info.issuesUrl,
        contributors: info.contributors,
        changelog: info.changelog,
      );

      expect(other, isNot(equals(info)));
    });
  });

  group('ChangelogEntry', () {
    test('it_should_should serialize to JSON', () {
      const entry = ChangelogEntry(
        version: '1.0.0',
        date: '2026-01-29',
        changes: ['Feature 1', 'Feature 2'],
      );

      final json = entry.toJson();

      expect(json['version'], '1.0.0');
      expect(json['date'], '2026-01-29');
      expect(json['changes'], ['Feature 1', 'Feature 2']);
    });

    test('it_should_should deserialize from JSON', () {
      final json = {
        'version': '1.0.0',
        'date': '2026-01-29',
        'changes': ['Feature 1', 'Feature 2'],
      };

      final entry = ChangelogEntry.fromJson(json);

      expect(entry.version, '1.0.0');
      expect(entry.date, '2026-01-29');
      expect(entry.changes, ['Feature 1', 'Feature 2']);
    });

    test('it_should_should handle equality correctly', () {
      const entry1 = ChangelogEntry(
        version: '1.0.0',
        date: '2026-01-29',
        changes: ['Feature 1'],
      );
      const entry2 = ChangelogEntry(
        version: '1.0.0',
        date: '2026-01-29',
        changes: ['Feature 1'],
      );

      expect(entry1, equals(entry2));
      expect(entry1.hashCode, equals(entry2.hashCode));
    });

    test('it_should_changelog_entry_round_trip', () {
      const entry = ChangelogEntry(
        version: '1.2.3',
        date: '2026-02-01',
        changes: ['Fix A', 'Fix B'],
      );

      final restored = ChangelogEntry.fromJson(entry.toJson());

      expect(restored, equals(entry));
    });
  });
}
