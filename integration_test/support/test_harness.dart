import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/bridge/rust_library_loader.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

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
  // 与 main.dart 一致：产物内按 exe 位置定位 Frameworks/libcardmind_backend.dylib，
  // 否则 FRB 默认加载器会去找 cardmind_backend.framework（macOS 宿主不存在）。
  final externalLibraryPath = resolveBundledRustLibraryPath(
    executablePath: Platform.resolvedExecutable,
    operatingSystem: Platform.operatingSystem,
    exists: (path) => File(path).existsSync(),
  );
  await RustLib.init(
    externalLibrary: externalLibraryPath == null
        ? null
        : ExternalLibrary.open(externalLibraryPath),
  );
}

void disposeFrb() {
  RustLib.dispose();
}
