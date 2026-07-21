import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/src/rust/frb_generated.dart';

export 'package:cardmind/bridge/frb_note_repository.dart'
    show FrbNoteRepository;

class CardMindIntegrationHarness {
  final _repositories = <FrbNoteRepository>[];
  final _directories = <Directory>[];

  Future<String> createDataDirectory() async {
    final directory = await Directory.systemTemp.createTemp(
      'cardmind_integration_',
    );
    _directories.add(directory);
    return directory.path;
  }

  Future<FrbNoteRepository> openRepository({String? dataDirectory}) async {
    final directory = dataDirectory ?? await createDataDirectory();
    final repository = await FrbNoteRepository.open(dataDirectory: directory);
    _repositories.add(repository);
    return repository;
  }

  Future<void> closeRepository(FrbNoteRepository repository) async {
    repository.close();
    _repositories.remove(repository);
  }

  Future<void> dispose() async {
    for (final repository in _repositories.reversed) {
      repository.close();
    }
    _repositories.clear();
    for (final directory in _directories.reversed) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    _directories.clear();
  }
}

Future<void> initializeFrb() async {
  await RustLib.init();
}

void disposeFrb() {
  RustLib.dispose();
}
