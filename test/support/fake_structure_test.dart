import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 结构测试：三个共享 fake 必须 `extends NoteRepositoryStub`（或对应 stub），
/// 而非 `implements` 全接口——确保接口加方法时只需改 stub 基类。
void main() {
  group('test/support fake 去重', () {
    test('MemoryNoteRepository extends NoteRepositoryStub（不再 implements）', () {
      final src = File(
        'test/support/memory_note_repository.dart',
      ).readAsStringSync();
      expect(
        src,
        isNot(contains('implements NoteRepository')),
        reason:
            'MemoryNoteRepository 应 extends NoteRepositoryStub 而非 implements 全接口',
      );
      expect(src, contains('extends NoteRepositoryStub'));
    });

    test(
      'DevicesRepository extends NoteRepositoryStub（保留 ConnectivityRepository）',
      () {
        final src = File(
          'test/support/devices_repository.dart',
        ).readAsStringSync();
        expect(
          src,
          isNot(contains('implements NoteRepository')),
          reason:
              'DevicesRepository 应 extends NoteRepositoryStub 而非 implements 全接口',
        );
        expect(src, contains('extends NoteRepositoryStub'));
        // ConnectivityRepository 不在 stub 中，仍需显式 implements。
        expect(src, contains('implements ConnectivityRepository'));
      },
    );

    test('CredentialUiRepository extends NoteRepositoryStub（不再 implements）', () {
      final src = File(
        'test/support/credential_ui_repository.dart',
      ).readAsStringSync();
      expect(
        src,
        isNot(contains('implements NoteRepository')),
        reason:
            'CredentialUiRepository 应 extends NoteRepositoryStub 而非 implements 全接口',
      );
      expect(src, contains('extends NoteRepositoryStub'));
    });
  });
}
