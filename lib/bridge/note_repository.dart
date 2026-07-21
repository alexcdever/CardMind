import '../src/rust/store.dart';

abstract interface class NoteRepository {
  Future<List<NoteRow>> listNotes();

  Future<List<NoteRow>> search(String query);

  Future<String?> getNote(String id);

  Future<void> createNote(String id, String content);
}
