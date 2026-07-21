import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(RustLib.init);

  test(
    'repository restores Loro content and SQLite projection after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('cardmind_repo_');
      FrbNoteRepository? repository;
      addTearDown(() {
        repository?.close();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      repository = await FrbNoteRepository.open(dataDirectory: dir.path);
      await repository.createNote(
        'persistent-note',
        '<!--tags:work,idea--># Persisted title\n\nPersistent body',
      );
      repository.close();

      repository = await FrbNoteRepository.open(dataDirectory: dir.path);
      expect(
        await repository.getNote('persistent-note'),
        '<!--tags:work,idea--># Persisted title\n\nPersistent body',
      );

      final rows = await repository.listNotes();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Persisted title');
      expect(rows.single.contentPreview, 'Persistent body');
      expect(rows.single.tags, 'work,idea');

      expect((await repository.search('idea')).single.id, 'persistent-note');
    },
  );

  test('closed repository rejects further operations', () async {
    final dir = await Directory.systemTemp.createTemp('cardmind_repo_closed_');
    final repository = await FrbNoteRepository.open(dataDirectory: dir.path);
    repository.close();
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    expect(repository.listNotes(), throwsStateError);
  });
}
