import 'package:cardmind/src/rust/frb_generated.dart';

import 'frb_note_repository.dart';

export 'frb_note_repository.dart' show FrbNoteRepository;

const kNewNoteTooltip = '新建笔记';
const kCloseEditorTooltip = '关闭编辑器';
const kSaveTooltip = '保存';

class CardMindIntegrationHarness {
  final _repositories = <FrbNoteRepository>[];

  Future<FrbNoteRepository> openRepository() async {
    final repository = await FrbNoteRepository.create();
    _repositories.add(repository);
    return repository;
  }

  Future<void> dispose() async {
    for (final repository in _repositories.reversed) {
      await repository.dispose();
    }
    _repositories.clear();
  }
}

Future<void> initializeFrb() async {
  await RustLib.init();
}

void disposeFrb() {
  RustLib.dispose();
}
