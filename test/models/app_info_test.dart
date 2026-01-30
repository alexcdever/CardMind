import 'package:cardmind/models/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInfo', () {
    test('should create default info', () {
      final info = AppInfo.defaultInfo();

      expect(info.version, '0.1.0');
      expect(info.buildNumber, '1');
      expect(info.contributors, isNotEmpty);
      expect(info.changelog, isNotEmpty);
    });

    test('should serialize to JSON', () {
      final info = AppInfo.defaultInfo();
      final json = info.toJson();

      expect(json['version'], info.version);
      expect(json['buildNumber'], info.buildNumber);
      expect(json['contributors'], info.contributors);
    });

    test('should deserialize from JSON', () {
      final original = AppInfo.defaultInfo();
      final json = original.toJson();
      final deserialized = AppInfo.fromJson(json);

      expect(deserialized.version, original.version);
      expect(deserialized.buildNumber, original.buildNumber);
      expect(deserialized.contributors, original.contributors);
    });

    test('should handle equality correctly', () {
      final info1 = AppInfo.defaultInfo();
      final info2 = AppInfo.defaultInfo();

      expect(info1, equals(info2));
      expect(info1.hashCode, equals(info2.hashCode));
    });
  });

  group('ChangelogEntry', () {
    test('should serialize to JSON', () {
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

    test('should deserialize from JSON', () {
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

    test('should handle equality correctly', () {
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
  });
}
